import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_provider.dart';
import '../identify/identify_result_page.dart';
import 'photo_utils.dart';

class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> {
  final _picker = ImagePicker();
  String? _path;
  ProcessedPhoto? _processed;
  String? _error;
  bool _busy = false;
  bool _identifying = false;

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 4000,
        maxHeight: 4000,
        imageQuality: 95,
      );
      if (file == null) {
        setState(() => _busy = false);
        return;
      }
      final processed = await resizeForUpload(file.path);
      setState(() {
        _path = file.path;
        _processed = processed;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Błąd: $e';
        _busy = false;
      });
    }
  }

  Future<void> _identify() async {
    final processed = _processed;
    final path = _path;
    if (processed == null || path == null) return;
    final client = ref.read(apiClientProvider);
    if (client == null) {
      setState(() => _error = 'Brak konfiguracji backendu.');
      return;
    }
    setState(() {
      _identifying = true;
      _error = null;
    });
    try {
      final artefakt = await client.identify(processed.bytes);
      if (!mounted) return;
      await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) =>
              IdentifyResultPage(artefakt: artefakt, photoPath: path),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _identifying = false);
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _processed != null && _path != null;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Zdjęcie')),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6.resolveFrom(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _path == null
                      ? const Center(
                          child: Text(
                            'Brak zdjęcia',
                            style: TextStyle(
                                color: CupertinoColors.systemGrey,
                                fontSize: 16),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_path!),
                            fit: BoxFit.contain,
                            width: double.infinity,
                          ),
                        ),
                ),
              ),
              if (_processed != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Po resize: ${_processed!.width}×${_processed!.height} px, '
                  '${_formatSize(_processed!.sizeBytes)} JPEG q85',
                  style: const TextStyle(
                      fontSize: 13, color: CupertinoColors.systemGrey),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(
                        color: CupertinoColors.destructiveRed, fontSize: 13)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      color: CupertinoColors.systemGrey4,
                      onPressed: (_busy || _identifying)
                          ? null
                          : () => _pick(ImageSource.gallery),
                      child: const Text('Z biblioteki',
                          style: TextStyle(color: CupertinoColors.label)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoButton(
                      color: CupertinoColors.systemGrey4,
                      onPressed: (_busy || _identifying)
                          ? null
                          : () => _pick(ImageSource.camera),
                      child: const Text('Aparat',
                          style: TextStyle(color: CupertinoColors.label)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CupertinoButton.filled(
                onPressed: (hasPhoto && !_busy && !_identifying)
                    ? _identify
                    : null,
                child: _identifying
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CupertinoActivityIndicator(
                              color: CupertinoColors.white),
                          SizedBox(width: 10),
                          Text('Wysyłam do AI…'),
                        ],
                      )
                    : const Text('Zidentyfikuj'),
              ),
              if (_busy && !_identifying) ...[
                const SizedBox(height: 12),
                const Center(child: CupertinoActivityIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

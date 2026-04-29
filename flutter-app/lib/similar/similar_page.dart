import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_provider.dart';
import '../photo/photo_utils.dart';
import 'similar_result.dart';

class SimilarPage extends ConsumerStatefulWidget {
  const SimilarPage({super.key});

  @override
  ConsumerState<SimilarPage> createState() => _SimilarPageState();
}

class _SimilarPageState extends ConsumerState<SimilarPage> {
  final _picker = ImagePicker();
  String? _path;
  ProcessedPhoto? _processed;
  bool _busy = false;
  bool _searching = false;
  String? _error;
  SimilarResponse? _response;

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
        _response = null;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Błąd: $e';
        _busy = false;
      });
    }
  }

  Future<void> _search() async {
    final processed = _processed;
    if (processed == null) return;
    final client = ref.read(apiClientProvider);
    if (client == null) {
      setState(() => _error = 'Brak konfiguracji backendu.');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _response = null;
    });
    try {
      final res = await client.findSimilar(processed.bytes, topK: 5);
      if (!mounted) return;
      setState(() => _response = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _processed != null;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Znajdź podobne')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_path != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(_path!),
                  height: 180,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              )
            else
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('Wybierz zdjęcie eksponatu',
                      style: TextStyle(color: CupertinoColors.systemGrey)),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    color: CupertinoColors.systemGrey4,
                    onPressed: (_busy || _searching)
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
                    onPressed: (_busy || _searching)
                        ? null
                        : () => _pick(ImageSource.camera),
                    child: const Text('Aparat',
                        style: TextStyle(color: CupertinoColors.label)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            CupertinoButton.filled(
              onPressed: (hasPhoto && !_busy && !_searching) ? _search : null,
              child: _searching
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CupertinoActivityIndicator(
                            color: CupertinoColors.white),
                        SizedBox(width: 10),
                        Text('Szukam podobnych…'),
                      ],
                    )
                  : const Text('Szukaj'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(
                      color: CupertinoColors.destructiveRed, fontSize: 13)),
            ],
            if (_response != null) ...[
              const SizedBox(height: 18),
              Text(
                'Top ${_response!.results.length} z ${_response!.indexSize} eksponatów',
                style: const TextStyle(
                    fontSize: 12, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(height: 8),
              for (final r in _response!.results) _ResultTile(result: r),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final SimilarResult result;
  const _ResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final thumb = result.thumbnailB64;
    final distancePct = ((1.0 - result.distance.clamp(0.0, 1.0)) * 100)
        .round()
        .clamp(0, 100);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: thumb != null
                ? Image.memory(
                    base64Decode(thumb),
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 70,
                    height: 70,
                    color: CupertinoColors.systemGrey4,
                    child: const Icon(CupertinoIcons.photo,
                        color: CupertinoColors.systemGrey),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (result.vendor != null || result.model != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [result.vendor, result.model]
                        .where((e) => e != null && e.isNotEmpty)
                        .join(' · '),
                    style: const TextStyle(
                        fontSize: 12, color: CupertinoColors.systemGrey),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Podobieństwo: $distancePct% (dystans ${result.distance.toStringAsFixed(2)})',
                  style: const TextStyle(
                      fontSize: 11, color: CupertinoColors.systemBlue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

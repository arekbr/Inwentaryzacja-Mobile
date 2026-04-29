import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _urlCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  bool _hydrated = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    settingsAsync.whenData((s) {
      if (!_hydrated) {
        _urlCtrl.text = s.apiUrl;
        _tokenCtrl.text = s.apiToken;
        _hydrated = true;
      }
    });

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Ustawienia'),
      ),
      child: SafeArea(
        child: settingsAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (e, _) => Center(child: Text('Błąd: $e')),
          data: (_) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('URL backendu',
                  style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
              const SizedBox(height: 6),
              CupertinoTextField(
                controller: _urlCtrl,
                placeholder: 'https://api.example.com',
                keyboardType: TextInputType.url,
                autocorrect: false,
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 20),
              const Text('Token API',
                  style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
              const SizedBox(height: 6),
              CupertinoTextField(
                controller: _tokenCtrl,
                placeholder: 'Bearer token',
                obscureText: true,
                autocorrect: false,
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 28),
              CupertinoButton.filled(
                onPressed: () async {
                  await ref.read(settingsProvider.notifier).save(
                        apiUrl: _urlCtrl.text,
                        apiToken: _tokenCtrl.text,
                      );
                  if (!context.mounted) return;
                  await showCupertinoDialog<void>(
                    context: context,
                    builder: (ctx) => CupertinoAlertDialog(
                      title: const Text('Zapisano'),
                      content: const Text('Ustawienia zostały zapisane.'),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Zapisz'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

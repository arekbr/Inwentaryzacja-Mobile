import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_page.dart';
import '../settings/settings_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Inwentaryzacja'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Inwentaryzacja Mobile',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Flutter rewrite — etap F3',
                style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(height: 24),
              settingsAsync.when(
                loading: () => const CupertinoActivityIndicator(),
                error: (e, _) => Text('Błąd ustawień: $e'),
                data: (s) => Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6.resolveFrom(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('Backend URL', s.apiUrl.isEmpty ? '— brak —' : s.apiUrl),
                      const SizedBox(height: 6),
                      _row('Token API',
                          s.apiToken.isEmpty ? '— brak —' : '••• (${s.apiToken.length} zn.)'),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              CupertinoButton.filled(
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const SettingsPage()),
                ),
                child: const Text('Ustawienia'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: CupertinoColors.systemGrey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );
}

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_provider.dart';
import '../api/health.dart';
import '../photo/camera_page.dart';
import '../settings/settings_page.dart';
import '../similar/similar_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Color _statusColor(HealthStatus s) => switch (s) {
        HealthStatus.ok => CupertinoColors.activeGreen,
        HealthStatus.backendDown => CupertinoColors.destructiveRed,
        HealthStatus.tokenInvalid => CupertinoColors.systemOrange,
        HealthStatus.notConfigured => CupertinoColors.systemGrey,
      };

  String _statusLabel(HealthStatus s) => switch (s) {
        HealthStatus.ok => 'OK',
        HealthStatus.backendDown => 'Backend niedostępny',
        HealthStatus.tokenInvalid => 'Token niepoprawny',
        HealthStatus.notConfigured => 'Nieskonfigurowane',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(healthProvider);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Inwentaryzacja'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => ref.invalidate(healthProvider),
          child: const Icon(CupertinoIcons.refresh),
        ),
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
                'Flutter rewrite — etap F4',
                style: TextStyle(
                    fontSize: 14, color: CupertinoColors.systemGrey),
              ),
              const SizedBox(height: 20),
              _buildHealthPanel(context, healthAsync),
              if (healthAsync.asData?.value.status ==
                  HealthStatus.notConfigured) ...[
                const SizedBox(height: 14),
                _buildOnboarding(context),
              ],
              const Spacer(),
              CupertinoButton.filled(
                onPressed: healthAsync.asData?.value.isOk == true
                    ? () => Navigator.of(context).push(
                          CupertinoPageRoute(
                              builder: (_) => const CameraPage()),
                        )
                    : null,
                child: const Text('Zrób zdjęcie eksponatu'),
              ),
              const SizedBox(height: 10),
              CupertinoButton(
                color: CupertinoColors.systemGrey5,
                onPressed: healthAsync.asData?.value.isOk == true
                    ? () => Navigator.of(context).push(
                          CupertinoPageRoute(
                              builder: (_) => const SimilarPage()),
                        )
                    : null,
                child: const Text('Znajdź podobne',
                    style: TextStyle(color: CupertinoColors.label)),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
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

  Widget _buildHealthPanel(
      BuildContext context, AsyncValue<HealthInfo> healthAsync) {
    final bg = CupertinoColors.systemGrey6.resolveFrom(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: healthAsync.when(
        loading: () => const Row(
          children: [
            CupertinoActivityIndicator(),
            SizedBox(width: 12),
            Text('Sprawdzam backend…'),
          ],
        ),
        error: (e, _) => Row(
          children: [
            const Icon(CupertinoIcons.exclamationmark_triangle,
                color: CupertinoColors.destructiveRed),
            const SizedBox(width: 8),
            Expanded(child: Text('Błąd: $e')),
          ],
        ),
        data: (h) {
          final color = _statusColor(h.status);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _statusLabel(h.status),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: color),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(h.message,
                  style: const TextStyle(fontSize: 13, color: CupertinoColors.label)),
              if (h.isOk) ...[
                const SizedBox(height: 12),
                _kv('Wersja', h.version ?? '?'),
                _kv('Baza', h.database ?? '?'),
                _kv('Eksponaty', '${h.exhibitsCount ?? '?'}'),
                _kv('CLIP index', '${h.clipIndexSize ?? '?'}'),
                if (h.mockIdentify == true)
                  _kv('Tryb', 'MOCK identify (DEV)'),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildOnboarding(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: CupertinoColors.systemBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(CupertinoIcons.info_circle,
                  color: CupertinoColors.systemBlue, size: 20),
              SizedBox(width: 8),
              Text('Witaj w Inwentaryzacji',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.systemBlue)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Apka wymaga własnego self-hosted backendu (FastAPI + MariaDB + CLIP). '
            'Wpisz URL i token w Ustawieniach. Pełna instrukcja konfiguracji w README projektu.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: CupertinoColors.systemGrey)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}

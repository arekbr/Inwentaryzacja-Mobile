import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_provider.dart';
import 'api_client.dart';
import 'health.dart';

final apiClientProvider = Provider.autoDispose<ApiClient?>((ref) {
  final settings = ref.watch(settingsProvider).asData?.value;
  if (settings == null) return null;
  final client = ApiClient(baseUrl: settings.apiUrl, token: settings.apiToken);
  ref.onDispose(client.dispose);
  return client;
});

final healthProvider = FutureProvider.autoDispose<HealthInfo>((ref) async {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    return const HealthInfo(
      status: HealthStatus.notConfigured,
      message: 'Ładowanie ustawień…',
    );
  }
  return client.checkHealth();
});

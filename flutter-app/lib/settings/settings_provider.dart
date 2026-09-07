import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_state.dart';

const _kApiUrl = 'api_url';
const _kApiToken = 'api_token';

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      apiUrl: prefs.getString(_kApiUrl) ?? '',
      apiToken: prefs.getString(_kApiToken) ?? '',
    );
  }

  Future<void> save({required String apiUrl, required String apiToken}) async {
    state = const AsyncValue.loading();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiUrl, apiUrl.trim());
    await prefs.setString(_kApiToken, apiToken.trim());
    state = AsyncValue.data(
      AppSettings(apiUrl: apiUrl.trim(), apiToken: apiToken.trim()),
    );
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

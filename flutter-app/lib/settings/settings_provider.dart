import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_state.dart';

const _kApiUrl = 'api_url';
const _kApiToken = 'api_token';

const _secureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      apiUrl: prefs.getString(_kApiUrl) ?? '',
      apiToken: await _readToken(prefs),
    );
  }

  Future<String> _readToken(SharedPreferences prefs) async {
    final legacyToken = prefs.getString(_kApiToken);
    try {
      if (legacyToken == null) {
        return await _secureStorage.read(key: _kApiToken) ?? '';
      }
      await _secureStorage.write(key: _kApiToken, value: legacyToken);
      if (await _secureStorage.read(key: _kApiToken) == legacyToken) {
        await prefs.remove(_kApiToken);
      }
    } on PlatformException {
      // Bez Pęku kluczy aplikacja ma się otworzyć; błąd zapisu pokaże ekran Ustawień.
    }
    return legacyToken ?? '';
  }

  Future<void> save({required String apiUrl, required String apiToken}) async {
    final url = apiUrl.trim();
    final token = apiToken.trim();
    if (token.isEmpty) {
      await _secureStorage.delete(key: _kApiToken);
    } else {
      await _secureStorage.write(key: _kApiToken, value: token);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiUrl, url);
    state = AsyncValue.data(AppSettings(apiUrl: url, apiToken: token));
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

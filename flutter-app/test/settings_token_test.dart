import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'api_token';
const _urlKey = 'api_url';
const _secure = FlutterSecureStorage();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('zapis: token w sejfie systemowym, nigdy w preferencjach', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(settingsProvider.future);

    await container
        .read(settingsProvider.notifier)
        .save(apiUrl: 'https://a.test', apiToken: 'token-do-sejfu');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_tokenKey), isNull);
    expect(prefs.getString(_urlKey), 'https://a.test');
    expect(await _secure.read(key: _tokenKey), 'token-do-sejfu');
  });

  test('odczyt: token z sejfu wraca po ponownym uruchomieniu', () async {
    FlutterSecureStorage.setMockInitialValues({_tokenKey: 'token-z-sejfu'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settings = await container.read(settingsProvider.future);

    expect(settings.apiToken, 'token-z-sejfu');
  });

  test('migracja: stary token przechodzi do sejfu i znika z preferencji',
      () async {
    SharedPreferences.setMockInitialValues({_tokenKey: 'stary-token'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settings = await container.read(settingsProvider.future);

    expect(settings.apiToken, 'stary-token');
    expect(await _secure.read(key: _tokenKey), 'stary-token');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_tokenKey), isNull);
  });

  test('puste pole usuwa token z sejfu', () async {
    FlutterSecureStorage.setMockInitialValues({_tokenKey: 'do-usuniecia'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(settingsProvider.future);

    await container
        .read(settingsProvider.notifier)
        .save(apiUrl: 'https://a.test', apiToken: '   ');

    expect(await _secure.read(key: _tokenKey), isNull);
  });
}

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:mobile/api/api_client.dart';
import 'package:mobile/api/api_provider.dart';
import 'package:mobile/photo/camera_page.dart';
import 'package:mobile/settings/settings_page.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _consentKey = 'ai_consent_v1';

class _FakePicker extends ImagePickerPlatform with MockPlatformInterfaceMixin {
  _FakePicker(this.path);

  final String path;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async =>
      XFile(path);
}

/// Oddaje czas prawdziwemu wejściu-wyjściu i przebudowuje widżety.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Długi dialog bywa przewijany w małym oknie testowym, więc najpierw odsłania przycisk.
Future<void> _tapInDialog(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await _settle(tester);
}

/// Otwiera ekran zdjęcia z wybranym zdjęciem i zwraca licznik żądań do backendu.
Future<int Function()> _openCameraWithPhoto(WidgetTester tester) async {
  var requests = 0;
  final client = ApiClient(
    baseUrl: 'https://test.invalid',
    token: 'token-testowy',
    client: MockClient((request) async {
      requests++;
      return http.Response('{}', 500);
    }),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiClientProvider.overrideWith((ref) => client)],
      child: const CupertinoApp(home: CameraPage()),
    ),
  );
  await tester.tap(find.text('Z biblioteki'));
  await _settle(tester);
  expect(find.textContaining('Zdjęcie do wysłania'), findsOneWidget);
  return () => requests;
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('ai_consent_test');
    final photo = File('${tempDir.path}/photo.jpg')
      ..writeAsBytesSync(img.encodeJpg(img.Image(width: 8, height: 8)));
    ImagePickerPlatform.instance = _FakePicker(photo.path);
  });

  tearDownAll(() => tempDir.deleteSync(recursive: true));

  testWidgets('bez zgody zdjęcie nie wychodzi, a ekran nazywa Anthropic',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final requests = await _openCameraWithPhoto(tester);

    await tester.tap(find.text('Zidentyfikuj'));
    await _settle(tester);

    expect(find.textContaining('Anthropic'), findsWidgets);
    await _tapInDialog(tester, 'Nie teraz');

    expect(find.text('Nie teraz'), findsNothing);
    expect(find.textContaining('wymaga zgody'), findsOneWidget);
    expect(requests(), 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_consentKey), isNot(true));
  });

  testWidgets('po zgodzie zdjęcie wychodzi, a zgoda zostaje zapamiętana',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final requests = await _openCameraWithPhoto(tester);

    await tester.tap(find.text('Zidentyfikuj'));
    await _settle(tester);
    await _tapInDialog(tester, 'Zgadzam się');

    expect(find.text('Zgadzam się'), findsNothing);
    expect(requests(), 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_consentKey), isTrue);
  });

  testWidgets('zapisana zgoda: bez ponownego pytania', (tester) async {
    SharedPreferences.setMockInitialValues({_consentKey: true});
    final requests = await _openCameraWithPhoto(tester);

    await tester.tap(find.text('Zidentyfikuj'));
    await _settle(tester);

    expect(find.text('Nie teraz'), findsNothing);
    expect(requests(), 1);
  });

  testWidgets('Ustawienia: zgodę da się wycofać, a polityka jest pod ręką',
      (tester) async {
    SharedPreferences.setMockInitialValues({_consentKey: true});
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(child: CupertinoApp(home: SettingsPage())),
    );
    await _settle(tester);

    expect(find.text('Polityka prywatności'), findsOneWidget);
    await tester.tap(find.byType(CupertinoSwitch));
    await _settle(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_consentKey), isFalse);
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/api/api_client.dart';
import 'package:mobile/api/api_provider.dart';
import 'package:mobile/main.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Zrzuty do App Store. Adres i token przychodzą z `--dart-define-from-file`, spoza repo.
const _url = String.fromEnvironment('DEMO_URL');
const _token = String.fromEnvironment('DEMO_TOKEN');

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

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 150; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Nie pojawiło się: $finder');
}

Future<void> _settleImages(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _back(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await _settleImages(tester);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('zrzuty ekranów', (tester) async {
    expect(_url, isNotEmpty);
    expect(_token, isNotEmpty);

    final client = ApiClient(baseUrl: _url, token: _token);
    final first = await client.listExhibits(page: 1, perPage: 5);
    final thumbnail =
        first.results.firstWhere((e) => e.thumbnailB64 != null).thumbnailB64!;
    final photo = File('${Directory.systemTemp.path}/zrzut-eksponat.jpg')
      ..writeAsBytesSync(base64Decode(thumbnail));
    ImagePickerPlatform.instance = _FakePicker(photo.path);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWith((ref) => client)],
        child: const InwentaryzacjaApp(),
      ),
    );
    await _waitFor(tester, find.text('Eksponaty'));
    await _settleImages(tester);
    await binding.takeScreenshot('1-start');

    await tester.tap(find.text('Przeglądaj bazę'));
    await _waitFor(tester, find.textContaining('Eksponaty w bazie'));
    await _settleImages(tester);
    await binding.takeScreenshot('2-baza');

    await tester.tap(find.text('ATARI STFM'));
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 4; i++) {
      await _settleImages(tester);
    }
    await binding.takeScreenshot('3-szczegoly');

    await _back(tester);
    await _back(tester);

    await tester.tap(find.text('Znajdź podobne'));
    await _settleImages(tester);
    await tester.tap(find.text('Z biblioteki'));
    await _settleImages(tester);
    await tester.tap(find.text('Szukaj'));
    await _waitFor(tester, find.textContaining('Podobieństwo'));
    await _settleImages(tester);
    await binding.takeScreenshot('4-podobne');

    await _back(tester);

    await tester.tap(find.text('Zrób zdjęcie eksponatu'));
    await _settleImages(tester);
    await tester.tap(find.text('Z biblioteki'));
    await _waitFor(tester, find.textContaining('Zdjęcie do wysłania'));
    await tester.tap(find.text('Zidentyfikuj'));
    await _waitFor(tester, find.text('Zgadzam się'));
    await _settleImages(tester);
    await binding.takeScreenshot('5-zgoda');
  });
}

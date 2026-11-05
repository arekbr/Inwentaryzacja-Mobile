import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/api/api_provider.dart';
import 'package:mobile/api/health.dart';
import 'package:mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Największy systemowy rozmiar tekstu iOS (Dostępność) daje skalę około 3,12.
const _largestSystemTextScale = 3.12;

const _ready = HealthInfo(status: HealthStatus.ok, message: 'OK');
const _notConfigured = HealthInfo(
  status: HealthStatus.notConfigured,
  message: 'Brak URL backendu — skonfiguruj w Ustawieniach.',
);

Future<void> _pumpApp(WidgetTester tester, HealthInfo health) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = _largestSystemTextScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [healthProvider.overrideWith((ref) async => health)],
      child: const InwentaryzacjaApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _open(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('nieskonfigurowana aplikacja: Ustawienia są osiągalne',
      (tester) async {
    await _pumpApp(tester, _notConfigured);

    await _open(tester, 'Ustawienia');

    expect(find.text('URL backendu'), findsOneWidget);
  });

  testWidgets('ekran zdjęcia: wszystkie przyciski są osiągalne', (tester) async {
    await _pumpApp(tester, _ready);

    await _open(tester, 'Zrób zdjęcie eksponatu');

    for (final label in ['Z biblioteki', 'Aparat', 'Zidentyfikuj']) {
      await tester.ensureVisible(find.text(label));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(label).hitTestable(), findsOneWidget, reason: label);
    }
  });

  testWidgets('ekran podobnych: otwiera się bez rozsypania układu',
      (tester) async {
    await _pumpApp(tester, _ready);

    await _open(tester, 'Znajdź podobne');

    expect(find.text('Z biblioteki').hitTestable(), findsOneWidget);
  });
}

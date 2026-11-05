import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api/api_client.dart';
import 'package:mobile/api/api_provider.dart';
import 'package:mobile/api/health.dart';
import 'package:mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ready = HealthInfo(status: HealthStatus.ok, message: 'OK');

/// Próbka w kształcie odpowiedzi `ExhibitListResponse` z backendu.
http.Response _page(int page, List<String> names, {required bool hasMore}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode({
        'results': [
          for (final name in names)
            {
              'id': 'id-$name',
              'name': name,
              'vendor': 'Commodore',
              'model': null,
              'thumbnail_b64': null,
            },
        ],
        'total': 3,
        'page': page,
        'per_page': 50,
        'has_more': hasMore,
      })),
      200,
      headers: {'content-type': 'application/json'},
    );

Future<void> _openBrowse(WidgetTester tester, MockClient client) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final api = ApiClient(baseUrl: 'https://test.invalid', token: 't', client: client);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        healthProvider.overrideWith((ref) async => _ready),
        apiClientProvider.overrideWith((ref) => api),
      ],
      child: const InwentaryzacjaApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.text('Przeglądaj bazę'));
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('lista pokazuje eksponaty i dociąga kolejną stronę', (tester) async {
    final requested = <String>[];
    await _openBrowse(tester, MockClient((request) async {
      requested.add(request.url.query);
      return request.url.queryParameters['page'] == '1'
          ? _page(1, ['Amiga 500', 'Atari ST'], hasMore: true)
          : _page(2, ['VIC-20'], hasMore: false);
    }));

    expect(find.text('Amiga 500'), findsOneWidget);
    expect(find.text('VIC-20'), findsOneWidget);
    expect(find.textContaining('3'), findsWidgets);
    expect(requested.length, 2);
  });

  testWidgets('stuknięcie otwiera szczegóły właściwego eksponatu', (tester) async {
    final paths = <String>[];
    await _openBrowse(tester, MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/api/v1/exhibits')) {
        return _page(1, ['Amiga 500'], hasMore: false);
      }
      return http.Response('{}', 500);
    }));

    await tester.tap(find.text('Amiga 500'));
    await _settle(tester);

    expect(paths, contains('/api/v1/exhibits/id-Amiga%20500'));
  });

  testWidgets('błąd sieci: komunikat i działające „Ponów”', (tester) async {
    var attempts = 0;
    await _openBrowse(tester, MockClient((request) async {
      attempts++;
      return attempts == 1
          ? http.Response('{}', 500)
          : _page(1, ['Amiga 500'], hasMore: false);
    }));

    expect(find.text('Ponów'), findsOneWidget);
    await tester.tap(find.text('Ponów'));
    await _settle(tester);

    expect(find.text('Amiga 500'), findsOneWidget);
    expect(find.text('Ponów'), findsNothing);
  });

  testWidgets('pusta baza: czytelna informacja', (tester) async {
    await _openBrowse(tester, MockClient((request) async {
      return _page(1, const [], hasMore: false);
    }));

    expect(find.text('Brak eksponatów'), findsOneWidget);
  });

  testWidgets('największy tekst: lista się nie rozsypuje', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 3.12;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final api = ApiClient(
      baseUrl: 'https://test.invalid',
      token: 't',
      client: MockClient((request) async {
        return _page(1, ['Bardzo długa nazwa eksponatu Commodore Amiga 1200'],
            hasMore: false);
      }),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthProvider.overrideWith((ref) async => _ready),
          apiClientProvider.overrideWith((ref) => api),
        ],
        child: const InwentaryzacjaApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.ensureVisible(find.text('Przeglądaj bazę'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Przeglądaj bazę'));
    await _settle(tester);

    expect(find.textContaining('Bardzo długa'), findsOneWidget);
  });
}

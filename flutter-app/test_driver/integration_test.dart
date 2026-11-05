import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Zapisuje zrzuty zrobione przez aplikację w trakcie testu.
Future<void> main() => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final folder = Platform.environment['ZRZUTY_KATALOG']!;
        await File('$folder/$name.png').writeAsBytes(bytes);
        return true;
      },
    );

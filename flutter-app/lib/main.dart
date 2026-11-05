import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/home_page.dart';

void main() {
  runApp(const ProviderScope(child: InwentaryzacjaApp()));
}

const _maxTextScale = 2.0;

Widget _limitTextScale(BuildContext context, Widget? child) =>
    MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: child!,
    );

class InwentaryzacjaApp extends StatelessWidget {
  const InwentaryzacjaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Inwentaryzacja',
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.activeBlue,
      ),
      builder: _limitTextScale,
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

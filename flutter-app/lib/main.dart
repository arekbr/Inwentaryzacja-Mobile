import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/home_page.dart';

void main() {
  runApp(const ProviderScope(child: InwentaryzacjaApp()));
}

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
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

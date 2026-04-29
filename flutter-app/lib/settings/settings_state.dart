import 'package:flutter/foundation.dart';

@immutable
class AppSettings {
  final String apiUrl;
  final String apiToken;

  const AppSettings({required this.apiUrl, required this.apiToken});

  static const empty = AppSettings(apiUrl: '', apiToken: '');

  AppSettings copyWith({String? apiUrl, String? apiToken}) => AppSettings(
        apiUrl: apiUrl ?? this.apiUrl,
        apiToken: apiToken ?? this.apiToken,
      );
}

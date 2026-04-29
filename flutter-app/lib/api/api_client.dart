import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'health.dart';

class ApiClient {
  ApiClient({required this.baseUrl, required this.token, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final String token;
  final http.Client _client;

  static const _timeout = Duration(seconds: 5);

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _authHeaders() => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

  Future<HealthInfo> checkHealth() async {
    if (baseUrl.trim().isEmpty) {
      return const HealthInfo(
        status: HealthStatus.notConfigured,
        message: 'Brak URL backendu — skonfiguruj w Ustawieniach.',
      );
    }
    if (token.trim().isEmpty) {
      return const HealthInfo(
        status: HealthStatus.notConfigured,
        message: 'Brak tokena API — skonfiguruj w Ustawieniach.',
      );
    }

    Map<String, dynamic> healthJson;
    try {
      final r = await _client.get(_uri('/health')).timeout(_timeout);
      if (r.statusCode != 200) {
        return HealthInfo(
          status: HealthStatus.backendDown,
          message: 'Backend odpowiedział ${r.statusCode} na /health.',
        );
      }
      healthJson = jsonDecode(r.body) as Map<String, dynamic>;
    } on TimeoutException {
      return const HealthInfo(
        status: HealthStatus.backendDown,
        message: 'Backend nie odpowiada (timeout 5 s).',
      );
    } catch (e) {
      return HealthInfo(
        status: HealthStatus.backendDown,
        message: 'Błąd połączenia: $e',
      );
    }

    try {
      final r = await _client
          .get(_uri('/api/v1/dictionaries/types'), headers: _authHeaders())
          .timeout(_timeout);
      if (r.statusCode == 200) {
        return HealthInfo(
          status: HealthStatus.ok,
          message: 'Backend OK, token poprawny.',
          version: healthJson['version'] as String?,
          database: healthJson['database'] as String?,
          exhibitsCount: (healthJson['exhibits_count'] as num?)?.toInt(),
          clipIndexSize: (healthJson['clip_index_size'] as num?)?.toInt(),
          mockIdentify: healthJson['mock_identify'] as bool?,
        );
      }
      if (r.statusCode == 401 || r.statusCode == 403) {
        return const HealthInfo(
          status: HealthStatus.tokenInvalid,
          message: 'Backend OK, ale token niepoprawny — sprawdź Ustawienia.',
        );
      }
      return HealthInfo(
        status: HealthStatus.tokenInvalid,
        message: 'Weryfikacja tokenu zwróciła ${r.statusCode}.',
      );
    } on TimeoutException {
      return const HealthInfo(
        status: HealthStatus.tokenInvalid,
        message: 'Weryfikacja tokenu — timeout.',
      );
    } catch (e) {
      return HealthInfo(
        status: HealthStatus.tokenInvalid,
        message: 'Weryfikacja tokenu nieudana: $e',
      );
    }
  }

  void dispose() => _client.close();
}

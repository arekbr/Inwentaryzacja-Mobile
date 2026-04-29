import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../identify/artefakt.dart';
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

  Future<Artefakt> identify(Uint8List jpegBytes,
      {String filename = 'photo.jpg'}) async {
    final req = http.MultipartRequest('POST', _uri('/api/v1/identify'))
      ..headers.addAll(_authHeaders())
      ..files.add(http.MultipartFile.fromBytes('images', jpegBytes,
          filename: filename));

    final streamed = await _client.send(req).timeout(const Duration(seconds: 45));
    final r = await http.Response.fromStream(streamed);

    if (r.statusCode != 200) {
      throw _ApiError(r.statusCode, _errorMessage(r));
    }
    final json = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    return Artefakt.fromJson(json);
  }

  String _errorMessage(http.Response r) {
    if (r.statusCode == 401 || r.statusCode == 403) {
      return 'Token niepoprawny lub wygasły.';
    }
    if (r.statusCode == 413) return 'Zdjęcie zbyt duże dla backendu.';
    if (r.statusCode == 429) return 'Limit zapytań osiągnięty — spróbuj za chwilę.';
    if (r.statusCode == 502 || r.statusCode == 503) {
      return 'AI niedostępne (HTTP ${r.statusCode}).';
    }
    try {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final detail = body['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) return detail.first.toString();
    } catch (_) {}
    return 'Błąd HTTP ${r.statusCode}';
  }

  void dispose() => _client.close();
}

class _ApiError implements Exception {
  final int status;
  final String message;
  _ApiError(this.status, this.message);
  @override
  String toString() => message;
}

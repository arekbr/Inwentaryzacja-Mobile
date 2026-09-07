import 'package:flutter/foundation.dart';

enum HealthStatus { ok, backendDown, tokenInvalid, notConfigured }

@immutable
class HealthInfo {
  final HealthStatus status;
  final String message;
  final String? version;
  final String? database;
  final int? exhibitsCount;
  final int? clipIndexSize;
  final bool? mockIdentify;

  const HealthInfo({
    required this.status,
    required this.message,
    this.version,
    this.database,
    this.exhibitsCount,
    this.clipIndexSize,
    this.mockIdentify,
  });

  bool get isOk => status == HealthStatus.ok;
}

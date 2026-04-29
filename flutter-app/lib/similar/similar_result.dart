import 'package:flutter/foundation.dart';

@immutable
class SimilarResult {
  final String exhibitId;
  final String name;
  final String? vendor;
  final String? model;
  final double distance;
  final String? thumbnailB64;

  const SimilarResult({
    required this.exhibitId,
    required this.name,
    required this.vendor,
    required this.model,
    required this.distance,
    required this.thumbnailB64,
  });

  factory SimilarResult.fromJson(Map<String, dynamic> j) => SimilarResult(
        exhibitId: j['exhibit_id'] as String,
        name: j['name'] as String? ?? '',
        vendor: j['vendor'] as String?,
        model: j['model'] as String?,
        distance: (j['distance'] as num?)?.toDouble() ?? 99.0,
        thumbnailB64: j['thumbnail_b64'] as String?,
      );
}

@immutable
class SimilarResponse {
  final List<SimilarResult> results;
  final int indexSize;

  const SimilarResponse({required this.results, required this.indexSize});

  factory SimilarResponse.fromJson(Map<String, dynamic> j) => SimilarResponse(
        results: ((j['results'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(SimilarResult.fromJson)
            .toList(growable: false),
        indexSize: (j['index_size'] as num?)?.toInt() ?? 0,
      );
}

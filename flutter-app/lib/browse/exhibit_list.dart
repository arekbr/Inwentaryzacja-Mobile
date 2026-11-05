class ExhibitListItem {
  const ExhibitListItem({
    required this.id,
    required this.name,
    this.vendor,
    this.model,
    this.thumbnailB64,
  });

  factory ExhibitListItem.fromJson(Map<String, dynamic> json) => ExhibitListItem(
        id: json['id'] as String,
        name: json['name'] as String,
        vendor: json['vendor'] as String?,
        model: json['model'] as String?,
        thumbnailB64: json['thumbnail_b64'] as String?,
      );

  final String id;
  final String name;
  final String? vendor;
  final String? model;
  final String? thumbnailB64;
}

class ExhibitListResponse {
  const ExhibitListResponse({
    required this.results,
    required this.total,
    required this.page,
    required this.hasMore,
  });

  factory ExhibitListResponse.fromJson(Map<String, dynamic> json) =>
      ExhibitListResponse(
        results: (json['results'] as List<dynamic>)
            .map((e) => ExhibitListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
        page: json['page'] as int,
        hasMore: json['has_more'] as bool,
      );

  final List<ExhibitListItem> results;
  final int total;
  final int page;
  final bool hasMore;
}

import 'package:flutter/foundation.dart';

@immutable
class ExhibitDetail {
  final String id;
  final String name;
  final String? type;
  final String? vendor;
  final String? model;
  final String? serialNumber;
  final String? partNumber;
  final String? revision;
  final int? productionYear;
  final String? status;
  final String? storagePlace;
  final String? description;
  final bool hasOriginalPackaging;
  final String? photoB64;
  final int photosCount;

  const ExhibitDetail({
    required this.id,
    required this.name,
    this.type,
    this.vendor,
    this.model,
    this.serialNumber,
    this.partNumber,
    this.revision,
    this.productionYear,
    this.status,
    this.storagePlace,
    this.description,
    this.hasOriginalPackaging = false,
    this.photoB64,
    this.photosCount = 0,
  });

  factory ExhibitDetail.fromJson(Map<String, dynamic> j) => ExhibitDetail(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        type: j['type'] as String?,
        vendor: j['vendor'] as String?,
        model: j['model'] as String?,
        serialNumber: j['serial_number'] as String?,
        partNumber: j['part_number'] as String?,
        revision: j['revision'] as String?,
        productionYear: (j['production_year'] as num?)?.toInt(),
        status: j['status'] as String?,
        storagePlace: j['storage_place'] as String?,
        description: j['description'] as String?,
        hasOriginalPackaging: j['has_original_packaging'] as bool? ?? false,
        photoB64: j['photo_b64'] as String?,
        photosCount: (j['photos_count'] as num?)?.toInt() ?? 0,
      );
}

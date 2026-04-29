import 'package:flutter/foundation.dart';

@immutable
class DictItem {
  final String id;
  final String name;
  final String? vendorId;

  const DictItem({required this.id, required this.name, this.vendorId});

  factory DictItem.fromJson(Map<String, dynamic> j) => DictItem(
        id: j['id'] as String,
        name: j['name'] as String,
        vendorId: j['vendor_id'] as String?,
      );
}

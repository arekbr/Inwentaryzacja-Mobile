import 'package:flutter/foundation.dart';

import '../identify/artefakt.dart';

@immutable
class ExhibitForm {
  final String name;
  final String type;
  final String vendor;
  final String model;
  final String serialNumber;
  final String partNumber;
  final String revision;
  final String productionYear;
  final String status;
  final String storagePlace;
  final String description;
  final String value;
  final bool hasOriginalPackaging;

  const ExhibitForm({
    required this.name,
    required this.type,
    required this.vendor,
    required this.model,
    required this.serialNumber,
    required this.partNumber,
    required this.revision,
    required this.productionYear,
    required this.status,
    required this.storagePlace,
    required this.description,
    required this.value,
    required this.hasOriginalPackaging,
  });

  factory ExhibitForm.fromArtefakt(Artefakt a) => ExhibitForm(
        name: a.name,
        type: a.type,
        vendor: a.vendor ?? '',
        model: a.model ?? '',
        serialNumber: a.serialNumber ?? '',
        partNumber: a.partNumber ?? '',
        revision: a.revision ?? '',
        productionYear: a.productionYear?.toString() ?? '',
        status: a.status,
        storagePlace: '',
        description: a.description,
        value: '',
        hasOriginalPackaging: a.hasOriginalPackaging,
      );

  /// Walidacja zwraca null gdy OK, lub komunikat błędu.
  String? validate() {
    if (name.trim().isEmpty) return 'Nazwa jest wymagana.';
    if (type.trim().isEmpty) return 'Typ jest wymagany.';
    if (vendor.trim().isEmpty) return 'Producent jest wymagany.';
    if (model.trim().isEmpty) return 'Model jest wymagany.';
    if (status.trim().isEmpty) return 'Status jest wymagany.';
    if (storagePlace.trim().isEmpty) return 'Miejsce przechowywania jest wymagane.';
    if (productionYear.trim().isNotEmpty) {
      final y = int.tryParse(productionYear.trim());
      if (y == null || y < 1900 || y > 2100) {
        return 'Rok produkcji musi być w zakresie 1900-2100.';
      }
    }
    if (value.trim().isNotEmpty) {
      final v = int.tryParse(value.trim());
      if (v == null || v < 0) return 'Wartość musi być liczbą nieujemną.';
    }
    return null;
  }
}

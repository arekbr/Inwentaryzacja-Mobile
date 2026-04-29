import 'package:flutter/foundation.dart';

@immutable
class Analiza {
  final List<String> widoczneOznaczenia;
  final List<String> cechyIdentyfikacyjne;
  final double pewnosc;
  final bool wymagaWeryfikacji;
  final String notatkiDlaKuratora;
  final List<String> sugerowaneTagi;

  const Analiza({
    required this.widoczneOznaczenia,
    required this.cechyIdentyfikacyjne,
    required this.pewnosc,
    required this.wymagaWeryfikacji,
    required this.notatkiDlaKuratora,
    required this.sugerowaneTagi,
  });

  factory Analiza.fromJson(Map<String, dynamic> j) => Analiza(
        widoczneOznaczenia: List<String>.from(j['widoczne_oznaczenia'] ?? const []),
        cechyIdentyfikacyjne:
            List<String>.from(j['cechy_identyfikacyjne'] ?? const []),
        pewnosc: (j['pewnosc'] as num?)?.toDouble() ?? 0.0,
        wymagaWeryfikacji: j['wymaga_weryfikacji'] as bool? ?? false,
        notatkiDlaKuratora: j['notatki_dla_kuratora'] as String? ?? '',
        sugerowaneTagi: List<String>.from(j['sugerowane_tagi'] ?? const []),
      );
}

@immutable
class Artefakt {
  final String name;
  final String type;
  final String? vendor;
  final String? model;
  final String? serialNumber;
  final String? partNumber;
  final String? revision;
  final int? productionYear;
  final String status;
  final String description;
  final bool hasOriginalPackaging;
  final Analiza analiza;

  const Artefakt({
    required this.name,
    required this.type,
    required this.vendor,
    required this.model,
    required this.serialNumber,
    required this.partNumber,
    required this.revision,
    required this.productionYear,
    required this.status,
    required this.description,
    required this.hasOriginalPackaging,
    required this.analiza,
  });

  factory Artefakt.fromJson(Map<String, dynamic> j) => Artefakt(
        name: j['name'] as String? ?? '',
        type: j['type'] as String? ?? '',
        vendor: j['vendor'] as String?,
        model: j['model'] as String?,
        serialNumber: j['serial_number'] as String?,
        partNumber: j['part_number'] as String?,
        revision: j['revision'] as String?,
        productionYear: (j['production_year'] as num?)?.toInt(),
        status: j['status'] as String? ?? '',
        description: j['description'] as String? ?? '',
        hasOriginalPackaging: j['has_original_packaging'] as bool? ?? false,
        analiza: Analiza.fromJson(
            (j['analiza'] as Map<String, dynamic>?) ?? const {}),
      );
}

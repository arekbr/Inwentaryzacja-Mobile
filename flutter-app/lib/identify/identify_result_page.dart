import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import '../edit/edit_exhibit_page.dart';
import 'artefakt.dart';

class IdentifyResultPage extends StatelessWidget {
  final Artefakt artefakt;
  final String photoPath;
  final Uint8List photoBytes;

  const IdentifyResultPage({
    super.key,
    required this.artefakt,
    required this.photoPath,
    required this.photoBytes,
  });

  @override
  Widget build(BuildContext context) {
    final a = artefakt;
    final pewnoscPct = (a.analiza.pewnosc * 100).round();
    final pewnoscColor = pewnoscPct >= 80
        ? CupertinoColors.activeGreen
        : pewnoscPct >= 50
            ? CupertinoColors.systemOrange
            : CupertinoColors.destructiveRed;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Wynik AI')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(photoPath),
                  height: 200, fit: BoxFit.cover, width: double.infinity),
            ),
            const SizedBox(height: 16),
            Text(a.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: pewnoscColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Pewność: $pewnoscPct%',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: pewnoscColor),
                  ),
                ),
                if (a.analiza.wymagaWeryfikacji) ...[
                  const SizedBox(width: 8),
                  const Text('⚠ wymaga weryfikacji',
                      style: TextStyle(
                          fontSize: 12, color: CupertinoColors.systemOrange)),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _section('Identyfikacja', [
              _kv('Producent', a.vendor),
              _kv('Model', a.model),
              _kv('Typ', a.type),
              _kv('Rok', a.productionYear?.toString()),
              _kv('Status', a.status),
              _kv('Numer seryjny', a.serialNumber),
              _kv('Part number', a.partNumber),
              _kv('Rewizja', a.revision),
              _kv('Oryginalne pudło',
                  a.hasOriginalPackaging ? 'tak' : 'nie'),
            ]),
            const SizedBox(height: 16),
            _section('Opis', [
              if (a.description.isNotEmpty)
                Text(a.description,
                    style: const TextStyle(fontSize: 14, height: 1.4)),
            ]),
            if (a.analiza.widoczneOznaczenia.isNotEmpty)
              _chips('Widoczne oznaczenia', a.analiza.widoczneOznaczenia),
            if (a.analiza.cechyIdentyfikacyjne.isNotEmpty)
              _chips('Cechy identyfikacyjne', a.analiza.cechyIdentyfikacyjne),
            if (a.analiza.sugerowaneTagi.isNotEmpty)
              _chips('Sugerowane tagi', a.analiza.sugerowaneTagi),
            if (a.analiza.notatkiDlaKuratora.isNotEmpty)
              _section('Notatki dla kuratora', [
                Text(a.analiza.notatkiDlaKuratora,
                    style: const TextStyle(fontSize: 13, height: 1.4)),
              ]),
            const SizedBox(height: 24),
            Builder(builder: (ctx) => CupertinoButton.filled(
              onPressed: () => Navigator.of(ctx).push(
                CupertinoPageRoute(
                  builder: (_) => EditExhibitPage(
                    artefakt: a,
                    photoPath: photoPath,
                    photoBytes: photoBytes,
                  ),
                ),
              ),
              child: const Text('Edytuj i zapisz'),
            )),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _kv(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: CupertinoColors.systemGrey)),
          ),
          Expanded(
              child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _chips(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(t,
                          style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemBlue)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

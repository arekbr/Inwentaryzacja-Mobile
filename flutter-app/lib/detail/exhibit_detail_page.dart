import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_provider.dart';
import 'exhibit_detail.dart';

final _exhibitDetailProvider =
    FutureProvider.autoDispose.family<ExhibitDetail, String>((ref, id) async {
  final client = ref.watch(apiClientProvider);
  if (client == null) {
    throw StateError('Brak konfiguracji backendu.');
  }
  return client.getExhibit(id);
});

class ExhibitDetailPage extends ConsumerWidget {
  final String exhibitId;
  final String? fallbackName;

  const ExhibitDetailPage({
    super.key,
    required this.exhibitId,
    this.fallbackName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(_exhibitDetailProvider(exhibitId));
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(fallbackName ?? 'Eksponat'),
      ),
      child: SafeArea(
        child: detailAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Center(child: Text('Błąd: $e')),
          ),
          data: (d) => _buildDetail(context, d),
        ),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, ExhibitDetail d) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (d.photoB64 != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(d.photoB64!),
              height: 280,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          )
        else
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(CupertinoIcons.photo,
                  size: 48, color: CupertinoColors.systemGrey),
            ),
          ),
        const SizedBox(height: 16),
        Text(d.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        if (d.vendor != null || d.model != null) ...[
          const SizedBox(height: 4),
          Text(
            [d.vendor, d.model]
                .where((e) => e != null && e!.isNotEmpty)
                .join(' · '),
            style: const TextStyle(
                fontSize: 15, color: CupertinoColors.systemGrey),
          ),
        ],
        const SizedBox(height: 16),
        _grid(context, d),
        if (d.description != null && d.description!.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text('Opis',
              style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(d.description!,
              style: const TextStyle(fontSize: 14, height: 1.4)),
        ],
        const SizedBox(height: 18),
        Text(
          'ID: ${d.id}  ·  Zdjęć: ${d.photosCount}',
          style:
              const TextStyle(fontSize: 11, color: CupertinoColors.systemGrey),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _grid(BuildContext context, ExhibitDetail d) {
    final entries = <(String, String?)>[
      ('Typ', d.type),
      ('Status', d.status),
      ('Rok', d.productionYear?.toString()),
      ('Miejsce', d.storagePlace),
      ('Numer seryjny', d.serialNumber),
      ('Part number', d.partNumber),
      ('Rewizja', d.revision),
      ('Oryginalne pudło', d.hasOriginalPackaging ? 'tak' : 'nie'),
    ].where((e) => e.$2 != null && e.$2!.isNotEmpty).toList();

    final pairs = <List<(String, String)>>[];
    for (var i = 0; i < entries.length; i += 2) {
      pairs.add(entries
          .sublist(i, (i + 2 > entries.length) ? entries.length : i + 2)
          .map((e) => (e.$1, e.$2!))
          .toList());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in pairs)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(child: _cell(context, row[0].$1, row[0].$2)),
                const SizedBox(width: 8),
                if (row.length > 1)
                  Expanded(child: _cell(context, row[1].$1, row[1].$2))
                else
                  const Spacer(),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: CupertinoColors.systemGrey)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

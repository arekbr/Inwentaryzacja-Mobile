import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_provider.dart';
import '../detail/exhibit_detail_page.dart';
import 'exhibit_list.dart';

class BrowsePage extends ConsumerStatefulWidget {
  const BrowsePage({super.key});

  @override
  ConsumerState<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends ConsumerState<BrowsePage> {
  final _items = <ExhibitListItem>[];
  int _loadedPage = 0;
  int _total = 0;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  Future<void> _loadNextPage() async {
    if (_loading || !_hasMore) return;
    final client = ref.read(apiClientProvider);
    if (client == null) {
      setState(() => _error = 'Brak konfiguracji backendu.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await client.listExhibits(page: _loadedPage + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.results);
        _loadedPage = page.page;
        _total = page.total;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Przeglądaj bazę'),
      ),
      child: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _items.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) return _buildHeader();
            if (index == _items.length + 1) return _buildFooter();
            final item = _items[index - 1];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => ExhibitDetailPage(
                    exhibitId: item.id,
                    fallbackName: item.name,
                  ),
                ),
              ),
              child: _ExhibitTile(item: item),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (_total == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        'Eksponaty w bazie: $_total',
        style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
      ),
    );
  }

  /// Stopka powstaje dopiero blisko końca listy, więc jej zbudowanie dociąga kolejną stronę.
  Widget _buildFooter() {
    if (_error != null) {
      return Column(
        children: [
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: CupertinoColors.destructiveRed),
          ),
          CupertinoButton(
            onPressed: _loadNextPage,
            child: const Text('Ponów'),
          ),
        ],
      );
    }
    if (_hasMore) {
      if (!_loading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadNextPage();
        });
      }
      return const Padding(
        padding: EdgeInsets.all(16),
        child: CupertinoActivityIndicator(),
      );
    }
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Brak eksponatów', textAlign: TextAlign.center),
      );
    }
    return const SizedBox.shrink();
  }
}

class _ExhibitTile extends StatelessWidget {
  const _ExhibitTile({required this.item});

  final ExhibitListItem item;

  @override
  Widget build(BuildContext context) {
    final thumbnail = item.thumbnailB64;
    final subtitle = [item.vendor, item.model]
        .where((e) => e != null && e.isNotEmpty)
        .join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: thumbnail != null
                ? Image.memory(
                    base64Decode(thumbnail),
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    cacheWidth: 210,
                  )
                : Container(
                    width: 70,
                    height: 70,
                    color: CupertinoColors.systemGrey4,
                    child: const Icon(
                      CupertinoIcons.photo,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            CupertinoIcons.chevron_forward,
            color: CupertinoColors.systemGrey,
            size: 18,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_provider.dart';
import 'dict_item.dart';

Future<List<DictItem>> _fetch(Ref ref, String slug) async {
  final client = ref.watch(apiClientProvider);
  if (client == null) return const [];
  return client.fetchDictionary(slug);
}

final typesProvider = FutureProvider.autoDispose<List<DictItem>>(
    (ref) => _fetch(ref, 'types'));
final vendorsProvider = FutureProvider.autoDispose<List<DictItem>>(
    (ref) => _fetch(ref, 'vendors'));
final modelsProvider = FutureProvider.autoDispose<List<DictItem>>(
    (ref) => _fetch(ref, 'models'));
final statusesProvider = FutureProvider.autoDispose<List<DictItem>>(
    (ref) => _fetch(ref, 'statuses'));
final storagePlacesProvider = FutureProvider.autoDispose<List<DictItem>>(
    (ref) => _fetch(ref, 'storage-places'));

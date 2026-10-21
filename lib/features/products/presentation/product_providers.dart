import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/http_client_provider.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(client: ref.watch(httpClientProvider));
});

/// Resultados de búsqueda por nombre. La pantalla debería aplicar debounce (~400 ms)
/// antes de cambiar el `query`: la búsqueda de OFF tiene un límite de consultas bajo.
final productSearchProvider =
    FutureProvider.autoDispose.family<List<Product>, String>((ref, query) {
  return ref.watch(productRepositoryProvider).searchByName(query);
});

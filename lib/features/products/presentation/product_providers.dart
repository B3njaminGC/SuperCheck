import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/http_client_provider.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(client: ref.watch(httpClientProvider));
});

/// Resultados de búsqueda por nombre. La pantalla solo cambia el `query` cuando la
/// persona deja de escribir un instante o toca la lupa: la búsqueda de OFF tiene un
/// límite de consultas bajo.
/// Los resultados buenos se guardan mientras la app esté abierta, así repetir una
/// búsqueda no vuelve a gastar consultas; los errores no se guardan.
final productSearchProvider =
    FutureProvider.autoDispose.family<List<Product>, String>((ref, query) async {
  final keep = ref.keepAlive();
  try {
    return await ref.watch(productRepositoryProvider).searchByName(query);
  } catch (_) {
    keep.close();
    rethrow;
  }
});

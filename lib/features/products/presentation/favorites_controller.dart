import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mode/app_mode.dart';
import '../data/favorites_repository.dart';
import '../domain/product.dart';
import 'my_products_controller.dart';

/// Favoritos tal como se guardaron (copias). Para mostrarlos usar [favoriteProductsProvider].
final favoritesProvider =
    NotifierProvider<FavoritesController, List<Product>>(FavoritesController.new);

class FavoritesController extends Notifier<List<Product>> {
  late final FavoritesRepository _repo =
      FavoritesRepository(ref.read(sharedPreferencesProvider));

  @override
  List<Product> build() => _repo.load();

  bool isFavorite(Product product) =>
      state.any((p) => p.favoriteKey == product.favoriteKey);

  /// Marca o desmarca. Los productos sin código de barras que no son propios no se
  /// pueden marcar (no hay cómo reconocerlos después).
  Future<void> toggle(Product product) async {
    if (!product.canBeFavorite) return;
    final key = product.favoriteKey;
    final next = isFavorite(product)
        ? [
            for (final p in state)
              if (p.favoriteKey != key) p,
          ]
        : [...state, product];
    state = next;
    await _repo.save(next);
  }
}

/// Favoritos listos para mostrar, por nombre. Los propios se toman de "Mis productos"
/// (así reflejan ediciones) y desaparecen si se borraron.
final favoriteProductsProvider = Provider<List<Product>>((ref) {
  final saved = ref.watch(favoritesProvider);
  final mine = ref.watch(myProductsProvider);
  final result = <Product>[];
  for (final p in saved) {
    if (p.libraryId == null) {
      result.add(p);
    } else {
      final current = mine.where((m) => m.libraryId == p.libraryId).firstOrNull;
      if (current != null) result.add(current);
    }
  }
  result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return result;
});

final favoriteKeysProvider = Provider<Set<String>>((ref) {
  return {for (final p in ref.watch(favoriteProductsProvider)) p.favoriteKey};
});

/// Marcas de los favoritos (en minúsculas): sus productos salen primero al buscar.
final favoriteBrandsProvider = Provider<Set<String>>((ref) {
  return {
    for (final p in ref.watch(favoriteProductsProvider))
      if (p.brand != null && p.brand!.trim().isNotEmpty) p.brand!.trim().toLowerCase(),
  };
});

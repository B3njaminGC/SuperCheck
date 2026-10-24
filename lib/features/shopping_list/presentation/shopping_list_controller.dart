import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mode/app_mode.dart';
import '../../../core/network/supabase_provider.dart';
import '../../../core/utils/barcode_utils.dart';
import '../../products/domain/product.dart';
import '../data/local_shopping_list_repository.dart';
import '../data/shopping_list_repository.dart';
import '../data/supabase_shopping_list_repository.dart';
import '../domain/shopping_item.dart';

/// Dónde se guardan las listas: en el teléfono (sin cuenta) o en Supabase (con cuenta),
/// según el modo elegido. El resto de la app no distingue entre uno y otro.
final shoppingListRepositoryProvider = Provider<ShoppingListRepository>((ref) {
  switch (ref.watch(appModeProvider)) {
    case AppMode.local:
      final repository =
          LocalShoppingListRepository(ref.watch(sharedPreferencesProvider));
      ref.onDispose(repository.dispose);
      return repository;
    case AppMode.cloud:
      return SupabaseShoppingListRepository(ref.watch(supabaseClientProvider));
  }
});

/// Estado de una lista concreta (el argumento es el `listId`).
///
/// El estado es un stream del repositorio (en la nube, Supabase Realtime: lo que
/// agregue o tache otro miembro llega solo). Las acciones se aplican de forma
/// optimista (la UI responde al instante) y se corrigen con el siguiente evento del
/// stream o si el guardado falla.
final shoppingListControllerProvider = StreamNotifierProvider.autoDispose
    .family<ShoppingListController, List<ShoppingItem>, String>(
  ShoppingListController.new,
);

class ShoppingListController
    extends AutoDisposeFamilyStreamNotifier<List<ShoppingItem>, String> {
  ShoppingListRepository get _repo => ref.read(shoppingListRepositoryProvider);

  List<ShoppingItem> get _items => state.valueOrNull ?? const [];

  @override
  Stream<List<ShoppingItem>> build(String listId) {
    return ref.watch(shoppingListRepositoryProvider).watchItems(listId).map(_sorted);
  }

  /// Pendientes primero (en orden de agregado), completos al final.
  static List<ShoppingItem> _sorted(List<ShoppingItem> items) {
    final copy = [...items];
    copy.sort((a, b) {
      if (a.isChecked != b.isChecked) return a.isChecked ? 1 : -1;
      return a.createdAt.compareTo(b.createdAt);
    });
    return copy;
  }

  void _emit(List<ShoppingItem> items) => state = AsyncData(_sorted(items));

  // --- Agregar ---------------------------------------------------------

  /// Agrega un producto. Si ya está pendiente en la lista (mismo código de barras),
  /// suma unidades en lugar de duplicar el renglón (o, con [checked], lo completa).
  /// Con [checked] un producto nuevo entra ya completo.
  Future<void> addProduct(
    Product product, {
    int quantity = 1,
    bool checked = false,
  }) async {
    final existing = _items
        .where((i) => !i.isChecked && BarcodeUtils.isSame(i.barcode, product.barcode))
        .firstOrNull;

    if (existing != null) {
      if (checked) {
        await toggleChecked(existing.id);
      } else {
        await setDesiredQty(existing.id, existing.desiredQty + quantity);
      }
      return;
    }
    await _repo.addProduct(arg, product, desiredQty: quantity, checked: checked);
  }

  /// Agrega un ítem de texto libre (sin código de barras). Si ya hay uno pendiente
  /// con el mismo nombre, suma unidades.
  Future<void> addCustomItem(String name, {int quantity = 1}) async {
    final clean = name.trim();
    if (clean.isEmpty) return;

    final existing = _items
        .where(
          (i) =>
              !i.isChecked &&
              i.barcode == null &&
              i.name.trim().toLowerCase() == clean.toLowerCase(),
        )
        .firstOrNull;

    if (existing != null) {
      await setDesiredQty(existing.id, existing.desiredQty + quantity);
      return;
    }
    await _repo.addCustomItem(arg, _capitalize(clean), desiredQty: quantity);
  }

  static String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);

  // --- Cambios sobre un ítem -------------------------------------------

  /// Toque manual: completa el ítem o, si ya estaba completo, lo reinicia.
  Future<void> toggleChecked(String itemId) async {
    final userId = _repo.currentUserId;
    await _update(itemId, (item) => item.toggled(userId: userId));
  }

  /// Suma una unidad llevada (una lectura del escáner). Devuelve el ítem ya
  /// actualizado, o `null` si no existe.
  Future<ShoppingItem?> pickOne(String itemId) {
    final userId = _repo.currentUserId;
    return _update(
      itemId,
      (item) => item.withPicked(item.pickedQty + 1, userId: userId),
    );
  }

  Future<void> setDesiredQty(String itemId, int qty) async {
    final userId = _repo.currentUserId;
    await _update(
      itemId,
      (item) => item.withDesiredQty(qty, userId: userId),
      includeDesiredQty: true,
    );
  }

  Future<void> removeItem(String itemId) async {
    final previous = _items;
    _emit(previous.where((i) => i.id != itemId).toList());
    try {
      await _repo.removeItem(itemId);
    } catch (_) {
      _emit(previous);
      rethrow;
    }
  }

  /// Aplica [change] de forma optimista y la guarda; si falla, revierte.
  Future<ShoppingItem?> _update(
    String itemId,
    ShoppingItem Function(ShoppingItem item) change, {
    bool includeDesiredQty = false,
  }) async {
    final previous = _items;
    final index = previous.indexWhere((i) => i.id == itemId);
    if (index == -1) return null;

    final updated = change(previous[index]);
    _emit([...previous]..[index] = updated);
    try {
      await _repo.saveProgress(updated, includeDesiredQty: includeDesiredQty);
      return updated;
    } catch (_) {
      _emit(previous); // revierte el cambio optimista
      rethrow;
    }
  }

  int get pendingCount => _items.where((i) => !i.isChecked).length;
  int get checkedCount => _items.where((i) => i.isChecked).length;
}

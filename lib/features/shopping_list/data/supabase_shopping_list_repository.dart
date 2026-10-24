import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../products/domain/product.dart';
import '../../family/domain/list_member.dart';
import '../domain/shopping_item.dart';
import '../domain/shopping_list.dart';
import 'shopping_list_repository.dart';

/// Implementación en la nube (modo con cuenta): listas compartidas en tiempo real.
/// La seguridad real la dan las políticas RLS de las migraciones.
class SupabaseShoppingListRepository implements ShoppingListRepository {
  SupabaseShoppingListRepository(this._client);

  final SupabaseClient _client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  String get _requireUserId {
    final id = currentUserId;
    if (id == null) throw const AppException('Tenés que iniciar sesión.');
    return id;
  }

  // --- Listas ----------------------------------------------------------

  /// Todas mis listas (activas y finalizadas), en vivo: si otro miembro finaliza
  /// o renombra una lista, llega solo.
  @override
  Stream<List<ShoppingList>> watchLists() {
    return _client
        .from('lists')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows.map(ShoppingList.fromJson).toList());
  }

  /// Listas finalizadas, la más reciente primero, con la cantidad de productos.
  @override
  Future<List<ShoppingList>> fetchHistory() {
    return _guard(() async {
      final rows = await _client
          .from('lists')
          .select('*, list_items(count)')
          .eq('status', 'completed')
          .order('completed_at', ascending: false);
      return rows.map(ShoppingList.fromJson).toList();
    });
  }

  @override
  Future<ShoppingList> createList(String name) {
    return _guard(() async {
      final row = await _client
          .from('lists')
          .insert({'name': name.trim(), 'owner_id': _requireUserId})
          .select()
          .single();
      return ShoppingList.fromJson(row);
    });
  }

  /// Une al usuario actual a la lista dueña de [code]. Devuelve el id de la lista.
  @override
  Future<String> joinByCode(String code) {
    return _guard(() async {
      final listId = await _client.rpc(
        'join_list_by_code',
        params: {'p_code': code.trim()},
      );
      return listId as String;
    });
  }

  /// Solo el dueño puede renombrar (lo impone la política RLS).
  @override
  Future<void> renameList(String listId, String name) {
    return _guard(() async {
      await _client.from('lists').update({'name': name.trim()}).eq('id', listId);
    });
  }

  /// Borra la lista y todo lo que tiene (ítems y miembros). Solo el dueño.
  @override
  Future<void> deleteList(String listId) {
    return _guard(() async {
      await _client.from('lists').delete().eq('id', listId);
    });
  }

  /// Guarda la lista en el historial (queda de solo lectura).
  @override
  Future<void> completeList(String listId) {
    return _guard(() async {
      await _client.rpc('complete_list', params: {'p_list_id': listId});
    });
  }

  /// Saca la lista del historial y la vuelve a dejar editable.
  @override
  Future<void> reopenList(String listId) {
    return _guard(() async {
      await _client.rpc('reopen_list', params: {'p_list_id': listId});
    });
  }

  /// Crea una lista nueva con los mismos productos (sin tachar). Devuelve su id.
  @override
  Future<String> duplicateList(String listId, {String? name}) {
    return _guard(() async {
      final newId = await _client.rpc(
        'duplicate_list',
        params: {'p_source_list_id': listId, 'p_name': name?.trim()},
      );
      return newId as String;
    });
  }

  // --- Miembros --------------------------------------------------------

  @override
  Future<List<ListMember>> fetchMembers(String listId) {
    return _guard(() async {
      final rows = await _client
          .from('list_members')
          .select('user_id, role, joined_at, profiles(display_name)')
          .eq('list_id', listId)
          .order('joined_at');
      return rows.map(ListMember.fromJson).toList();
    });
  }

  /// Sirve para salir de una lista (userId propio) o, siendo dueño, quitar a otro.
  /// La fila del dueño no se puede borrar (lo impide la política RLS).
  @override
  Future<void> removeMember(String listId, String userId) {
    return _guard(() async {
      await _client
          .from('list_members')
          .delete()
          .eq('list_id', listId)
          .eq('user_id', userId);
    });
  }

  // --- Ítems -----------------------------------------------------------

  /// Emite la lista completa cada vez que alguien agrega, tacha o borra un ítem.
  /// (Supabase Realtime; primero emite la carga inicial.)
  @override
  Stream<List<ShoppingItem>> watchItems(String listId) {
    return _client
        .from('list_items')
        .stream(primaryKey: ['id'])
        .eq('list_id', listId)
        .order('created_at')
        .map((rows) => rows.map(ShoppingItem.fromJson).toList());
  }

  /// Agrega un producto; con [checked] entra directamente completo (cuando se lo
  /// escanea en la góndola y ya está en el carrito).
  @override
  Future<ShoppingItem> addProduct(
    String listId,
    Product product, {
    int desiredQty = 1,
    bool checked = false,
  }) {
    return _guard(() async {
      final net = product.netQuantity;
      final userId = _requireUserId;
      final row = await _client
          .from('list_items')
          .insert({
            'list_id': listId,
            'barcode': product.barcode,
            'name': product.name,
            'brand': product.brand,
            'quantity_label': product.quantityLabel,
            'net_quantity': net?.value,
            'net_unit': net?.unit.symbol,
            'image_url': product.imageUrl,
            'desired_qty': desiredQty,
            'picked_qty': checked ? desiredQty : 0,
            'added_by': userId,
            'is_checked': checked,
            'checked_by': checked ? userId : null,
            'checked_at': checked ? DateTime.now().toUtc().toIso8601String() : null,
          })
          .select()
          .single();
      return ShoppingItem.fromJson(row);
    });
  }

  /// Agrega un ítem de texto libre, sin código de barras ("papas", "pan").
  @override
  Future<ShoppingItem> addCustomItem(
    String listId,
    String name, {
    int desiredQty = 1,
  }) {
    return _guard(() async {
      final row = await _client
          .from('list_items')
          .insert({
            'list_id': listId,
            'name': name.trim(),
            'desired_qty': desiredQty,
            'added_by': _requireUserId,
          })
          .select()
          .single();
      return ShoppingItem.fromJson(row);
    });
  }

  /// Guarda el avance de un ítem ya calculado (unidades llevadas y si está completo).
  /// Con [includeDesiredQty] también guarda la cantidad pedida.
  @override
  Future<void> saveProgress(ShoppingItem item, {bool includeDesiredQty = false}) {
    return _guard(() async {
      await _client.from('list_items').update({
        if (includeDesiredQty) 'desired_qty': item.desiredQty,
        'picked_qty': item.pickedQty,
        'is_checked': item.isChecked,
        'checked_by': item.checkedBy,
        'checked_at': item.checkedAt?.toUtc().toIso8601String(),
      }).eq('id', item.id);
    });
  }

  @override
  Future<void> removeItem(String itemId) {
    return _guard(() async {
      await _client.from('list_items').delete().eq('id', itemId);
    });
  }

  // ---------------------------------------------------------------------

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      final message = e.message;
      if (message.contains('invalid_invite_code')) {
        throw AppException('Ese código de invitación no existe.', cause: e);
      }
      if (message.contains('not_a_member')) {
        throw AppException('No sos miembro de esa lista.', cause: e);
      }
      if (e.code == '42501' || message.contains('row-level security')) {
        throw AppException(
          'No se puede modificar esta lista (¿ya está finalizada?).',
          cause: e,
        );
      }
      throw AppException('No se pudo completar la operación ($message).', cause: e);
    } on AuthException catch (e) {
      throw AppException('Problema de sesión: ${e.message}', cause: e);
    }
  }
}

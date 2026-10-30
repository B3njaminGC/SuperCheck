import '../../family/domain/list_member.dart';
import '../../products/domain/product.dart';
import '../domain/shopping_item.dart';
import '../domain/shopping_list.dart';

/// Todo lo que la app necesita para guardar y leer listas, sin importar dónde viven.
///
/// Tiene dos implementaciones:
/// - [LocalShoppingListRepository] (`local_shopping_list_repository.dart`): en el
///   teléfono, sin cuenta.
/// - [SupabaseShoppingListRepository] (`supabase_shopping_list_repository.dart`): en la
///   nube, con cuenta y sincronización en vivo.
///
/// El resto de la app solo conoce esta interfaz, así que las pantallas funcionan igual
/// en los dos modos.
abstract class ShoppingListRepository {
  /// Id de quien usa la app (en el modo local siempre es el mismo).
  String? get currentUserId;

  // --- Listas ----------------------------------------------------------

  /// Todas mis listas (activas y finalizadas), la más nueva primero. Emite el estado
  /// actual al suscribirse y de nuevo en cada cambio.
  Stream<List<ShoppingList>> watchLists();

  /// Listas finalizadas, la más reciente primero, con la cantidad de productos.
  Future<List<ShoppingList>> fetchHistory();

  Future<ShoppingList> createList(String name);

  /// Une al usuario actual a la lista dueña de [code]. Devuelve el id de la lista.
  Future<String> joinByCode(String code);

  Future<void> renameList(String listId, String name);

  /// Borra la lista y todo lo que tiene.
  Future<void> deleteList(String listId);

  /// Guarda la lista en el historial (queda de solo lectura).
  Future<void> completeList(String listId);

  /// Termina la compra sin haber conseguido todo: lo tachado pasa al historial como una
  /// lista finalizada y esta lista queda solo con lo que falta, marcada como pendiente.
  Future<void> leavePendingList(String listId);

  /// Saca la lista del historial y la vuelve a dejar editable.
  Future<void> reopenList(String listId);

  /// Crea una lista nueva con los mismos productos, sin tachar. Devuelve su id.
  Future<String> duplicateList(String listId, {String? name});

  // --- Miembros --------------------------------------------------------

  Future<List<ListMember>> fetchMembers(String listId);

  /// Sirve para salir de una lista (userId propio) o, siendo dueño, quitar a otro.
  Future<void> removeMember(String listId, String userId);

  // --- Ítems -----------------------------------------------------------

  /// Emite los ítems de la lista al suscribirse y de nuevo en cada cambio.
  Stream<List<ShoppingItem>> watchItems(String listId);

  /// Agrega un producto; con [checked] entra directamente completo (cuando se lo
  /// escanea en la góndola y ya está en el carrito).
  Future<ShoppingItem> addProduct(
    String listId,
    Product product, {
    int desiredQty = 1,
    bool checked = false,
  });

  /// Agrega un ítem de texto libre, sin código de barras ("papas", "pan").
  Future<ShoppingItem> addCustomItem(
    String listId,
    String name, {
    int desiredQty = 1,
  });

  /// Guarda el avance de un ítem ya calculado (unidades llevadas y si está completo).
  /// Con [includeDesiredQty] también guarda la cantidad pedida.
  Future<void> saveProgress(ShoppingItem item, {bool includeDesiredQty = false});

  Future<void> removeItem(String itemId);
}

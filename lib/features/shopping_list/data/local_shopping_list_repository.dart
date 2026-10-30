import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/mode/app_mode.dart';
import '../../family/domain/list_member.dart';
import '../../products/domain/product.dart';
import '../domain/shopping_item.dart';
import '../domain/shopping_list.dart';
import 'shopping_list_repository.dart';

/// Implementación del modo "sin cuenta": listas e ítems guardados en el teléfono.
///
/// Todo vive en memoria y se escribe completo en `SharedPreferences` (como un único
/// texto JSON) después de cada cambio. Para listas de compras sobra: son cientos de
/// renglones como mucho. Los cambios se aplican en memoria al instante y el guardado
/// va en cola, así que dos cambios seguidos nunca se pisan.
class LocalShoppingListRepository implements ShoppingListRepository {
  LocalShoppingListRepository(this._prefs) {
    _load();
  }

  /// Clave bajo la que se guardan los datos.
  static const storageKey = 'local_data_v1';

  static const _maxNameLength = 80;

  final SharedPreferences _prefs;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final Random _random = Random();

  List<ShoppingList> _lists = [];
  List<ShoppingItem> _items = [];

  Future<void> _saveChain = Future<void>.value();
  int _lastStamp = 0;
  int _sequence = 0;

  // --- Carga y guardado ------------------------------------------------

  void _load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final lists = (data['lists'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(ShoppingList.fromJson)
          .toList();
      final ids = lists.map((l) => l.id).toSet();
      _lists = lists;
      _items = (data['items'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(ShoppingItem.fromJson)
          .where((i) => ids.contains(i.listId))
          .toList();
    } catch (_) {
      // Datos ilegibles: se guardan aparte para no perderlos y se arranca vacío.
      _lists = [];
      _items = [];
      unawaited(
        _prefs.setString(
          '${storageKey}_ilegible_${DateTime.now().millisecondsSinceEpoch}',
          raw,
        ),
      );
    }
  }

  /// Avisa a quien esté mirando y guarda en el teléfono.
  Future<void> _commit() {
    if (!_changes.isClosed) _changes.add(null);

    final json = jsonEncode({
      'lists': [for (final l in _lists) l.toJson()],
      'items': [for (final i in _items) i.toJson()],
    });
    final result = _saveChain.then((_) async {
      final ok = await _prefs.setString(storageKey, json);
      if (!ok) {
        throw const AppException('No se pudo guardar en el teléfono.');
      }
    });
    // La cadena sigue funcionando aunque un guardado falle.
    _saveChain = result.catchError((Object _) {});
    return result;
  }

  /// Libera los recursos. Después de esto el repositorio no se debe usar.
  void dispose() {
    unawaited(_changes.close());
  }

  // --- Utilidades ------------------------------------------------------

  /// Hora actual, siempre estrictamente mayor que la anterior: así los ítems
  /// agregados en el mismo milisegundo conservan su orden.
  DateTime _now() {
    var ms = DateTime.now().millisecondsSinceEpoch;
    if (ms <= _lastStamp) ms = _lastStamp + 1;
    _lastStamp = ms;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  String _newId(String prefix) {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final noise = _random.nextInt(1 << 30).toRadixString(36);
    return '$prefix-$time-$noise-${_sequence++}';
  }

  String _cleanName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const AppException('Ponele un nombre.');
    }
    return trimmed.length > _maxNameLength
        ? trimmed.substring(0, _maxNameLength)
        : trimmed;
  }

  ShoppingList _requireList(String listId) {
    final list = _lists.where((l) => l.id == listId).firstOrNull;
    if (list == null) throw const AppException('Esa lista ya no existe.');
    return list;
  }

  /// Igual que en la nube, una lista finalizada rechaza cambios en sus productos.
  ShoppingList _requireActiveList(String listId) {
    final list = _requireList(listId);
    if (list.isCompleted) {
      throw const AppException(
        'No se puede modificar esta lista (¿ya está finalizada?).',
      );
    }
    return list;
  }

  List<ShoppingItem> _itemsOf(String listId) {
    return _items.where((i) => i.listId == listId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  void _replaceList(ShoppingList updated) {
    _lists = [
      for (final l in _lists)
        if (l.id == updated.id) updated else l,
    ];
  }

  /// Un stream que emite el estado actual al suscribirse y otra vez cada vez que
  /// cambia (sin repetir valores iguales).
  Stream<List<T>> _watch<T>(List<T> Function() snapshot) {
    late final StreamController<List<T>> controller;
    StreamSubscription<void>? subscription;
    List<T>? last;

    void emit() {
      final next = snapshot();
      if (last != null && listEquals(last, next)) return;
      last = next;
      controller.add(next);
    }

    controller = StreamController<List<T>>(
      onListen: () {
        emit();
        subscription = _changes.stream.listen((_) => emit());
      },
      onCancel: () async {
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  // --- Usuario ---------------------------------------------------------

  @override
  String? get currentUserId => localUserId;

  // --- Listas ----------------------------------------------------------

  @override
  Stream<List<ShoppingList>> watchLists() {
    return _watch(
      () => [..._lists]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  @override
  Future<List<ShoppingList>> fetchHistory() async {
    final completed = _lists.where((l) => l.isCompleted).toList()
      ..sort((a, b) {
        final byDate = (b.completedAt ?? b.createdAt)
            .compareTo(a.completedAt ?? a.createdAt);
        return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
      });
    return [
      for (final l in completed)
        l.copyWith(itemCount: _items.where((i) => i.listId == l.id).length),
    ];
  }

  @override
  Future<ShoppingList> createList(String name) async {
    final list = ShoppingList(
      id: _newId('lista'),
      name: _cleanName(name),
      ownerId: localUserId,
      inviteCode: '',
      createdAt: _now(),
    );
    _lists = [..._lists, list];
    await _commit();
    return list;
  }

  @override
  Future<String> joinByCode(String code) async {
    throw const AppException(
      'Para unirte a la lista de otra persona necesitás una cuenta.',
    );
  }

  @override
  Future<void> renameList(String listId, String name) async {
    final list = _requireList(listId);
    _replaceList(list.copyWith(name: _cleanName(name)));
    await _commit();
  }

  @override
  Future<void> deleteList(String listId) async {
    if (!_lists.any((l) => l.id == listId)) return;
    _lists = _lists.where((l) => l.id != listId).toList();
    _items = _items.where((i) => i.listId != listId).toList();
    await _commit();
  }

  @override
  Future<void> completeList(String listId) async {
    final list = _requireList(listId);
    if (list.isCompleted) return;
    _replaceList(
      list.copyWith(status: ListStatus.completed, completedAt: _now(), pending: false),
    );
    await _commit();
  }

  @override
  Future<void> leavePendingList(String listId) async {
    final list = _requireActiveList(listId);
    final items = _itemsOf(listId);
    final bought = {for (final i in items) if (i.isChecked) i.id};
    if (bought.isEmpty) {
      throw const AppException('Todavía no tachaste ningún producto.');
    }
    if (bought.length == items.length) {
      throw const AppException('Ya está todo tachado: terminá la compra con el check.');
    }

    // Lo comprado se mueve a una lista finalizada nueva (sus productos conservan todo).
    final now = _now();
    final done = ShoppingList(
      id: _newId('lista'),
      name: list.name,
      ownerId: localUserId,
      inviteCode: '',
      createdAt: now,
      status: ListStatus.completed,
      completedAt: now,
    );
    _items = [
      for (final i in _items)
        if (bought.contains(i.id))
          ShoppingItem.fromJson({...i.toJson(), 'list_id': done.id})
        else
          i,
    ];
    _lists = [..._lists, done];
    _replaceList(list.copyWith(pending: true));
    await _commit();
  }

  @override
  Future<void> reopenList(String listId) async {
    final list = _requireList(listId);
    if (!list.isCompleted) return;
    _replaceList(
      list.copyWith(status: ListStatus.active, clearCompletedAt: true),
    );
    await _commit();
  }

  @override
  Future<String> duplicateList(String listId, {String? name}) async {
    final source = _requireList(listId);
    final requested = name?.trim() ?? '';

    final copy = ShoppingList(
      id: _newId('lista'),
      name: _cleanName(requested.isEmpty ? source.name : requested),
      ownerId: localUserId,
      inviteCode: '',
      createdAt: _now(),
    );

    // Se copian los productos y cantidades pero no el avance: todo vuelve a pendiente.
    final copiedItems = [
      for (final item in _itemsOf(listId))
        ShoppingItem(
          id: _newId('item'),
          listId: copy.id,
          name: item.name,
          createdAt: _now(),
          barcode: item.barcode,
          brand: item.brand,
          quantityLabel: item.quantityLabel,
          netQuantity: item.netQuantity,
          imageUrl: item.imageUrl,
          desiredQty: item.desiredQty,
          notes: item.notes,
          addedBy: localUserId,
        ),
    ];

    _lists = [..._lists, copy];
    _items = [..._items, ...copiedItems];
    await _commit();
    return copy.id;
  }

  // --- Miembros --------------------------------------------------------

  @override
  Future<List<ListMember>> fetchMembers(String listId) async {
    final list = _lists.where((l) => l.id == listId).firstOrNull;
    if (list == null) return const [];
    return [
      ListMember(
        userId: localUserId,
        displayName: 'Yo',
        isOwner: true,
        joinedAt: list.createdAt,
      ),
    ];
  }

  @override
  Future<void> removeMember(String listId, String userId) async {
    // En el modo local no hay otros miembros.
  }

  // --- Ítems -----------------------------------------------------------

  @override
  Stream<List<ShoppingItem>> watchItems(String listId) {
    return _watch(() => _itemsOf(listId));
  }

  @override
  Future<ShoppingItem> addProduct(
    String listId,
    Product product, {
    int desiredQty = 1,
    bool checked = false,
  }) async {
    _requireActiveList(listId);
    final qty = desiredQty < 1 ? 1 : desiredQty;
    final now = _now();

    final item = ShoppingItem(
      id: _newId('item'),
      listId: listId,
      name: product.name,
      createdAt: now,
      barcode: product.hasBarcode ? product.barcode : null,
      brand: product.brand,
      quantityLabel: product.quantityLabel,
      netQuantity: product.netQuantity,
      imageUrl: product.imageUrl,
      desiredQty: qty,
      pickedQty: checked ? qty : 0,
      isChecked: checked,
      checkedBy: checked ? localUserId : null,
      checkedAt: checked ? now : null,
      addedBy: localUserId,
    );
    _items = [..._items, item];
    await _commit();
    return item;
  }

  @override
  Future<ShoppingItem> addCustomItem(
    String listId,
    String name, {
    int desiredQty = 1,
  }) async {
    _requireActiveList(listId);

    final item = ShoppingItem(
      id: _newId('item'),
      listId: listId,
      name: _cleanName(name),
      createdAt: _now(),
      desiredQty: desiredQty < 1 ? 1 : desiredQty,
      addedBy: localUserId,
    );
    _items = [..._items, item];
    await _commit();
    return item;
  }

  @override
  Future<void> saveProgress(
    ShoppingItem item, {
    bool includeDesiredQty = false,
  }) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index == -1) {
      throw const AppException('Ese producto ya no está en la lista.');
    }
    _requireActiveList(_items[index].listId);

    _items = [..._items]..[index] = item;
    await _commit();
  }

  @override
  Future<void> removeItem(String itemId) async {
    final item = _items.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return;
    _requireActiveList(item.listId);

    _items = _items.where((i) => i.id != itemId).toList();
    await _commit();
  }
}

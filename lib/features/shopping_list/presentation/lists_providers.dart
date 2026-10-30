import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../data/shopping_list_repository.dart';
import '../../family/domain/list_member.dart';
import '../domain/shopping_list.dart';
import 'shopping_list_controller.dart';

/// Todas mis listas (activas y finalizadas), en vivo.
final myListsProvider = StreamProvider.autoDispose<List<ShoppingList>>((ref) {
  return ref.watch(shoppingListRepositoryProvider).watchLists();
});

/// Solo las activas, para la pestaña "Listas".
final activeListsProvider =
    Provider.autoDispose<AsyncValue<List<ShoppingList>>>((ref) {
  return ref
      .watch(myListsProvider)
      .whenData((lists) => lists.where((l) => !l.isCompleted).toList());
});

/// Historial: listas finalizadas, la más reciente primero. Se vuelve a pedir cada
/// vez que cambia alguna lista (por ejemplo, cuando alguien finaliza una).
final historyProvider = FutureProvider.autoDispose<List<ShoppingList>>((ref) {
  ref.watch(myListsProvider);
  return ref.watch(shoppingListRepositoryProvider).fetchHistory();
});

/// Una lista por id, tomada del stream de listas (así refleja cambios en vivo).
final listByIdProvider =
    Provider.autoDispose.family<ShoppingList?, String>((ref, listId) {
  final lists = ref.watch(myListsProvider).valueOrNull ?? const <ShoppingList>[];
  return lists.where((l) => l.id == listId).firstOrNull;
});

/// Personas que participan de una lista.
final listMembersProvider = FutureProvider.autoDispose
    .family<List<ListMember>, String>((ref, listId) {
  return ref.watch(shoppingListRepositoryProvider).fetchMembers(listId);
});

final listActionsProvider = Provider<ListActions>(ListActions.new);

/// Acciones sobre listas completas (crear, unirse, finalizar, reabrir, reutilizar,
/// salir). Después de cada una refresca lo que corresponde.
class ListActions {
  ListActions(this._ref);

  final Ref _ref;

  ShoppingListRepository get _repo => _ref.read(shoppingListRepositoryProvider);

  void _refresh() {
    _ref.invalidate(myListsProvider);
  }

  Future<ShoppingList> create(String name) async {
    final list = await _repo.createList(name);
    _refresh();
    return list;
  }

  /// Devuelve el id de la lista a la que se unió.
  Future<String> join(String code) async {
    final listId = await _repo.joinByCode(code);
    _refresh();
    return listId;
  }

  Future<void> complete(String listId) async {
    await _repo.completeList(listId);
    _refresh();
  }

  /// Termina la compra dejando lo que falta como lista PENDIENTE.
  Future<void> leavePending(String listId) async {
    await _repo.leavePendingList(listId);
    _refresh();
  }

  Future<void> reopen(String listId) async {
    await _repo.reopenList(listId);
    _refresh();
  }

  /// Crea una lista nueva con los mismos productos. Devuelve el id de la nueva.
  Future<String> reuse(String listId, {String? name}) async {
    final newId = await _repo.duplicateList(listId, name: name);
    _refresh();
    return newId;
  }

  Future<void> rename(String listId, String name) async {
    await _repo.renameList(listId, name);
    _refresh();
  }

  /// Borra la lista para todos sus miembros (solo el dueño).
  Future<void> delete(String listId) async {
    await _repo.deleteList(listId);
    _refresh();
  }

  /// Sale de una lista compartida (el dueño no puede: finaliza la lista).
  Future<void> leave(String listId) async {
    final userId = _repo.currentUserId;
    if (userId == null) throw const AppException('Tenés que iniciar sesión.');
    await _repo.removeMember(listId, userId);
    _refresh();
  }

  /// Solo el dueño puede quitar a otros miembros.
  Future<void> removeMember(String listId, String userId) async {
    await _repo.removeMember(listId, userId);
    _ref.invalidate(listMembersProvider(listId));
  }
}

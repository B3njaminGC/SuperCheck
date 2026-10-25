import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/mode/app_mode.dart';
import '../../products/domain/net_quantity.dart';
import '../../products/domain/product.dart';
import '../data/imported_lists_registry.dart';
import '../domain/list_share.dart';
import '../domain/shopping_item.dart';
import '../domain/shopping_list.dart';
import 'lists_providers.dart';
import 'shopping_list_controller.dart';

/// Abre el menú de compartir del teléfono (WhatsApp, mensajes, etc.).
abstract class ListSharer {
  Future<void> share(String text, {String? subject});
}

class DeviceListSharer implements ListSharer {
  @override
  Future<void> share(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }
}

final listSharerProvider = Provider<ListSharer>((ref) => DeviceListSharer());

final listTransferProvider = Provider<ListTransfer>(ListTransfer.new);

/// Qué hacer cuando la lista que llega ya se había importado antes.
enum ImportMode { newCopy, replace }

/// Enviar una copia de una lista y recibir la de otra persona, sin cuentas ni servidor.
class ListTransfer {
  ListTransfer(this._ref);

  final Ref _ref;

  ImportedListsRegistry get _registry =>
      ImportedListsRegistry(_ref.read(sharedPreferencesProvider));

  /// Lee la lista tal como está ahora (sin avance del carrito).
  Future<SharedList> snapshot(ShoppingList list) async {
    final items =
        await _ref.read(shoppingListRepositoryProvider).watchItems(list.id).first;
    return SharedList(
      sourceId: list.id,
      name: list.name,
      items: [
        for (final it in items)
          SharedItem(
            name: it.name,
            brand: it.brand,
            quantityLabel: it.quantityLabel,
            barcode: it.barcode,
            imageUrl: _isWeb(it) ? it.imageUrl : null,
            desiredQty: it.desiredQty,
          ),
      ],
    );
  }

  static bool _isWeb(ShoppingItem it) => (it.imageUrl ?? '').startsWith('http');

  /// Abre el menú de compartir con el mensaje de [list].
  Future<void> send(ShoppingList list) async {
    final shared = await snapshot(list);
    if (shared.items.isEmpty) {
      throw const AppException('La lista está vacía: agregá productos antes de enviarla.');
    }
    await _ref
        .read(listSharerProvider)
        .share(ListShareCodec.toMessage(shared), subject: list.name);
  }

  /// La lista activa que ya viene de esta misma copia, si existe.
  Future<ShoppingList?> existingFor(SharedList shared) async {
    final sourceId = shared.sourceId;
    if (sourceId == null) return null;
    final lists = await _ref.read(shoppingListRepositoryProvider).watchLists().first;
    final localId = _registry.localIdFor(sourceId) ?? sourceId;
    return lists.where((l) => l.id == localId && !l.isCompleted).firstOrNull;
  }

  /// Crea la lista (o reemplaza los productos de [replacing]) y devuelve su id.
  Future<String> import(SharedList shared, {ShoppingList? replacing}) async {
    final repo = _ref.read(shoppingListRepositoryProvider);

    final String listId;
    if (replacing != null) {
      listId = replacing.id;
      final current = await repo.watchItems(listId).first;
      for (final item in current) {
        await repo.removeItem(item.id);
      }
    } else {
      listId = (await repo.createList(shared.name)).id;
    }

    for (final item in shared.items) {
      await repo.addProduct(
        listId,
        Product(
          barcode: item.barcode ?? '',
          name: item.name,
          brand: item.brand,
          quantityLabel: item.quantityLabel,
          netQuantity: NetQuantity.tryParse(item.quantityLabel),
          imageUrl: item.imageUrl,
        ),
        desiredQty: item.desiredQty,
      );
    }

    final sourceId = shared.sourceId;
    if (sourceId != null && replacing == null) {
      await _registry.remember(sourceId, listId);
    }
    _ref.invalidate(myListsProvider);
    return listId;
  }
}

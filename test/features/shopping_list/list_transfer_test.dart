import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supercheck/core/errors/app_exception.dart';
import 'package:supercheck/core/mode/app_mode.dart';
import 'package:supercheck/features/products/domain/product.dart';
import 'package:supercheck/features/shopping_list/domain/list_share.dart';
import 'package:supercheck/features/shopping_list/presentation/list_transfer.dart';
import 'package:supercheck/features/shopping_list/presentation/shopping_list_controller.dart';

import '../../helpers/app_harness.dart' show FakeListSharer;

/// Dos teléfonos: cada uno tiene su propio almacenamiento.
Future<ProviderContainer> _phone(FakeListSharer sharer) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    listSharerProvider.overrideWithValue(sharer),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('enviar y recibir: la copia llega con productos, marca, tamaño y cantidades',
      () async {
    final sharer = FakeListSharer();
    final sender = await _phone(sharer);
    final repo = sender.read(shoppingListRepositoryProvider);
    final list = await repo.createList('Compras del mes');
    await repo.addProduct(
      list.id,
      const Product(
        barcode: '7782900990620',
        name: 'Azúcar impalpable',
        brand: 'Dos Anclas',
        quantityLabel: '300 g',
      ),
      desiredQty: 2,
    );
    await repo.addCustomItem(list.id, 'Pan');

    await sender.read(listTransferProvider).send(list);
    expect(sharer.sent, hasLength(1));

    final receiver = await _phone(FakeListSharer());
    final shared = ListShareCodec.decode(sharer.sent.single)!;
    final newId = await receiver.read(listTransferProvider).import(shared);

    final rrepo = receiver.read(shoppingListRepositoryProvider);
    final lists = await rrepo.watchLists().first;
    expect(lists.single.name, 'Compras del mes');
    final items = await rrepo.watchItems(newId).first;
    expect(items.map((i) => i.name), ['Azúcar impalpable', 'Pan']);
    expect(items[0].brand, 'Dos Anclas');
    expect(items[0].barcode, '7782900990620');
    expect(items[0].netQuantity, isNotNull);
    expect(items[0].desiredQty, 2);
    expect(items.every((i) => !i.isChecked && i.pickedQty == 0), isTrue);
  });

  test('el avance del carrito no viaja en la copia', () async {
    final sharer = FakeListSharer();
    final c = await _phone(sharer);
    final repo = c.read(shoppingListRepositoryProvider);
    final list = await repo.createList('Súper');
    await repo.addProduct(
      list.id,
      const Product(barcode: '', name: 'Pan'),
      checked: true,
    );

    await c.read(listTransferProvider).send(list);

    final other = await _phone(FakeListSharer());
    final id = await other
        .read(listTransferProvider)
        .import(ListShareCodec.decode(sharer.sent.single)!);
    final items = await other.read(shoppingListRepositoryProvider).watchItems(id).first;
    expect(items.single.isChecked, isFalse);
  });

  test('una lista vacía no se envía', () async {
    final sharer = FakeListSharer();
    final c = await _phone(sharer);
    final list = await c.read(shoppingListRepositoryProvider).createList('Vacía');

    await expectLater(
      c.read(listTransferProvider).send(list),
      throwsA(isA<AppException>()),
    );
    expect(sharer.sent, isEmpty);
  });

  test('al recibir de nuevo la misma lista, se reconoce y se puede reemplazar', () async {
    final sharer = FakeListSharer();
    final sender = await _phone(sharer);
    final srepo = sender.read(shoppingListRepositoryProvider);
    final list = await srepo.createList('Compras');
    await srepo.addCustomItem(list.id, 'Pan');
    await sender.read(listTransferProvider).send(list);

    final receiver = await _phone(FakeListSharer());
    final transfer = receiver.read(listTransferProvider);
    final first = ListShareCodec.decode(sharer.sent.last)!;

    expect(await transfer.existingFor(first), isNull);
    final localId = await transfer.import(first);

    // La otra persona agrega un producto y vuelve a enviar.
    await srepo.addCustomItem(list.id, 'Leche');
    await sender.read(listTransferProvider).send(list);
    final second = ListShareCodec.decode(sharer.sent.last)!;

    final existing = await transfer.existingFor(second);
    expect(existing?.id, localId);

    final rrepo = receiver.read(shoppingListRepositoryProvider);
    final sameId = await transfer.import(second, replacing: existing);
    expect(sameId, localId);
    expect((await rrepo.watchLists().first), hasLength(1));
    expect(
      (await rrepo.watchItems(localId).first).map((i) => i.name),
      ['Pan', 'Leche'],
    );
  });

  test('importar otra vez como copia deja dos listas', () async {
    final sharer = FakeListSharer();
    final c = await _phone(sharer);
    final repo = c.read(shoppingListRepositoryProvider);
    final list = await repo.createList('Compras');
    await repo.addCustomItem(list.id, 'Pan');
    await c.read(listTransferProvider).send(list);

    final transfer = c.read(listTransferProvider);
    final shared = ListShareCodec.decode(sharer.sent.single)!;
    // En el mismo teléfono la lista original cuenta como "ya la tengo".
    expect((await transfer.existingFor(shared))?.id, list.id);

    await transfer.import(shared);
    expect(await repo.watchLists().first, hasLength(2));
  });

  test('una lista finalizada no cuenta como "ya la tengo"', () async {
    final sharer = FakeListSharer();
    final c = await _phone(sharer);
    final repo = c.read(shoppingListRepositoryProvider);
    final list = await repo.createList('Compras');
    await repo.addCustomItem(list.id, 'Pan');
    await c.read(listTransferProvider).send(list);
    await repo.completeList(list.id);

    final shared = ListShareCodec.decode(sharer.sent.single)!;
    expect(await c.read(listTransferProvider).existingFor(shared), isNull);
  });
}

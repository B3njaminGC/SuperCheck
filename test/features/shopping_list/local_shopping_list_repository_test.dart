import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supercheck/core/errors/app_exception.dart';
import 'package:supercheck/core/mode/app_mode.dart';
import 'package:supercheck/features/products/domain/net_quantity.dart';
import 'package:supercheck/features/products/domain/product.dart';
import 'package:supercheck/features/shopping_list/data/local_shopping_list_repository.dart';

const criollitas = Product(
  barcode: '7790001000001',
  name: 'Galletitas de agua',
  brand: 'Criollitas',
  quantityLabel: '300 g',
  netQuantity: NetQuantity(300, QuantityUnit.gram),
  imageUrl: 'https://img.example/criollitas.jpg',
);

void main() {
  late SharedPreferences prefs;
  late LocalShoppingListRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = LocalShoppingListRepository(prefs);
  });

  tearDown(() => repo.dispose());

  group('listas', () {
    test('arranca sin listas', () async {
      expect(await repo.watchLists().first, isEmpty);
      expect(await repo.fetchHistory(), isEmpty);
    });

    test('crea listas y devuelve la más nueva primero', () async {
      await repo.createList('Compras del mes');
      await repo.createList('  Verdulería ');

      final lists = await repo.watchLists().first;
      expect(lists.map((l) => l.name), ['Verdulería', 'Compras del mes']);
      expect(lists.every((l) => l.ownerId == localUserId), isTrue);
      expect(lists.every((l) => !l.isCompleted), isTrue);
    });

    test('rechaza nombres vacíos', () async {
      await expectLater(repo.createList('   '), throwsA(isA<AppException>()));
      expect(await repo.watchLists().first, isEmpty);
    });

    test('renombra', () async {
      final list = await repo.createList('Super');
      await repo.renameList(list.id, 'Súper del sábado');
      expect((await repo.watchLists().first).single.name, 'Súper del sábado');
    });

    test('unirse con un código pide tener cuenta', () async {
      await expectLater(repo.joinByCode('ABCD2345'), throwsA(isA<AppException>()));
    });

    test('el único miembro es el dueño', () async {
      final list = await repo.createList('Super');
      final members = await repo.fetchMembers(list.id);
      expect(members, hasLength(1));
      expect(members.single.isOwner, isTrue);
      expect(members.single.userId, localUserId);
      expect(await repo.fetchMembers('no-existe'), isEmpty);
    });
  });

  group('productos', () {
    test('agrega un producto con todos sus datos y un ítem de texto libre', () async {
      final list = await repo.createList('Super');
      await repo.addProduct(list.id, criollitas, desiredQty: 2);
      await repo.addCustomItem(list.id, 'Pan');

      final items = await repo.watchItems(list.id).first;
      expect(items.map((i) => i.name), ['Galletitas de agua', 'Pan']);

      final galletitas = items.first;
      expect(galletitas.barcode, '7790001000001');
      expect(galletitas.brand, 'Criollitas');
      expect(galletitas.netQuantity, const NetQuantity(300, QuantityUnit.gram));
      expect(galletitas.imageUrl, 'https://img.example/criollitas.jpg');
      expect(galletitas.desiredQty, 2);
      expect(galletitas.isChecked, isFalse);

      expect(items.last.barcode, isNull);
      expect(items.last.desiredQty, 1);
    });

    test('un producto agregado ya tachado entra completo', () async {
      final list = await repo.createList('Super');
      final item = await repo.addProduct(
        list.id,
        criollitas,
        desiredQty: 3,
        checked: true,
      );
      expect(item.isChecked, isTrue);
      expect(item.pickedQty, 3);
      expect(item.checkedBy, localUserId);
    });

    test('cuenta unidades y se tacha al completar', () async {
      final list = await repo.createList('Super');
      final added = await repo.addProduct(list.id, criollitas, desiredQty: 3);

      await repo.saveProgress(added.withPicked(1, userId: localUserId));
      var item = (await repo.watchItems(list.id).first).single;
      expect(item.pickedQty, 1);
      expect(item.isChecked, isFalse);
      expect(item.progressLabel, '1 de 3');

      await repo.saveProgress(item.withPicked(3, userId: localUserId));
      item = (await repo.watchItems(list.id).first).single;
      expect(item.isChecked, isTrue);
      expect(item.checkedBy, localUserId);
      expect(item.checkedAt, isNotNull);
    });

    test('quita un ítem', () async {
      final list = await repo.createList('Super');
      final pan = await repo.addCustomItem(list.id, 'Pan');
      await repo.addCustomItem(list.id, 'Leche');

      await repo.removeItem(pan.id);
      expect((await repo.watchItems(list.id).first).map((i) => i.name), ['Leche']);

      // Quitar algo que ya no está no es un error.
      await repo.removeItem(pan.id);
    });

    test('los productos de una lista no aparecen en otra', () async {
      final a = await repo.createList('A');
      final b = await repo.createList('B');
      await repo.addCustomItem(a.id, 'Pan');

      expect(await repo.watchItems(a.id).first, hasLength(1));
      expect(await repo.watchItems(b.id).first, isEmpty);
    });

    test('no agrega a una lista que no existe', () async {
      await expectLater(
        repo.addCustomItem('no-existe', 'Pan'),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('historial', () {
    test('finalizar guarda la lista en el historial con su cantidad de productos',
        () async {
      final list = await repo.createList('Compras del mes');
      await repo.addCustomItem(list.id, 'Pan');
      await repo.addProduct(list.id, criollitas);

      await repo.completeList(list.id);

      final history = await repo.fetchHistory();
      expect(history, hasLength(1));
      expect(history.single.name, 'Compras del mes');
      expect(history.single.isCompleted, isTrue);
      expect(history.single.completedAt, isNotNull);
      expect(history.single.itemCount, 2);
    });

    test('el historial muestra primero lo último que se finalizó', () async {
      final a = await repo.createList('A');
      final b = await repo.createList('B');
      await repo.completeList(a.id);
      await repo.completeList(b.id);

      expect((await repo.fetchHistory()).map((l) => l.name), ['B', 'A']);
    });

    test('una lista finalizada no se puede modificar hasta reabrirla', () async {
      final list = await repo.createList('Super');
      final pan = await repo.addCustomItem(list.id, 'Pan');
      await repo.completeList(list.id);

      await expectLater(
        repo.addCustomItem(list.id, 'Leche'),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repo.saveProgress(pan.toggled(userId: localUserId)),
        throwsA(isA<AppException>()),
      );
      await expectLater(repo.removeItem(pan.id), throwsA(isA<AppException>()));

      await repo.reopenList(list.id);
      expect(await repo.fetchHistory(), isEmpty);
      await repo.addCustomItem(list.id, 'Leche');
      expect(await repo.watchItems(list.id).first, hasLength(2));
    });

    test('reutilizar copia productos y cantidades pero no el avance', () async {
      final list = await repo.createList('Compras del mes');
      final galletitas = await repo.addProduct(list.id, criollitas, desiredQty: 3);
      final pan = await repo.addCustomItem(list.id, 'Pan');
      await repo.saveProgress(galletitas.withPicked(3, userId: localUserId));
      await repo.saveProgress(pan.toggled(userId: localUserId));
      await repo.completeList(list.id);

      final copyId = await repo.duplicateList(list.id, name: 'Compras de noviembre');

      expect(copyId, isNot(list.id));
      final lists = await repo.watchLists().first;
      final copy = lists.firstWhere((l) => l.id == copyId);
      expect(copy.name, 'Compras de noviembre');
      expect(copy.isCompleted, isFalse);

      final copied = await repo.watchItems(copyId).first;
      expect(copied.map((i) => i.name), ['Galletitas de agua', 'Pan']);
      expect(copied.map((i) => i.desiredQty), [3, 1]);
      expect(copied.every((i) => i.pickedQty == 0 && !i.isChecked), isTrue);
      expect(copied.first.brand, 'Criollitas');
      expect(copied.first.netQuantity, const NetQuantity(300, QuantityUnit.gram));
      expect(copied.every((i) => i.listId == copyId), isTrue);

      // La original queda como estaba.
      final original = await repo.watchItems(list.id).first;
      expect(original.every((i) => i.isChecked), isTrue);
      expect(original.map((i) => i.id).toSet().intersection(
            copied.map((i) => i.id).toSet(),
          ), isEmpty);
    });

    test('reutilizar sin nombre usa el de la lista original', () async {
      final list = await repo.createList('Compras del mes');
      final copyId = await repo.duplicateList(list.id);
      final lists = await repo.watchLists().first;
      expect(lists.firstWhere((l) => l.id == copyId).name, 'Compras del mes');
    });
  });

  group('borrar', () {
    test('borrar una lista elimina también sus productos', () async {
      final keep = await repo.createList('Quedarse');
      final remove = await repo.createList('Borrar');
      await repo.addCustomItem(keep.id, 'Pan');
      await repo.addCustomItem(remove.id, 'Leche');

      await repo.deleteList(remove.id);

      expect((await repo.watchLists().first).map((l) => l.id), [keep.id]);
      expect(await repo.watchItems(remove.id).first, isEmpty);
      expect(await repo.watchItems(keep.id).first, hasLength(1));
    });

    test('se puede borrar una lista del historial', () async {
      final list = await repo.createList('Vieja');
      await repo.completeList(list.id);
      await repo.deleteList(list.id);

      expect(await repo.fetchHistory(), isEmpty);
      expect(await repo.watchLists().first, isEmpty);
    });

    test('borrar una lista que ya no existe no falla', () async {
      await repo.deleteList('no-existe');
    });
  });

  group('persistencia', () {
    test('todo sobrevive al cerrar y volver a abrir la app', () async {
      final list = await repo.createList('Compras del mes');
      await repo.addProduct(list.id, criollitas, desiredQty: 2);
      final pan = await repo.addCustomItem(list.id, 'Pan');
      await repo.saveProgress(pan.toggled(userId: localUserId));
      final done = await repo.createList('Terminada');
      await repo.completeList(done.id);
      // Se espera a que termine el guardado (en la app, el guardado va en cola).
      await repo.createList('Última');

      final reopened = LocalShoppingListRepository(prefs);
      addTearDown(reopened.dispose);

      final lists = await reopened.watchLists().first;
      expect(lists.map((l) => l.name), ['Última', 'Terminada', 'Compras del mes']);
      expect(lists.firstWhere((l) => l.id == done.id).isCompleted, isTrue);

      final items = await reopened.watchItems(list.id).first;
      expect(items.map((i) => i.name), ['Galletitas de agua', 'Pan']);
      expect(items.first.desiredQty, 2);
      expect(items.first.netQuantity, const NetQuantity(300, QuantityUnit.gram));
      expect(items.last.isChecked, isTrue);
      expect(items.last.pickedQty, 1);
      expect(items.last.checkedBy, localUserId);

      expect((await reopened.fetchHistory()).single.name, 'Terminada');
    });

    test('dos cambios seguidos sin esperar no se pisan', () async {
      final list = await repo.createList('Super');
      await Future.wait([
        repo.addCustomItem(list.id, 'Pan'),
        repo.addCustomItem(list.id, 'Leche'),
        repo.addCustomItem(list.id, 'Huevos'),
      ]);

      final reopened = LocalShoppingListRepository(prefs);
      addTearDown(reopened.dispose);
      final names = (await reopened.watchItems(list.id).first).map((i) => i.name);
      expect(names, ['Pan', 'Leche', 'Huevos']);
    });

    test('datos ilegibles se guardan aparte y la app arranca vacía', () async {
      SharedPreferences.setMockInitialValues({
        LocalShoppingListRepository.storageKey: '{esto no es json',
      });
      final broken = await SharedPreferences.getInstance();
      final fresh = LocalShoppingListRepository(broken);
      addTearDown(fresh.dispose);
      await pumpEventQueue();

      expect(await fresh.watchLists().first, isEmpty);
      expect(
        broken.getKeys().any(
              (k) => k.startsWith('${LocalShoppingListRepository.storageKey}_ilegible_'),
            ),
        isTrue,
      );
    });
  });

  group('cambios en vivo', () {
    test('quien mira las listas recibe cada cambio', () async {
      final counts = <int>[];
      final subscription = repo.watchLists().listen((l) => counts.add(l.length));
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await repo.createList('A');
      await pumpEventQueue();
      await repo.createList('B');
      await pumpEventQueue();

      expect(counts, [0, 1, 2]);
    });

    test('quien mira los productos recibe cada cambio y no repeticiones', () async {
      final list = await repo.createList('Super');
      final snapshots = <List<String>>[];
      final subscription = repo
          .watchItems(list.id)
          .listen((items) => snapshots.add([for (final i in items) i.name]));
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await repo.addCustomItem(list.id, 'Pan');
      await pumpEventQueue();
      // Un cambio en otra lista no vuelve a emitir esta.
      final other = await repo.createList('Otra');
      await repo.addCustomItem(other.id, 'Leche');
      await pumpEventQueue();

      expect(snapshots, [
        <String>[],
        ['Pan'],
      ]);
    });
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supercheck/core/errors/app_exception.dart';
import 'package:supercheck/core/mode/app_mode.dart';
import 'package:supercheck/features/products/domain/net_quantity.dart';
import 'package:supercheck/features/products/presentation/my_products_controller.dart';

Future<ProviderContainer> containerWith(SharedPreferences prefs) async {
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('crea un producto con marca, tamaño, código y foto', () async {
    final container = await containerWith(prefs);
    final notifier = container.read(myProductsProvider.notifier);

    final product = await notifier.save(
      name: '  Azúcar impalpable ',
      brand: 'Dos Anclas',
      quantityLabel: '300 g',
      barcode: '7782900990620',
      imagePath: '/data/fotos/1.jpg',
    );

    expect(product.isMine, isTrue);
    expect(product.name, 'Azúcar impalpable');
    expect(product.brand, 'Dos Anclas');
    expect(product.netQuantity, const NetQuantity(300, QuantityUnit.gram));
    expect(product.barcode, '7782900990620');
    expect(product.imageUrl, '/data/fotos/1.jpg');
    expect(container.read(myProductsProvider), [product]);
  });

  test('un producto sin código ni foto es válido', () async {
    final container = await containerWith(prefs);
    final product = await container
        .read(myProductsProvider.notifier)
        .save(name: 'Pan casero', brand: '  ', quantityLabel: '', barcode: '');

    expect(product.hasBarcode, isFalse);
    expect(product.brand, isNull);
    expect(product.quantityLabel, isNull);
    expect(product.imageUrl, isNull);
  });

  test('rechaza nombre vacío y códigos demasiado cortos', () async {
    final container = await containerWith(prefs);
    final notifier = container.read(myProductsProvider.notifier);

    await expectLater(notifier.save(name: '   '), throwsA(isA<AppException>()));
    await expectLater(
      notifier.save(name: 'Algo', barcode: '1234'),
      throwsA(isA<AppException>()),
    );
    expect(container.read(myProductsProvider), isEmpty);
  });

  test('no permite dos productos con el mismo código, pero sí editar el propio',
      () async {
    final container = await containerWith(prefs);
    final notifier = container.read(myProductsProvider.notifier);

    final first = await notifier.save(name: 'Uno', barcode: '7790001000011');
    await expectLater(
      notifier.save(name: 'Dos', barcode: '7790001000011'),
      throwsA(
        isA<AppException>().having((e) => e.message, 'message', contains('"Uno"')),
      ),
    );

    // Editar el mismo producto con su propio código no es un choque.
    final edited = await notifier.save(
      id: first.libraryId,
      name: 'Uno editado',
      barcode: '7790001000011',
    );
    expect(edited.libraryId, first.libraryId);
    expect(container.read(myProductsProvider), hasLength(1));
    expect(container.read(myProductsProvider).single.name, 'Uno editado');
  });

  test('se guardan en el teléfono y siguen ahí al reabrir la app', () async {
    final first = await containerWith(prefs);
    await first.read(myProductsProvider.notifier).save(
          name: 'Azúcar impalpable',
          brand: 'Dos Anclas',
          quantityLabel: '300 g',
          barcode: '7782900990620',
          imagePath: '/data/fotos/1.jpg',
        );

    final second = await containerWith(prefs);
    final loaded = second.read(myProductsProvider);

    expect(loaded, hasLength(1));
    expect(loaded.single.brand, 'Dos Anclas');
    expect(loaded.single.netQuantity, const NetQuantity(300, QuantityUnit.gram));
    expect(loaded.single.barcode, '7782900990620');
    expect(loaded.single.imageUrl, '/data/fotos/1.jpg');
  });

  test('borrar saca el producto y queda guardado', () async {
    final container = await containerWith(prefs);
    final notifier = container.read(myProductsProvider.notifier);
    final a = await notifier.save(name: 'A');
    await notifier.save(name: 'B');

    await notifier.remove(a.libraryId!);

    expect(container.read(myProductsProvider).map((p) => p.name), ['B']);
    final reopened = await containerWith(prefs);
    expect(reopened.read(myProductsProvider).map((p) => p.name), ['B']);
  });

  test('la búsqueda ignora mayúsculas y tildes y mira nombre, marca y tamaño', () async {
    final container = await containerWith(prefs);
    final notifier = container.read(myProductsProvider.notifier);
    await notifier.save(name: 'Azúcar impalpable', brand: 'Dos Anclas', quantityLabel: '300 g');
    await notifier.save(name: 'Leche entera', brand: 'La Serenísima');

    expect(notifier.search('AZUCAR impalpable').map((p) => p.name), ['Azúcar impalpable']);
    expect(notifier.search('dos anclas').map((p) => p.name), ['Azúcar impalpable']);
    expect(notifier.search('serenisima leche'), hasLength(1));
    expect(notifier.search('300 g'), hasLength(1));
    expect(notifier.search('arroz'), isEmpty);
    expect(notifier.search('   '), isEmpty);
  });

  test('findByBarcode reconoce UPC-A y EAN-13 con cero adelante como el mismo', () async {
    final container = await containerWith(prefs);
    final notifier = container.read(myProductsProvider.notifier);
    await notifier.save(name: 'Galletitas', barcode: '012345678905');

    expect(notifier.findByBarcode('0012345678905')?.name, 'Galletitas');
    expect(notifier.findByBarcode('999999999999'), isNull);
  });
}

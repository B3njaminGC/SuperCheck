import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supercheck/core/mode/app_mode.dart';
import 'package:supercheck/features/products/domain/product.dart';
import 'package:supercheck/features/products/domain/product_text.dart';
import 'package:supercheck/features/products/presentation/favorites_controller.dart';
import 'package:supercheck/features/products/presentation/my_products_controller.dart';

const _sancor = Product(
  barcode: '7790070000011',
  name: 'Leche descremada',
  brand: 'Sancor',
  quantityLabel: '1 l',
);

Future<ProviderContainer> _container(SharedPreferences prefs) async {
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

  group('favoritos', () {
    test('marcar y desmarcar un producto', () async {
      final c = await _container(prefs);
      final favorites = c.read(favoritesProvider.notifier);

      expect(c.read(favoriteProductsProvider), isEmpty);
      await favorites.toggle(_sancor);
      expect(c.read(favoriteProductsProvider).single.name, 'Leche descremada');
      expect(c.read(favoriteKeysProvider), contains(_sancor.favoriteKey));

      await favorites.toggle(_sancor);
      expect(c.read(favoriteProductsProvider), isEmpty);
    });

    test('se guardan en el teléfono y vuelven al reabrir', () async {
      final first = await _container(prefs);
      await first.read(favoritesProvider.notifier).toggle(_sancor);

      final second = await _container(prefs);
      final loaded = second.read(favoriteProductsProvider).single;
      expect(loaded.name, 'Leche descremada');
      expect(loaded.brand, 'Sancor');
      expect(loaded.netQuantity, isNotNull);
    });

    test('UPC-A y EAN-13 con cero adelante son el mismo favorito', () async {
      final c = await _container(prefs);
      final favorites = c.read(favoritesProvider.notifier);
      const a = Product(barcode: '012345678905', name: 'Galletitas');
      const b = Product(barcode: '0012345678905', name: 'Galletitas');

      await favorites.toggle(a);
      expect(favorites.isFavorite(b), isTrue);
      await favorites.toggle(b);
      expect(c.read(favoriteProductsProvider), isEmpty);
    });

    test('un producto sin código y que no es propio no se puede marcar', () async {
      final c = await _container(prefs);
      await c.read(favoritesProvider.notifier).toggle(const Product(barcode: '', name: 'Pan'));
      expect(c.read(favoriteProductsProvider), isEmpty);
    });

    test('las marcas de los favoritos se guardan en minúsculas', () async {
      final c = await _container(prefs);
      await c.read(favoritesProvider.notifier).toggle(_sancor);
      expect(c.read(favoriteBrandsProvider), {'sancor'});
    });

    test('un favorito propio refleja las ediciones y desaparece si se borra', () async {
      final c = await _container(prefs);
      final mine = c.read(myProductsProvider.notifier);
      final created = await mine.save(name: 'Pan casero', brand: 'Lo de Ana');

      await c.read(favoritesProvider.notifier).toggle(created);
      expect(c.read(favoriteProductsProvider).single.name, 'Pan casero');

      await mine.save(id: created.libraryId, name: 'Pan lactal', brand: 'Lo de Ana');
      expect(c.read(favoriteProductsProvider).single.name, 'Pan lactal');

      await mine.remove(created.libraryId!);
      expect(c.read(favoriteProductsProvider), isEmpty);
    });

    test('quedan ordenados por nombre', () async {
      final c = await _container(prefs);
      final favorites = c.read(favoritesProvider.notifier);
      await favorites.toggle(const Product(barcode: '2222222222222', name: 'Yerba'));
      await favorites.toggle(const Product(barcode: '1111111111111', name: 'Arroz'));
      expect(c.read(favoriteProductsProvider).map((p) => p.name), ['Arroz', 'Yerba']);
    });
  });

  group('ProductText.matches', () {
    test('ignora tildes, mayúsculas y orden de las palabras', () {
      expect(ProductText.matches('AZUCAR dos', const Product(
        barcode: '1',
        name: 'Azúcar impalpable',
        brand: 'Dos Anclas',
      )), isTrue);
    });

    test('exige todas las palabras y no coincide con texto vacío', () {
      const p = Product(barcode: '1', name: 'Leche entera', brand: 'Sancor');
      expect(ProductText.matches('leche sancor', p), isTrue);
      expect(ProductText.matches('leche serenisima', p), isFalse);
      expect(ProductText.matches('   ', p), isFalse);
    });
  });
}

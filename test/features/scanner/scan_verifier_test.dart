import 'package:flutter_test/flutter_test.dart';
import 'package:supercheck/features/products/domain/net_quantity.dart';
import 'package:supercheck/features/products/domain/product.dart';
import 'package:supercheck/features/scanner/domain/scan_result.dart';
import 'package:supercheck/features/scanner/domain/scan_verifier.dart';
import 'package:supercheck/features/scanner/domain/size_advice.dart';
import 'package:supercheck/features/shopping_list/domain/shopping_item.dart';

const g = QuantityUnit.gram;

/// Ítem de la lista: por defecto, Criollitas "Galletitas de agua" de 500 g.
ShoppingItem item({
  String id = 'i1',
  String? barcode = '7790001000001',
  String name = 'Galletitas de agua',
  String? brand = 'Criollitas',
  NetQuantity? net = const NetQuantity(500, g),
  int qty = 1,
  bool checked = false,
}) {
  return ShoppingItem(
    id: id,
    listId: 'l1',
    name: name,
    createdAt: DateTime(2026, 1, 1),
    barcode: barcode,
    brand: brand,
    netQuantity: net,
    desiredQty: qty,
    isChecked: checked,
  );
}

/// Producto escaneado: por defecto, el mismo producto en paquete de 250 g.
Product product({
  String barcode = '7790001000002',
  String name = 'Galletitas de agua',
  String? brand = 'Criollitas',
  NetQuantity? net = const NetQuantity(250, g),
}) {
  return Product(barcode: barcode, name: name, brand: brand, netQuantity: net);
}

void main() {
  group('coincidencia exacta', () {
    test('mismo código de barras -> ScanExactMatch', () {
      final target = item();
      final result = ScanVerifier.verify(
        barcode: '7790001000001',
        items: [target],
      );

      expect(result, isA<ScanExactMatch>());
      final match = result as ScanExactMatch;
      expect(match.item, target);
      expect(match.alreadyChecked, isFalse);
    });

    test('UPC-A y EAN-13 con cero adelante cuentan como el mismo código', () {
      final result = ScanVerifier.verify(
        barcode: '0012345678905',
        items: [item(barcode: '012345678905')],
      );
      expect(result, isA<ScanExactMatch>());
    });

    test('si ya estaba tachado, lo avisa', () {
      final result = ScanVerifier.verify(
        barcode: '7790001000001',
        items: [item(checked: true)],
      ) as ScanExactMatch;
      expect(result.alreadyChecked, isTrue);
    });

    test('con varios ítems del mismo código, prefiere el pendiente', () {
      final result = ScanVerifier.verify(
        barcode: '7790001000001',
        items: [item(id: 'done', checked: true), item(id: 'todo')],
      ) as ScanExactMatch;
      expect(result.item.id, 'todo');
      expect(result.alreadyChecked, isFalse);
    });
  });

  group('mismo producto, otro gramaje', () {
    test('buscaba 500 g y escanea 250 g -> sugiere 2 unidades', () {
      final result = ScanVerifier.verify(
        barcode: '7790001000002',
        items: [item()],
        scannedProduct: product(),
      );

      expect(result, isA<ScanSizeDifference>());
      final diff = result as ScanSizeDifference;
      expect(diff.advice.relation, SizeRelation.smaller);
      expect(diff.advice.unitsNeeded, 2);
      expect(diff.advice.exactFit, isTrue);
      expect(diff.advice.message, contains('250 g'));
      expect(diff.advice.message, contains('2 unidades'));
      expect(diff.advice.message, contains('500 g en total'));
    });

    test('tiene en cuenta la cantidad: 2 x 500 g con paquetes de 250 g -> 4', () {
      final diff = ScanVerifier.verify(
        barcode: '7790001000002',
        items: [item(qty: 2)],
        scannedProduct: product(),
      ) as ScanSizeDifference;

      expect(diff.advice.unitsNeeded, 4);
      expect(diff.advice.message, contains('4 unidades'));
      expect(diff.advice.message, contains('1 kg en total'));
    });

    test('descuenta lo que ya está en el carrito: faltan 2 de 4 -> 4 paquetes de 250 g', () {
      final diff = ScanVerifier.verify(
        barcode: '7790001000002',
        items: [item(qty: 4).withPicked(2)],
        scannedProduct: product(),
      ) as ScanSizeDifference;

      // Faltan 2 × 500 g = 1 kg, no los 2 kg del total pedido.
      expect(diff.advice.unitsNeeded, 4);
      expect(diff.advice.message, contains('1 kg en total'));
    });

    test('paquete más grande que lo buscado', () {
      final diff = ScanVerifier.verify(
        barcode: '7790001000002',
        items: [item()],
        scannedProduct: product(net: const NetQuantity(1000, g)),
      ) as ScanSizeDifference;

      expect(diff.advice.relation, SizeRelation.larger);
      expect(diff.advice.unitsNeeded, 1);
      expect(diff.advice.message, contains('más grande'));
      expect(diff.advice.message, contains('1 kg'));
    });

    test('si no da justo, redondea para arriba y lo aclara', () {
      final diff = ScanVerifier.verify(
        barcode: '7790001000002',
        items: [item(net: const NetQuantity(1000, g))],
        scannedProduct: product(net: const NetQuantity(400, g)),
      ) as ScanSizeDifference;

      expect(diff.advice.unitsNeeded, 3);
      expect(diff.advice.exactFit, isFalse);
      expect(diff.advice.message, contains('3 unidades'));
      expect(diff.advice.message, contains('1,2 kg'));
    });

    test('mismo contenido y distinto código: puede ser otra variedad', () {
      final diff = ScanVerifier.verify(
        barcode: '7790001000002',
        items: [item()],
        scannedProduct: product(net: const NetQuantity(500, g)),
      ) as ScanSizeDifference;

      expect(diff.advice.relation, SizeRelation.same);
      expect(diff.advice.message, contains('otro código de barras'));
    });

    test('sin gramos en el producto escaneado no se puede comparar', () {
      final diff = ScanVerifier.verify(
        barcode: '7790001000002',
        items: [item()],
        scannedProduct: product(net: null),
      ) as ScanSizeDifference;

      expect(diff.advice.relation, SizeRelation.unknown);
      expect(diff.advice.unitsNeeded, isNull);
    });

    test('gramos vs mililitros no se comparan', () {
      final diff = ScanVerifier.verify(
        barcode: '7790001000002',
        items: [item()],
        scannedProduct: product(net: const NetQuantity(500, QuantityUnit.milliliter)),
      ) as ScanSizeDifference;

      expect(diff.advice.relation, SizeRelation.unknown);
    });

    test('ignora diferencias de tildes y mayúsculas en marca y nombre', () {
      final diff = ScanVerifier.verify(
        barcode: '7790001000002',
        items: [item(name: 'Leche Entera', brand: 'La Serenísima', net: const NetQuantity(1000, QuantityUnit.milliliter))],
        scannedProduct: product(
          name: 'LECHE ENTERA',
          brand: 'La Serenisima',
          net: const NetQuantity(500, QuantityUnit.milliliter),
        ),
      );
      expect(diff, isA<ScanSizeDifference>());
      expect((diff as ScanSizeDifference).advice.unitsNeeded, 2);
    });

    test('elige el ítem más parecido cuando hay varios de la misma marca', () {
      final result = ScanVerifier.verify(
        barcode: '7790001000002',
        items: [
          item(id: 'dulces', name: 'Galletitas dulces'),
          item(id: 'agua', name: 'Galletitas de agua'),
        ],
        scannedProduct: product(name: 'Galletitas de agua'),
      ) as ScanSizeDifference;
      expect(result.item.id, 'agua');
    });
  });

  group('no está en la lista', () {
    test('otra marca -> ScanNotInList', () {
      final result = ScanVerifier.verify(
        barcode: '7790001000002',
        items: [item()],
        scannedProduct: product(brand: 'Okebon'),
      );
      expect(result, isA<ScanNotInList>());
    });

    test('misma marca pero otro tipo de producto -> ScanNotInList', () {
      final result = ScanVerifier.verify(
        barcode: '7790001000002',
        items: [item()],
        scannedProduct: product(name: 'Aceite de girasol'),
      );
      expect(result, isA<ScanNotInList>());
    });

    test('los ítems ya tachados no cuentan como candidatos', () {
      final result = ScanVerifier.verify(
        barcode: '7790001000002',
        items: [item(checked: true)],
        scannedProduct: product(),
      );
      expect(result, isA<ScanNotInList>());
    });

    test('sin marca en el escaneado hace falta un nombre casi idéntico', () {
      final similar = ScanVerifier.verify(
        barcode: '7790001000002',
        items: [item()],
        scannedProduct: product(brand: null),
      );
      expect(similar, isA<ScanSizeDifference>());

      final vague = ScanVerifier.verify(
        barcode: '7790001000002',
        items: [item()],
        scannedProduct: product(brand: null, name: 'Galletitas'),
      );
      expect(vague, isA<ScanNotInList>());
    });

    test('código que Open Food Facts no conoce -> ScanUnknownBarcode', () {
      final result = ScanVerifier.verify(
        barcode: '7790009999999',
        items: [item()],
      );
      expect(result, isA<ScanUnknownBarcode>());
      expect((result as ScanUnknownBarcode).barcode, '7790009999999');
    });
  });
}

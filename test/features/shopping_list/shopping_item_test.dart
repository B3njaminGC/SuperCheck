import 'package:flutter_test/flutter_test.dart';
import 'package:supercheck/features/products/domain/net_quantity.dart';
import 'package:supercheck/features/shopping_list/domain/shopping_item.dart';

ShoppingItem item({int desired = 3, NetQuantity? net}) {
  return ShoppingItem(
    id: 'i1',
    listId: 'l1',
    name: 'Yogur',
    createdAt: DateTime(2026, 1, 1),
    desiredQty: desired,
    netQuantity: net,
  );
}

void main() {
  group('withPicked', () {
    test('suma unidades sin completar', () {
      final result = item().withPicked(1, userId: 'u1');

      expect(result.pickedQty, 1);
      expect(result.isChecked, isFalse);
      expect(result.checkedBy, isNull);
      expect(result.remainingQty, 2);
      expect(result.progressLabel, '1 de 3');
    });

    test('al llegar a la cantidad pedida se tacha y anota quién', () {
      final result = item().withPicked(3, userId: 'u1');

      expect(result.isChecked, isTrue);
      expect(result.checkedBy, 'u1');
      expect(result.checkedAt, isNotNull);
      expect(result.remainingQty, 0);
      expect(result.progressLabel, isNull);
    });

    test('no pasa de la cantidad pedida ni baja de cero', () {
      expect(item().withPicked(10).pickedQty, 3);
      expect(item().withPicked(-2).pickedQty, 0);
    });

    test('pedir una sola unidad no muestra progreso parcial', () {
      expect(item(desired: 1).progressLabel, isNull);
    });
  });

  group('toggled', () {
    test('pendiente -> completo -> reiniciado', () {
      final done = item().withPicked(1).toggled(userId: 'u1');
      expect(done.pickedQty, 3);
      expect(done.isChecked, isTrue);

      final reset = done.toggled();
      expect(reset.pickedQty, 0);
      expect(reset.isChecked, isFalse);
      expect(reset.checkedBy, isNull);
      expect(reset.checkedAt, isNull);
    });
  });

  group('withDesiredQty', () {
    test('subir la cantidad de un ítem completo lo vuelve pendiente', () {
      final done = item(desired: 2).withPicked(2, userId: 'u1');
      final more = done.withDesiredQty(3);

      expect(more.isChecked, isFalse);
      expect(more.pickedQty, 2);
      expect(more.checkedBy, isNull);
    });

    test('bajar por debajo de lo llevado lo completa', () {
      final partial = item(desired: 4).withPicked(2);
      final fewer = partial.withDesiredQty(2, userId: 'u2');

      expect(fewer.isChecked, isTrue);
      expect(fewer.pickedQty, 2);
      expect(fewer.checkedBy, 'u2');
    });

    test('la cantidad mínima es 1', () {
      expect(item().withDesiredQty(0).desiredQty, 1);
    });
  });

  group('remainingNetQuantity', () {
    const g = QuantityUnit.gram;

    test('solo cuenta lo que falta llevar', () {
      final yogurts = item(desired: 4, net: const NetQuantity(200, g)).withPicked(1);
      expect(yogurts.remainingNetQuantity, const NetQuantity(600, g));
      expect(yogurts.totalNetQuantity, const NetQuantity(800, g));
    });

    test('es null sin gramos o cuando ya no falta nada', () {
      expect(item(desired: 2).remainingNetQuantity, isNull);
      final done = item(desired: 2, net: const NetQuantity(200, g)).withPicked(2);
      expect(done.remainingNetQuantity, isNull);
    });
  });

  group('fromJson', () {
    final base = {
      'id': 'i1',
      'list_id': 'l1',
      'name': 'Pan',
      'created_at': '2026-01-01T00:00:00Z',
    };

    test('un ítem sin código ni cantidades usa los valores por defecto', () {
      final parsed = ShoppingItem.fromJson(base);
      expect(parsed.barcode, isNull);
      expect(parsed.desiredQty, 1);
      expect(parsed.pickedQty, 0);
      expect(parsed.isChecked, isFalse);
    });

    test('lee picked_qty y desired_qty', () {
      final parsed = ShoppingItem.fromJson({
        ...base,
        'desired_qty': 4,
        'picked_qty': 2,
      });
      expect(parsed.desiredQty, 4);
      expect(parsed.pickedQty, 2);
    });
  });
}

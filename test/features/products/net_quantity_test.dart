import 'package:flutter_test/flutter_test.dart';
import 'package:supercheck/features/products/domain/net_quantity.dart';

void main() {
  group('NetQuantity.tryParse', () {
    const g = QuantityUnit.gram;
    const ml = QuantityUnit.milliliter;

    final cases = <String, NetQuantity>{
      '300 g': const NetQuantity(300, g),
      '300g': const NetQuantity(300, g),
      '1 kg': const NetQuantity(1000, g),
      '1,5 kg': const NetQuantity(1500, g),
      '1.000 g': const NetQuantity(1000, g),
      '500 ml': const NetQuantity(500, ml),
      '500ml': const NetQuantity(500, ml),
      '1 L': const NetQuantity(1000, ml),
      '1,5 l': const NetQuantity(1500, ml),
      '33 cl': const NetQuantity(330, ml),
      '6 x 330 ml': const NetQuantity(1980, ml),
      '2x100 g': const NetQuantity(200, g),
    };

    cases.forEach((input, expected) {
      test('"$input" -> ${expected.toDisplayString()}', () {
        expect(NetQuantity.tryParse(input), expected);
      });
    });

    test('devuelve null cuando no hay peso ni volumen', () {
      expect(NetQuantity.tryParse('12 unidades'), isNull);
      expect(NetQuantity.tryParse(''), isNull);
      expect(NetQuantity.tryParse(null), isNull);
    });
  });

  group('NetQuantity comparaciones', () {
    test('ratioTo: 500 g contiene 2 paquetes de 250 g', () {
      const wanted = NetQuantity(500, QuantityUnit.gram);
      const scanned = NetQuantity(250, QuantityUnit.gram);
      expect(wanted.ratioTo(scanned), 2.0);
    });

    test('ratioTo es null si las unidades no coinciden', () {
      const grams = NetQuantity(500, QuantityUnit.gram);
      const millis = NetQuantity(500, QuantityUnit.milliliter);
      expect(grams.ratioTo(millis), isNull);
    });
  });

  group('NetQuantity.toDisplayString', () {
    test('formatea con coma decimal y cambia a kg / L desde 1000', () {
      expect(const NetQuantity(300, QuantityUnit.gram).toDisplayString(), '300 g');
      expect(const NetQuantity(1500, QuantityUnit.gram).toDisplayString(), '1,5 kg');
      expect(const NetQuantity(1980, QuantityUnit.milliliter).toDisplayString(), '1,98 L');
    });
  });
}

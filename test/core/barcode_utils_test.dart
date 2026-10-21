import 'package:flutter_test/flutter_test.dart';
import 'package:supercheck/core/utils/barcode_utils.dart';

void main() {
  group('BarcodeUtils.normalize', () {
    test('saca no-dígitos y ceros a la izquierda', () {
      expect(BarcodeUtils.normalize(' 0012-3456 '), '123456');
      expect(BarcodeUtils.normalize(null), '');
    });
  });

  group('BarcodeUtils.isSame', () {
    test('UPC-A (12) y EAN-13 con cero adelante son el mismo producto', () {
      expect(BarcodeUtils.isSame('0012345678905', '012345678905'), isTrue);
      expect(BarcodeUtils.isSame('7790070410009', '7790070410016'), isFalse);
    });

    test('vacío o nulo nunca coincide', () {
      expect(BarcodeUtils.isSame(null, null), isFalse);
      expect(BarcodeUtils.isSame('', ''), isFalse);
    });
  });

  group('BarcodeUtils.hasValidChecksum', () {
    test('acepta códigos válidos', () {
      expect(BarcodeUtils.hasValidChecksum('4006381333931'), isTrue); // EAN-13
      expect(BarcodeUtils.hasValidChecksum('012345678905'), isTrue); // UPC-A
    });

    test('rechaza dígito verificador incorrecto o largo inválido', () {
      expect(BarcodeUtils.hasValidChecksum('4006381333932'), isFalse);
      expect(BarcodeUtils.hasValidChecksum('12345'), isFalse);
    });
  });
}

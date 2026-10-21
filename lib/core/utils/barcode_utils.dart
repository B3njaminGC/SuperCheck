abstract final class BarcodeUtils {
  /// Deja solo dígitos y saca los ceros a la izquierda.
  ///
  /// Un UPC-A (12 dígitos) se lee como EAN-13 con un 0 adelante, y Open Food Facts
  /// a veces guarda códigos sin ceros iniciales. Normalizar así hace que
  /// `0012345678905`, `012345678905` y `12345678905` sean el mismo producto.
  static String normalize(String? raw) {
    if (raw == null) return '';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.replaceFirst(RegExp(r'^0+'), '');
  }

  static bool isSame(String? a, String? b) {
    final na = normalize(a);
    final nb = normalize(b);
    return na.isNotEmpty && na == nb;
  }

  /// Valida el dígito verificador GTIN (EAN-8, UPC-A, EAN-13, GTIN-14).
  static bool hasValidChecksum(String raw) {
    final code = raw.replaceAll(RegExp(r'\D'), '');
    if (![8, 12, 13, 14].contains(code.length)) return false;

    final digits = code.split('').map(int.parse).toList();
    final check = digits.removeLast();

    var sum = 0;
    // Desde la derecha (sin el verificador) los pesos alternan 3, 1, 3, 1...
    for (var i = 0; i < digits.length; i++) {
      final fromRight = digits.length - 1 - i;
      sum += digits[i] * (fromRight.isEven ? 3 : 1);
    }
    return (10 - (sum % 10)) % 10 == check;
  }
}

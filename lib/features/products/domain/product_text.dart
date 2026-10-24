import 'product.dart';

/// Comparación de texto para buscar en los productos de la persona (propios y favoritos).
abstract final class ProductText {
  /// Minúsculas y sin tildes: "Azúcar" y "azucar" son lo mismo.
  static String fold(String text) {
    const from = 'áàäâéèëêíìïîóòöôúùüûñ';
    const to = 'aaaaeeeeiiiioooouuuun';
    final out = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      final i = from.indexOf(ch);
      out.write(i >= 0 ? to[i] : ch);
    }
    return out.toString();
  }

  /// `true` si el producto contiene todas las palabras de [query], mirando nombre,
  /// marca y tamaño.
  static bool matches(String query, Product product) {
    final words = fold(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return false;
    final haystack =
        fold('${product.name} ${product.brand ?? ''} ${product.quantityLabel ?? ''}');
    return words.every(haystack.contains);
  }
}

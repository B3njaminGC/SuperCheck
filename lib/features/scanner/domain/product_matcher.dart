import 'dart:math' as math;

/// Decide si dos productos son "el mismo producto en otro tamaño" (misma marca y
/// mismo tipo de producto), sin importar el código de barras.
///
/// Es una heurística sobre nombre y marca, porque Open Food Facts no trae un
/// identificador de "familia". Limitación conocida: variantes que solo difieren en
/// una palabra ("Galletitas de agua" vs "Galletitas de agua light") pueden
/// considerarse la misma familia. Por eso la UI siempre muestra qué producto se
/// escaneó, y el usuario decide.
abstract final class ProductMatcher {
  /// Devuelve un puntaje en (0, 1], o `null` si no parecen el mismo producto.
  ///
  /// - Ambos con marca: las marcas deben coincidir y alcanza con que la mitad
  ///   de las palabras del nombre más corto aparezcan en el otro.
  /// - Falta alguna marca: se exige un solapamiento alto (>= 80%) y al menos
  ///   2 palabras en común.
  static double? familyScore({
    required String nameA,
    String? brandA,
    required String nameB,
    String? brandB,
  }) {
    final normBrandA = _normalize(brandA);
    final normBrandB = _normalize(brandB);
    final bothHaveBrand = normBrandA.isNotEmpty && normBrandB.isNotEmpty;
    if (bothHaveBrand && !_sameBrand(normBrandA, normBrandB)) return null;

    // La marca suele repetirse dentro del nombre ("Galletitas Criollitas"):
    // se la saca para no inflar ni distorsionar el solapamiento.
    final brandTokens = <String>{
      ...normBrandA.split(' '),
      ...normBrandB.split(' '),
    }..remove('');

    final tokensA = _withoutBrand(_nameTokens(nameA), brandTokens);
    final tokensB = _withoutBrand(_nameTokens(nameB), brandTokens);
    if (tokensA.isEmpty || tokensB.isEmpty) return null;

    final shared = tokensA.intersection(tokensB).length;
    if (shared == 0) return null;

    final overlap = shared / math.min(tokensA.length, tokensB.length);
    if (bothHaveBrand) return overlap >= 0.5 ? overlap : null;
    return (overlap >= 0.8 && shared >= 2) ? overlap : null;
  }

  static bool _sameBrand(String a, String b) {
    if (a == b) return true;
    // "serenisima" vs "la serenisima": una contiene a la otra.
    final shorter = a.length <= b.length ? a : b;
    final longer = identical(shorter, a) ? b : a;
    return shorter.length >= 4 && longer.contains(shorter);
  }

  static Set<String> _withoutBrand(Set<String> tokens, Set<String> brandTokens) {
    final stripped = tokens.difference(brandTokens);
    return stripped.isEmpty ? tokens : stripped;
  }

  static Set<String> _nameTokens(String name) {
    return _normalize(name)
        .split(' ')
        .where(
          (t) =>
              t.length >= 2 &&
              !_stopWords.contains(t) &&
              !_unitWords.contains(t) &&
              !t.contains(RegExp(r'\d')),
        )
        .toSet();
  }

  static const _stopWords = {
    'de', 'del', 'la', 'el', 'los', 'las', 'y', 'e', 'con', 'sin', 'en',
    'para', 'al', 'un', 'una', 'por',
  };

  static const _unitWords = {
    'g', 'gr', 'grs', 'gramo', 'gramos', 'kg', 'kgs', 'kilo', 'kilos',
    'ml', 'cl', 'cc', 'l', 'lt', 'lts', 'litro', 'litros', 'un', 'unidades',
  };

  static const _accents = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n',
  };

  /// Minúsculas, sin tildes ni signos, con espacios simples.
  static String _normalize(String? text) {
    if (text == null) return '';
    final buffer = StringBuffer();
    for (final char in text.toLowerCase().split('')) {
      buffer.write(_accents[char] ?? char);
    }
    return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }
}

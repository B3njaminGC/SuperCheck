import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/product.dart';

/// Acceso al catálogo de Open Food Facts.
///
/// - Por código de barras: `GET /api/v2/product/{barcode}.json`
/// - Por nombre: primero Search-a-licious (`search.openfoodfacts.org/search`), el buscador
///   de texto pensado para este uso. Si falla o responde algo inesperado, se usa el
///   buscador clásico `GET /cgi/search.pl`, que solo permite 10 búsquedas por minuto por
///   IP y responde 503 al pasarse.
///   OJO: el endpoint `/api/v2/search` de OFF filtra por etiquetas pero no hace búsqueda
///   de texto libre por nombre.
class ProductRepository {
  ProductRepository({
    required http.Client client,
    String host = AppConstants.offHost,
    String? countryTag = AppConstants.offDefaultCountryTag,
    bool fallbackToWorld = true,
    bool useSearchALicious = true,
    String searchHost = AppConstants.offSearchHost,
    Duration timeout = AppConstants.httpTimeout,
  })  : _client = client,
        _useSearchALicious = useSearchALicious,
        _searchHost = searchHost,
        _host = host,
        _countryTag = countryTag,
        _fallbackToWorld = fallbackToWorld,
        _timeout = timeout;

  final http.Client _client;
  final String _host;
  final String? _countryTag;
  final bool _fallbackToWorld;
  final bool _useSearchALicious;
  final String _searchHost;
  final Duration _timeout;

  static const _headers = {
    'User-Agent': AppConstants.offUserAgent,
    'Accept': 'application/json',
  };

  /// Busca productos por nombre (ej. "galletitas de agua").
  ///
  /// Prioriza productos vendidos en el país configurado; si no hay resultados en la
  /// primera página, repite la búsqueda sin filtro de país.
  Future<List<Product>> searchByName(
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final typed = query.trim();
    if (typed.length < 2) return const [];
    final term = _withoutFillerWords(typed);

    if (_useSearchALicious) {
      try {
        final results = await _searchModern(term, page: page, pageSize: pageSize);
        if (results.isNotEmpty || page > 1) return results;
        // Sin resultados: se prueba también el buscador clásico, que indexa distinto.
        try {
          return await _searchLegacy(term, page: page, pageSize: pageSize);
        } on AppException {
          return results;
        }
      } on AppException {
        // Cae al buscador clásico: mejor uno limitado que ninguno.
      }
    }
    return _searchLegacy(term, page: page, pageSize: pageSize);
  }

  static const _fillerWords = {
    'el', 'la', 'las', 'los', 'lo', 'de', 'del', 'y', 'e', 'un', 'una', 'unos',
    'unas', 'en', 'al', 'con', 'para',
  };

  /// Los buscadores exigen que aparezcan todas las palabras: "azúcar impalpable las dos
  /// anclas" no encontraba "Dos Anclas" por culpa del "las". Se sacan artículos y
  /// conectores; si no queda nada, se usa el texto tal cual.
  static String _withoutFillerWords(String text) {
    final kept = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !_fillerWords.contains(w.toLowerCase()))
        .toList();
    return kept.isEmpty ? text : kept.join(' ');
  }

  Future<List<Product>> _searchLegacy(
    String term, {
    required int page,
    required int pageSize,
  }) async {
    final country = _countryTag;
    if (country != null) {
      final local = await _search(
        term,
        page: page,
        pageSize: pageSize,
        countryTag: country,
      );
      if (local.isNotEmpty || !_fallbackToWorld || page > 1) return local;
    }
    return _search(term, page: page, pageSize: pageSize);
  }

  /// Devuelve el producto con ese código de barras, o `null` si OFF no lo conoce.
  Future<Product?> getByBarcode(String barcode) async {
    final code = barcode.replaceAll(RegExp(r'\D'), '');
    if (code.isEmpty) return null;

    final uri = Uri.https(_host, '/api/v2/product/$code.json', {
      'fields': AppConstants.offFields,
    });
    final response = await _get(uri);
    if (response.statusCode == 404) return null;
    _ensureSuccess(response);

    final body = _decode(response);
    final product = body['product'];
    if (product is! Map<String, dynamic>) return null;

    return Product.tryFromOffJson({
      ...product,
      'code': product['code'] ?? code,
    });
  }

  // ---------------------------------------------------------------------

  /// Search-a-licious: `GET /search?q=...`, con el país como filtro de la consulta.
  Future<List<Product>> _searchModern(
    String term, {
    required int page,
    required int pageSize,
  }) async {
    // Los caracteres de la sintaxis de consulta romperían la búsqueda.
    final clean = term.replaceAll(RegExp(r'[\"():\\\[\]{}^~*?!/]'), ' ').trim();
    if (clean.length < 2) return const [];

    final country = _countryTag;
    if (country != null) {
      final local = await _modernRequest(
        '$clean AND countries_tags:"en:$country"',
        page: page,
        pageSize: pageSize,
      );
      if (local.isNotEmpty || !_fallbackToWorld || page > 1) return local;
    }
    return _modernRequest(clean, page: page, pageSize: pageSize);
  }

  Future<List<Product>> _modernRequest(
    String q, {
    required int page,
    required int pageSize,
  }) async {
    final uri = Uri.https(_searchHost, '/search', {
      'q': q,
      'langs': 'es',
      'page': '$page',
      'page_size': '$pageSize',
    });
    final response = await _get(uri);
    _ensureSuccess(response);

    final hits = _decode(response)['hits'];
    if (hits is! List) {
      throw const DataParsingException('Respuesta inesperada del buscador.');
    }

    final seen = <String>{};
    final results = <Product>[];
    for (final raw in hits) {
      if (raw is! Map) continue;
      final product = Product.tryFromOffJson(_flattenHit(raw));
      if (product != null && seen.add(product.barcode)) {
        results.add(product);
      }
    }
    return results;
  }

  static const _hitTextFields = [
    'code',
    'product_name',
    'product_name_es',
    'generic_name',
    'brands',
    'quantity',
    'product_quantity_unit',
    'image_front_small_url',
    'image_front_url',
    'image_small_url',
    'image_url',
  ];

  /// Search-a-licious puede devolver textos como cadena, lista (marcas) o un mapa por
  /// idioma (nombres). Se pasan al formato plano que entiende [Product.tryFromOffJson].
  static Map<String, dynamic> _flattenHit(Map raw) {
    final hit = <String, dynamic>{...raw.cast<String, dynamic>()};
    for (final key in _hitTextFields) {
      final flat = _flatten(hit[key]);
      if (flat != null) hit[key] = flat;
    }
    return hit;
  }

  static String? _flatten(Object? value) {
    if (value is String) return value;
    if (value is num) return value.toString();
    if (value is List) {
      final parts = value.map(_flatten).whereType<String>().where((s) => s.isNotEmpty);
      return parts.isEmpty ? null : parts.join(',');
    }
    if (value is Map) {
      for (final key in const ['es', 'main', 'en']) {
        final flat = _flatten(value[key]);
        if (flat != null && flat.isNotEmpty) return flat;
      }
      for (final v in value.values) {
        final flat = _flatten(v);
        if (flat != null && flat.isNotEmpty) return flat;
      }
    }
    return null;
  }

  Uri _searchUri(
    String term, {
    required int page,
    required int pageSize,
    String? countryTag,
  }) {
    return Uri.https(_host, '/cgi/search.pl', {
      'search_terms': term,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page': '$page',
      'page_size': '$pageSize',
      'sort_by': 'unique_scans_n', // los más escaneados primero = más comunes
      'fields': AppConstants.offFields,
      if (countryTag != null) ...{
        'tagtype_0': 'countries',
        'tag_contains_0': 'contains',
        'tag_0': countryTag,
      },
    });
  }

  Future<List<Product>> _search(
    String term, {
    required int page,
    required int pageSize,
    String? countryTag,
  }) async {
    final uri = _searchUri(
      term,
      page: page,
      pageSize: pageSize,
      countryTag: countryTag,
    );
    final response = await _get(uri);
    _ensureSuccess(response);

    final rawProducts = _decode(response)['products'];
    if (rawProducts is! List) return const [];

    final seen = <String>{};
    final results = <Product>[];
    for (final raw in rawProducts) {
      if (raw is! Map<String, dynamic>) continue;
      final product = Product.tryFromOffJson(raw);
      if (product != null && seen.add(product.barcode)) {
        results.add(product);
      }
    }
    return results;
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      return await _client.get(uri, headers: _headers).timeout(_timeout);
    } on TimeoutException catch (e) {
      throw NetworkException(
        'Open Food Facts tardó demasiado en responder.',
        cause: e,
      );
    } on SocketException catch (e) {
      throw NetworkException('Sin conexión a internet.', cause: e);
    } on http.ClientException catch (e) {
      throw NetworkException('No se pudo conectar con Open Food Facts.', cause: e);
    }
  }

  void _ensureSuccess(http.Response response) {
    final code = response.statusCode;
    if (code >= 200 && code < 300) return;
    if (code == 429) {
      throw const RateLimitException(
        'Demasiadas búsquedas seguidas. Esperá unos segundos e intentá de nuevo.',
      );
    }
    if (code == 502 || code == 503 || code == 504) {
      throw RemoteServiceException(
        'Open Food Facts está saturado o limitó las búsquedas ($code). '
        'Probá de nuevo en un minuto, o agregalo sin código.',
        statusCode: code,
      );
    }
    throw RemoteServiceException(
      'Open Food Facts respondió con error ($code).',
      statusCode: code,
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      // bodyBytes + utf8 para no depender del charset del header (tildes, ñ).
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      throw const FormatException('La respuesta no es un objeto JSON.');
    } on FormatException catch (e) {
      throw DataParsingException(
        'Respuesta inesperada de Open Food Facts.',
        cause: e,
      );
    }
  }
}

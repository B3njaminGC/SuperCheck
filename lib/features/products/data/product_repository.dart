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
/// - Por nombre: `GET /cgi/search.pl` (búsqueda de texto).
///   OJO: el endpoint `/api/v2/search` de OFF filtra por etiquetas (marca, categoría,
///   país...) pero no hace búsqueda de texto libre por nombre. Si más adelante querés
///   mejor relevancia, el reemplazo es Search-a-licious; solo habría que cambiar
///   [_searchUri] y el parseo de la respuesta.
class ProductRepository {
  ProductRepository({
    required http.Client client,
    String host = AppConstants.offHost,
    String? countryTag = AppConstants.offDefaultCountryTag,
    bool fallbackToWorld = true,
    Duration timeout = AppConstants.httpTimeout,
  })  : _client = client,
        _host = host,
        _countryTag = countryTag,
        _fallbackToWorld = fallbackToWorld,
        _timeout = timeout;

  final http.Client _client;
  final String _host;
  final String? _countryTag;
  final bool _fallbackToWorld;
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
    final term = query.trim();
    if (term.length < 2) return const [];

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

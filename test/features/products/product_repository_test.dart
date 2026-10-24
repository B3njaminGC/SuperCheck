import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercheck/core/errors/app_exception.dart';
import 'package:supercheck/features/products/data/product_repository.dart';
import 'package:supercheck/features/products/domain/net_quantity.dart';

http.Response _json(Object body, [int status = 200]) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// Por defecto usa solo el buscador clásico; los tests de Search-a-licious lo piden aparte.
ProductRepository _repo(
  MockClientHandler handler, {
  String? countryTag = 'argentina',
  bool modern = false,
}) {
  return ProductRepository(
    client: MockClient(handler),
    countryTag: countryTag,
    useSearchALicious: modern,
  );
}

void main() {
  group('searchByName', () {
    test('parsea productos, filtra por país y descarta los incompletos', () async {
      late http.Request captured;
      final repo = _repo((request) async {
        captured = request;
        return _json({
          'count': 3,
          'products': [
            {
              'code': '7622300000001',
              'product_name': 'Galletitas de agua',
              'brands': 'Criollitas,Mondelez',
              'quantity': '300 g',
              'image_front_small_url': 'https://img.example/1.jpg',
            },
            {'code': '', 'product_name': 'Sin código'},
            {'code': '7622300000002'},
          ],
        });
      });

      final results = await repo.searchByName('galletitas de agua');

      expect(captured.url.host, 'world.openfoodfacts.org');
      expect(captured.url.path, '/cgi/search.pl');
      expect(captured.url.queryParameters['search_terms'], 'galletitas de agua');
      expect(captured.url.queryParameters['tag_0'], 'argentina');
      expect(captured.headers['User-Agent'], contains('SuperCheck'));

      expect(results, hasLength(1));
      final p = results.single;
      expect(p.barcode, '7622300000001');
      expect(p.name, 'Galletitas de agua');
      expect(p.brand, 'Criollitas');
      expect(p.quantityLabel, '300 g');
      expect(p.netQuantity, const NetQuantity(300, QuantityUnit.gram));
      expect(p.imageUrl, 'https://img.example/1.jpg');
    });

    test('si no hay resultados en el país, reintenta sin filtro', () async {
      var calls = 0;
      final repo = _repo((request) async {
        calls++;
        if (request.url.queryParameters.containsKey('tag_0')) {
          return _json({'products': <Object>[]});
        }
        return _json({
          'products': [
            {'code': '1', 'product_name': 'Cookies', 'quantity': '200 g'},
          ],
        });
      });

      final results = await repo.searchByName('cookies');

      expect(calls, 2);
      expect(results.single.name, 'Cookies');
    });

    test('no consulta la API con textos de menos de 2 caracteres', () async {
      final repo = _repo((_) async => fail('No debería llamar a la API'));
      expect(await repo.searchByName(' a '), isEmpty);
    });

    test('elimina duplicados por código de barras', () async {
      final repo = _repo((_) async => _json({
            'products': [
              {'code': '1', 'product_name': 'Leche'},
              {'code': '1', 'product_name': 'Leche (dup)'},
            ],
          }));
      expect(await repo.searchByName('leche'), hasLength(1));
    });

    test('HTTP 429 -> RateLimitException', () async {
      final repo = _repo((_) async => http.Response('', 429));
      expect(repo.searchByName('leche'), throwsA(isA<RateLimitException>()));
    });

    test('HTTP 500 -> RemoteServiceException con statusCode', () async {
      final repo = _repo((_) async => http.Response('', 500));
      await expectLater(
        repo.searchByName('leche'),
        throwsA(
          isA<RemoteServiceException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('cuerpo que no es JSON -> DataParsingException', () async {
      final repo = _repo((_) async => http.Response('<html>', 200));
      expect(repo.searchByName('leche'), throwsA(isA<DataParsingException>()));
    });

    test('fallo de conexión -> NetworkException', () async {
      final repo = _repo((_) async => throw http.ClientException('boom'));
      expect(repo.searchByName('leche'), throwsA(isA<NetworkException>()));
    });
  });

  group('searchByName con Search-a-licious', () {
    const hit = {
      'code': '7790001000011',
      'product_name': {'es': 'Leche entera', 'en': 'Whole milk'},
      'brands': ['La Serenísima', 'Otra'],
      'quantity': '1 l',
      'image_front_small_url': 'https://img.example/leche.jpg',
    };

    test('consulta search.openfoodfacts.org con el filtro de país y aplana los datos',
        () async {
      late http.Request captured;
      final repo = _repo((request) async {
        captured = request;
        return _json({'hits': [hit], 'count': 1});
      }, modern: true);

      final results = await repo.searchByName('leche');

      expect(captured.url.host, 'search.openfoodfacts.org');
      expect(captured.url.path, '/search');
      expect(captured.url.queryParameters['q'], contains('leche'));
      expect(captured.url.queryParameters['q'], contains('countries_tags:"en:argentina"'));
      expect(captured.headers['User-Agent'], contains('SuperCheck'));
      final p = results.single;
      expect(p.name, 'Leche entera');
      expect(p.brand, 'La Serenísima');
      expect(p.netQuantity, const NetQuantity(1000, QuantityUnit.milliliter));
    });

    test('sin resultados en el país, repite sin filtro (en el mismo buscador)', () async {
      final queries = <String>[];
      final repo = _repo((request) async {
        queries.add(request.url.queryParameters['q']!);
        return queries.length == 1
            ? _json({'hits': <Object>[]})
            : _json({'hits': [hit]});
      }, modern: true);

      final results = await repo.searchByName('leche');

      expect(queries, hasLength(2));
      expect(queries.first, contains('countries_tags'));
      expect(queries.last, isNot(contains('countries_tags')));
      expect(results, hasLength(1));
    });

    test('quita los caracteres de la sintaxis de consulta', () async {
      late String q;
      final repo = _repo((request) async {
        q = request.url.queryParameters['q']!;
        return _json({'hits': [hit]});
      }, modern: true, countryTag: null);

      await repo.searchByName('leche "entera": (1l)');

      expect(q, isNot(contains('"')));
      expect(q, isNot(contains(':')));
      expect(q, isNot(contains('(')));
      expect(q, contains('leche'));
    });

    test('si el buscador responde 503, usa el clásico', () async {
      final hosts = <String>[];
      final repo = _repo((request) async {
        hosts.add(request.url.host);
        if (request.url.host == 'search.openfoodfacts.org') {
          return http.Response('', 503);
        }
        return _json({
          'products': [
            {'code': '1', 'product_name': 'Leche clásica'},
          ],
        });
      }, modern: true);

      final results = await repo.searchByName('leche');

      expect(hosts, ['search.openfoodfacts.org', 'world.openfoodfacts.org']);
      expect(results.single.name, 'Leche clásica');
    });

    test('si la respuesta no tiene "hits", usa el clásico', () async {
      final repo = _repo((request) async {
        if (request.url.host == 'search.openfoodfacts.org') {
          return _json({'algo': 'raro'});
        }
        return _json({
          'products': [
            {'code': '1', 'product_name': 'Leche clásica'},
          ],
        });
      }, modern: true);

      expect((await repo.searchByName('leche')).single.name, 'Leche clásica');
    });

    test('si fallan los dos, el error mostrado explica el 503', () async {
      final repo = _repo((_) async => http.Response('', 503), modern: true);
      await expectLater(
        repo.searchByName('leche'),
        throwsA(
          isA<RemoteServiceException>()
              .having((e) => e.statusCode, 'statusCode', 503)
              .having((e) => e.message, 'message', contains('saturado')),
        ),
      );
    });
  });

  group('getByBarcode', () {
    test('devuelve el producto y usa el código consultado si OFF no lo repite', () async {
      late http.Request captured;
      final repo = _repo((request) async {
        captured = request;
        return _json({
          'status': 1,
          'product': {
            'product_name': 'Fideos tirabuzón',
            'brands': 'Matarazzo',
            'quantity': '500 g',
          },
        });
      });

      final product = await repo.getByBarcode('7790070410009');

      expect(captured.url.path, '/api/v2/product/7790070410009.json');
      expect(product, isNotNull);
      expect(product!.barcode, '7790070410009');
      expect(product.brand, 'Matarazzo');
      expect(product.netQuantity, const NetQuantity(500, QuantityUnit.gram));
    });

    test('404 o status 0 -> null', () async {
      final notFound = _repo((_) async => _json({'status': 0}, 404));
      expect(await notFound.getByBarcode('123'), isNull);

      final status0 = _repo((_) async => _json({'status': 0, 'code': '123'}));
      expect(await status0.getByBarcode('123'), isNull);
    });

    test('código vacío -> null sin llamar a la API', () async {
      final repo = _repo((_) async => fail('No debería llamar a la API'));
      expect(await repo.getByBarcode('abc'), isNull);
    });
  });
}

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

ProductRepository _repo(MockClientHandler handler, {String? countryTag = 'argentina'}) {
  return ProductRepository(client: MockClient(handler), countryTag: countryTag);
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

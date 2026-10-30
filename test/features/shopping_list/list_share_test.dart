import 'dart:convert';
import 'dart:io' show GZipCodec, ZLibCodec;

import 'package:flutter_test/flutter_test.dart';
import 'package:supercheck/features/shopping_list/domain/list_share.dart';

SharedList _sample() => const SharedList(
      sourceId: 'list-1',
      name: 'Compras del mes',
      items: [
        SharedItem(name: 'Pan', desiredQty: 2),
        SharedItem(
          name: 'Azúcar impalpable',
          brand: 'Dos Anclas',
          quantityLabel: '300 g',
          barcode: '7782900990620',
          imageUrl: 'https://images.openfoodfacts.org/images/products/778/a.jpg',
        ),
      ],
    );

/// Arma un código a mano, para probar entradas que nuestra app nunca generaría.
String _code(Object json) {
  final bytes = GZipCodec().encode(utf8.encode(jsonEncode(json)));
  return 'SC1:${base64Url.encode(bytes).replaceAll('=', '')}';
}

void main() {
  group('ListShareCodec', () {
    test('ida y vuelta conserva nombre, productos, marca, tamaño, código y cantidad', () {
      final decoded = ListShareCodec.decode(ListShareCodec.encode(_sample()))!;

      expect(decoded.name, 'Compras del mes');
      expect(decoded.sourceId, 'list-1');
      expect(decoded.items, hasLength(2));
      expect(decoded.items[0].name, 'Pan');
      expect(decoded.items[0].desiredQty, 2);
      expect(decoded.items[0].barcode, isNull);
      expect(decoded.items[1].brand, 'Dos Anclas');
      expect(decoded.items[1].quantityLabel, '300 g');
      expect(decoded.items[1].barcode, '7782900990620');
      expect(decoded.items[1].imageUrl, contains('openfoodfacts.org'));
    });

    test('encuentra el código dentro del mensaje completo', () {
      final message = ListShareCodec.toMessage(_sample());
      final decoded = ListShareCodec.decode('Hola! mirá esto:\n\n$message\n\ngracias')!;
      expect(decoded.items, hasLength(2));
    });

    test('el mensaje se lee sin la app: lista los productos y trae el código', () {
      final message = ListShareCodec.toMessage(_sample());
      expect(message, contains('Compras del mes · 2 productos'));
      expect(message, contains('• Pan ×2'));
      expect(message, contains('• Azúcar impalpable (Dos Anclas · 300 g)'));
      expect(message, contains('SC2:'));
    });

    test('con acentos y emojis en los nombres no se rompe', () {
      const list = SharedList(
        name: 'Fiesta 🎉 de Ñandú',
        items: [SharedItem(name: 'Maní con cáscara 🥜')],
      );
      final decoded = ListShareCodec.decode(ListShareCodec.encode(list))!;
      expect(decoded.name, 'Fiesta 🎉 de Ñandú');
      expect(decoded.items.single.name, 'Maní con cáscara 🥜');
    });

    test('texto sin código, código cortado o dañado -> null', () {
      expect(ListShareCodec.decode('hola'), isNull);
      expect(ListShareCodec.decode(''), isNull);
      expect(ListShareCodec.decode('SC1:'), isNull);
      expect(ListShareCodec.decode('SC1:abc'), isNull);
      final good = ListShareCodec.encode(_sample());
      expect(ListShareCodec.decode(good.substring(0, good.length - 12)), isNull);
    });

    test('un código con otra versión o sin nombre se rechaza', () {
      expect(ListShareCodec.decode(_code({'v': 2, 'n': 'X', 'i': []})), isNull);
      expect(ListShareCodec.decode(_code({'v': 1, 'i': []})), isNull);
      expect(ListShareCodec.decode(_code({'v': 1, 'n': 'X', 'i': 'nada'})), isNull);
    });

    test('limpia los datos de un tercero: fotos ajenas, códigos y cantidades raras', () {
      final decoded = ListShareCodec.decode(_code({
        'v': 1,
        'n': '  Lista   rara  ',
        'i': [
          {
            'n': 'Leche',
            'm': 'https://sitio-malo.example/track.png',
            'c': 'abc',
            'd': 100000,
          },
          {'n': 'Yerba', 'm': 'http://images.openfoodfacts.org/x.jpg', 'c': '12-345'},
          {'n': 'Fideos', 'c': '7790001000011', 'd': -3},
          {'n': ''},
          {'sin': 'nombre'},
          'basura',
        ],
      }))!;

      expect(decoded.name, 'Lista rara');
      expect(decoded.items.map((i) => i.name), ['Leche', 'Yerba', 'Fideos']);
      expect(decoded.items[0].imageUrl, isNull); // otro dominio
      expect(decoded.items[0].barcode, isNull); // no son números
      expect(decoded.items[0].desiredQty, 999); // tope
      expect(decoded.items[1].imageUrl, isNull); // sin https
      expect(decoded.items[1].barcode, isNull); // muy corto
      expect(decoded.items[2].barcode, '7790001000011');
      expect(decoded.items[2].desiredQty, 1);
    });

    test('recorta textos larguísimos y limita la cantidad de productos', () {
      final decoded = ListShareCodec.decode(_code({
        'v': 1,
        'n': 'N' * 500,
        'i': [
          for (var i = 0; i < 1000; i++) {'n': 'Producto $i'},
        ],
      }))!;
      expect(decoded.name.length, 80);
      expect(decoded.items, hasLength(300));
    });

    test('un código enorme se rechaza sin intentar leerlo', () {
      expect(ListShareCodec.decode('SC1:${'A' * 50000}'), isNull);
    });
  });

  group('código SC2', () {
    String folder(String b) =>
        '${b.substring(0, 3)}/${b.substring(3, 6)}/${b.substring(6, 9)}/${b.substring(9)}';

    List<SharedItem> fifteen() => [
          for (var i = 0; i < 15; i++)
            () {
              final barcode = '779${(1000000000 + i * 7919317).toString()}';
              return SharedItem(
                name: 'Producto número $i',
                brand: i.isEven ? 'La Serenísima' : 'Marca $i',
                quantityLabel: '${100 + i * 25} g',
                barcode: barcode,
                imageUrl:
                    'https://images.openfoodfacts.org/images/products/${folder(barcode)}/front_es.${10 + i}.200.jpg',
                desiredQty: i % 3 == 0 ? 2 : 1,
              );
            }(),
        ];

    test('ida y vuelta conserva todo, incluida la foto reconstruida', () {
      final items = fifteen();
      final decoded =
          ListShareCodec.decode(ListShareCodec.encode(SharedList(name: 'Mes', items: items)))!;

      expect(decoded.items, hasLength(15));
      for (var i = 0; i < 15; i++) {
        expect(decoded.items[i].name, items[i].name);
        expect(decoded.items[i].brand, items[i].brand);
        expect(decoded.items[i].quantityLabel, items[i].quantityLabel);
        expect(decoded.items[i].barcode, items[i].barcode);
        expect(decoded.items[i].imageUrl, items[i].imageUrl);
        expect(decoded.items[i].desiredQty, items[i].desiredQty);
      }
    });

    test('es bastante más corto que el formato anterior', () {
      final items = fifteen();
      final sc2 = ListShareCodec.encode(SharedList(name: 'Mes', items: items));
      final sc1 = _code({
        'v': 1,
        'n': 'Mes',
        'i': [
          for (final it in items)
            {
              'n': it.name,
              'b': it.brand,
              'q': it.quantityLabel,
              'c': it.barcode,
              'm': it.imageUrl,
              if (it.desiredQty != 1) 'd': it.desiredQty,
            },
        ],
      });
      expect(sc2.length, lessThan(sc1.length * 0.8));
    });

    test('códigos con ceros adelante, cortos, y fotos de otro formato', () {
      const items = [
        SharedItem(name: 'A', barcode: '0012345678905'),
        SharedItem(name: 'B', barcode: '12345678'),
        SharedItem(
          name: 'C',
          barcode: '7790001000011',
          imageUrl: 'https://images.openfoodfacts.org/images/products/otra/cosa.jpg',
        ),
        SharedItem(name: 'D', imageUrl: 'https://images.openfoodfacts.org/x.jpg'),
      ];
      final decoded = ListShareCodec.decode(
        ListShareCodec.encode(const SharedList(name: 'L', items: items)),
      )!;
      expect(decoded.items.map((i) => i.barcode), ['0012345678905', '12345678', '7790001000011', null]);
      expect(decoded.items[2].imageUrl, 'https://images.openfoodfacts.org/images/products/otra/cosa.jpg');
      expect(decoded.items[3].imageUrl, 'https://images.openfoodfacts.org/x.jpg');
    });

    test('los mensajes viejos (SC1) se siguen leyendo', () {
      final decoded = ListShareCodec.decode(_code({
        'v': 1,
        'n': 'Vieja',
        'i': [
          {'n': 'Pan', 'd': 2},
        ],
      }))!;
      expect(decoded.name, 'Vieja');
      expect(decoded.items.single.desiredQty, 2);
    });

    test('un SC2 cortado, dañado o que se expande demasiado da null', () {
      final code = ListShareCodec.encode(SharedList(name: 'Mes', items: fifteen()));
      expect(ListShareCodec.decode(code.substring(0, code.length ~/ 2)), isNull);
      expect(ListShareCodec.decode('SC2:'), isNull);
      expect(ListShareCodec.decode('SC2:abc'), isNull);
      expect(ListShareCodec.decode('SC2:${'A' * 50000}'), isNull);

      final bomb = ZLibCodec(raw: true).encode(List<int>.filled(5000000, 0));
      expect(ListShareCodec.decode('SC2:${base64Url.encode(bomb).replaceAll('=', '')}'), isNull);
    });
  });
}

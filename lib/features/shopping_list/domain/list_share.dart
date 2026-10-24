import 'dart:convert';
import 'dart:io' show GZipCodec;

/// Un renglón de una lista que se envía o se recibe como copia (sin avance del carrito).
class SharedItem {
  const SharedItem({
    required this.name,
    this.brand,
    this.quantityLabel,
    this.barcode,
    this.imageUrl,
    this.desiredQty = 1,
  });

  final String name;
  final String? brand;
  final String? quantityLabel;
  final String? barcode;

  /// Solo fotos de Open Food Facts: las fotos propias están en el teléfono de quien envía.
  final String? imageUrl;
  final int desiredQty;
}

/// Una copia de una lista: lo que viaja en el mensaje.
class SharedList {
  const SharedList({required this.name, required this.items, this.sourceId});

  /// Id de la lista de quien la envió. Sirve para reconocer que ya se importó antes.
  final String? sourceId;
  final String name;
  final List<SharedItem> items;
}

/// Convierte una lista en un texto corto con un código `SC1:...` y al revés.
///
/// El código es el JSON de la lista comprimido (gzip) y en base64 seguro para URLs, así
/// cabe en un mensaje de WhatsApp. Todo lo que se lee es dato de un tercero: se limita
/// el tamaño y se limpia cada campo.
abstract final class ListShareCodec {
  static const prefix = 'SC1:';

  static const _maxCodeLength = 40000;
  static const _maxItems = 300;
  static final _codePattern = RegExp(r'SC1:([A-Za-z0-9_\-]+)');

  static String encode(SharedList list) {
    final json = jsonEncode({
      'v': 1,
      if (list.sourceId != null) 'l': list.sourceId,
      'n': list.name,
      'i': [
        for (final item in list.items)
          {
            'n': item.name,
            if (_has(item.brand)) 'b': item.brand,
            if (_has(item.quantityLabel)) 'q': item.quantityLabel,
            if (_has(item.barcode)) 'c': item.barcode,
            if (item.desiredQty != 1) 'd': item.desiredQty,
            if (_has(item.imageUrl)) 'm': item.imageUrl,
          },
      ],
    });
    final bytes = GZipCodec().encode(utf8.encode(json));
    return prefix + base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Busca un código `SC1:` en [text] (puede venir dentro de un mensaje entero) y lo
  /// lee. Devuelve `null` si no hay código o está dañado.
  static SharedList? decode(String text) {
    final match = _codePattern.firstMatch(text);
    if (match == null) return null;
    final code = match.group(1)!;
    if (code.length > _maxCodeLength) return null;

    try {
      final padded = code.padRight((code.length + 3) ~/ 4 * 4, '=');
      final json = jsonDecode(utf8.decode(GZipCodec().decode(base64Url.decode(padded))));
      if (json is! Map || json['v'] != 1) return null;

      final name = _clean(json['n'], 80);
      final rawItems = json['i'];
      if (name == null || rawItems is! List) return null;

      final items = <SharedItem>[];
      for (final raw in rawItems.take(_maxItems)) {
        if (raw is! Map) continue;
        final itemName = _clean(raw['n'], 120);
        if (itemName == null) continue;
        final qty = raw['d'];
        items.add(
          SharedItem(
            name: itemName,
            brand: _clean(raw['b'], 80),
            quantityLabel: _clean(raw['q'], 40),
            barcode: _barcode(raw['c']),
            imageUrl: _imageUrl(raw['m']),
            desiredQty: qty is int ? qty.clamp(1, 999).toInt() : 1,
          ),
        );
      }
      return SharedList(
        sourceId: _clean(json['l'], 80),
        name: name,
        items: items,
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    } on Exception {
      return null; // gzip dañado
    }
  }

  /// El mensaje que se envía: la lista en texto (se lee sin la app) y, abajo, el código.
  static String toMessage(SharedList list) {
    final count = list.items.length;
    final buffer = StringBuffer('🛒 ${list.name} · ')
      ..writeln(count == 1 ? '1 producto' : '$count productos');
    for (final item in list.items) {
      buffer.write('• ${item.name}');
      if (item.desiredQty > 1) buffer.write(' ×${item.desiredQty}');
      final detail = [item.brand, item.quantityLabel].where(_has).join(' · ');
      if (detail.isNotEmpty) buffer.write(' ($detail)');
      buffer.writeln();
    }
    buffer
      ..writeln()
      ..writeln('Para abrirla en SuperCheck: copiá este mensaje, entrá a Mis listas, '
          'tocá el ícono de importar y pegalo.')
      ..write(encode(list));
    return buffer.toString();
  }

  static bool _has(String? v) => v != null && v.trim().isNotEmpty;

  static String? _clean(Object? v, int max) {
    if (v is! String) return null;
    final text = v.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return null;
    return text.length > max ? text.substring(0, max) : text;
  }

  static String? _barcode(Object? v) {
    if (v is! String) return null;
    final digits = v.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 8 && digits.length <= 14 ? digits : null;
  }

  /// Solo fotos de Open Food Facts: una dirección cualquiera haría que el teléfono de
  /// quien importa visite un sitio elegido por otra persona.
  static String? _imageUrl(Object? v) {
    if (v is! String || v.length > 300) return null;
    final uri = Uri.tryParse(v);
    if (uri == null || uri.scheme != 'https') return null;
    final host = uri.host;
    final ok = host == 'openfoodfacts.org' || host.endsWith('.openfoodfacts.org');
    return ok ? v : null;
  }
}

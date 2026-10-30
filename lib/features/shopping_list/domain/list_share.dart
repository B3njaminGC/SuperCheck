import 'dart:convert';
import 'dart:io' show GZipCodec, ZLibCodec;
import 'dart:typed_data' show BytesBuilder;

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

/// Convierte una lista en un texto con un código `SC2:...` y al revés.
///
/// El código es un formato binario compacto (textos con su largo, el código de barras en
/// 7 bytes y la foto de Open Food Facts reconstruida a partir del propio código), comprimido
/// y en base64 seguro para URLs. Ocupa ~40 % menos que el `SC1:` anterior, que también se
/// sigue pudiendo leer. Todo lo que se lee es dato de un tercero: se limita el tamaño y se
/// limpia cada campo.
abstract final class ListShareCodec {
  static const prefix = 'SC2:';

  static const _maxCodeLength = 40000;
  static const _maxInflated = 200000;
  static const _maxItems = 300;
  static final _codePattern = RegExp(r'SC([12]):([A-Za-z0-9_\-]+)');

  static const _offImages = 'https://images.openfoodfacts.org/images/products/';
  static final _offPhotoFile = RegExp(r'^front_([a-z]{2})\.([1-9]\d{0,5})\.([1-9]\d{0,3})\.jpg$');

  static String encode(SharedList list) {
    final out = BytesBuilder();
    final hasSource = _has(list.sourceId);
    out
      ..addByte(2)
      ..addByte(hasSource ? 1 : 0);
    if (hasSource) _putString(out, list.sourceId!);
    _putString(out, list.name);
    _putVarint(out, list.items.length);

    for (final item in list.items) {
      final barcode = _barcode(item.barcode);
      final image = item.imageUrl?.trim() ?? '';
      final qty = item.desiredQty.clamp(1, 999).toInt();

      // 1 = foto estándar de Open Food Facts (se reconstruye), 2 = dirección completa.
      var photoMode = 0;
      String? lang, rev, size;
      if (image.isNotEmpty) {
        photoMode = 2;
        if (barcode != null && image.startsWith('$_offImages${_offFolder(barcode)}/')) {
          final file = image.substring('$_offImages${_offFolder(barcode)}/'.length);
          final m = _offPhotoFile.firstMatch(file);
          if (m != null) {
            photoMode = 1;
            lang = m.group(1);
            rev = m.group(2);
            size = m.group(3);
          }
        }
      }

      var flags = 0;
      if (_has(item.brand)) flags |= 1;
      if (_has(item.quantityLabel)) flags |= 2;
      if (barcode != null) flags |= 4;
      if (qty != 1) flags |= 8;
      flags |= photoMode << 4;

      out.addByte(flags);
      _putString(out, item.name);
      if (flags & 1 != 0) _putString(out, item.brand!);
      if (flags & 2 != 0) _putString(out, item.quantityLabel!);
      if (barcode != null) {
        out.addByte(barcode.length);
        var value = int.parse(barcode);
        final bytes = List<int>.filled(6, 0);
        for (var i = 5; i >= 0; i--) {
          bytes[i] = value & 0xff;
          value >>= 8;
        }
        out.add(bytes);
      }
      if (qty != 1) _putVarint(out, qty);
      if (photoMode == 1) {
        out.add(lang!.codeUnits);
        _putVarint(out, int.parse(rev!));
        _putVarint(out, int.parse(size!));
      } else if (photoMode == 2) {
        _putString(out, image);
      }
    }

    final packed = ZLibCodec(level: 9, raw: true).encode(out.takeBytes());
    return prefix + base64Url.encode(packed).replaceAll('=', '');
  }

  /// Busca un código `SC1:` o `SC2:` en [text] (puede venir dentro de un mensaje entero) y
  /// lo lee. Devuelve `null` si no hay código o está dañado.
  static SharedList? decode(String text) {
    final match = _codePattern.firstMatch(text);
    if (match == null) return null;
    final code = match.group(2)!;
    if (code.length > _maxCodeLength) return null;

    try {
      final padded = code.padRight((code.length + 3) ~/ 4 * 4, '=');
      final raw = base64Url.decode(padded);
      return match.group(1) == '2' ? _decodeV2(raw) : _decodeV1(raw);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    } on Exception {
      return null; // datos comprimidos dañados
    }
  }

  static SharedList? _decodeV2(List<int> raw) {
    final r = _Reader(_inflate(ZLibCodec(raw: true).decoder, raw));
    if (r.byte() != 2) return null;
    final header = r.byte();
    final sourceId = header & 1 != 0 ? _clean(r.string(400), 80) : null;
    final name = _clean(r.string(2000), 80);
    final count = r.varint();
    if (name == null || count > 100000) return null;

    final items = <SharedItem>[];
    for (var i = 0; i < count && i < _maxItems; i++) {
      final flags = r.byte();
      final itemName = _clean(r.string(2000), 120);
      final brand = flags & 1 != 0 ? _clean(r.string(2000), 80) : null;
      final quantity = flags & 2 != 0 ? _clean(r.string(2000), 40) : null;
      String? barcode;
      if (flags & 4 != 0) {
        final digits = r.byte();
        final value = r.bigEndian6();
        if (digits < 8 || digits > 14) throw const FormatException('código de barras');
        barcode = value.toString().padLeft(digits, '0');
        if (barcode.length != digits) throw const FormatException('código de barras');
      }
      final qty = flags & 8 != 0 ? r.varint().clamp(1, 999).toInt() : 1;

      String? image;
      switch (flags >> 4) {
        case 0:
          break;
        case 1:
          if (barcode == null) throw const FormatException('foto sin código');
          final lang = String.fromCharCodes([r.byte(), r.byte()]);
          final rev = r.varint();
          final size = r.varint();
          if (!RegExp(r'^[a-z]{2}$').hasMatch(lang)) throw const FormatException('foto');
          image = _imageUrl('$_offImages${_offFolder(barcode)}/front_$lang.$rev.$size.jpg');
        case 2:
          image = _imageUrl(r.string(600));
        default:
          throw const FormatException('foto');
      }

      if (itemName == null) continue;
      items.add(
        SharedItem(
          name: itemName,
          brand: brand,
          quantityLabel: quantity,
          barcode: barcode,
          imageUrl: image,
          desiredQty: qty,
        ),
      );
    }
    return SharedList(sourceId: sourceId, name: name, items: items);
  }

  /// Formato anterior (JSON comprimido con gzip). Se sigue aceptando para los mensajes
  /// que ya se habían enviado.
  static SharedList? _decodeV1(List<int> raw) {
    final json = jsonDecode(utf8.decode(_inflate(GZipCodec().decoder, raw)));
    if (json is! Map || json['v'] != 1) return null;

    final name = _clean(json['n'], 80);
    final rawItems = json['i'];
    if (name == null || rawItems is! List) return null;

    final items = <SharedItem>[];
    for (final item in rawItems.take(_maxItems)) {
      if (item is! Map) continue;
      final itemName = _clean(item['n'], 120);
      if (itemName == null) continue;
      final qty = item['d'];
      items.add(
        SharedItem(
          name: itemName,
          brand: _clean(item['b'], 80),
          quantityLabel: _clean(item['q'], 40),
          barcode: _barcode(item['c']),
          imageUrl: _imageUrl(item['m']),
          desiredQty: qty is int ? qty.clamp(1, 999).toInt() : 1,
        ),
      );
    }
    return SharedList(sourceId: _clean(json['l'], 80), name: name, items: items);
  }

  /// Descomprime cortando si el resultado es desproporcionado (un código malicioso podría
  /// expandirse a cientos de MB).
  static List<int> _inflate(Converter<List<int>, List<int>> decoder, List<int> input) {
    final sink = _LimitedSink(_maxInflated);
    final conversion = decoder.startChunkedConversion(sink);
    conversion
      ..add(input)
      ..close();
    return sink.bytes;
  }

  /// Carpeta de las fotos de Open Food Facts para un código (`779/000/100/0011`).
  static String _offFolder(String barcode) {
    if (barcode.length <= 8) return barcode;
    final padded = barcode.padLeft(13, '0');
    return '${padded.substring(0, 3)}/${padded.substring(3, 6)}/'
        '${padded.substring(6, 9)}/${padded.substring(9)}';
  }

  static void _putVarint(BytesBuilder out, int value) {
    var v = value;
    while (v >= 0x80) {
      out.addByte((v & 0x7f) | 0x80);
      v >>= 7;
    }
    out.addByte(v);
  }

  static void _putString(BytesBuilder out, String value) {
    final bytes = utf8.encode(value);
    _putVarint(out, bytes.length);
    out.add(bytes);
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

/// Lee los bytes del formato `SC2:`. Cualquier dato que falte o sobre es un
/// [FormatException], que el decodificador convierte en "código dañado".
class _Reader {
  _Reader(this._bytes);

  final List<int> _bytes;
  int _pos = 0;

  int byte() {
    if (_pos >= _bytes.length) throw const FormatException('fin inesperado');
    return _bytes[_pos++];
  }

  int varint() {
    var result = 0;
    var shift = 0;
    while (true) {
      final b = byte();
      result |= (b & 0x7f) << shift;
      if (b < 0x80) return result;
      shift += 7;
      if (shift > 28) throw const FormatException('número demasiado grande');
    }
  }

  int bigEndian6() {
    var value = 0;
    for (var i = 0; i < 6; i++) {
      value = (value << 8) | byte();
    }
    return value;
  }

  String string(int maxBytes) {
    final length = varint();
    if (length > maxBytes || _pos + length > _bytes.length) {
      throw const FormatException('texto inválido');
    }
    final text = utf8.decode(_bytes.sublist(_pos, _pos + length));
    _pos += length;
    return text;
  }
}

class _LimitedSink implements Sink<List<int>> {
  _LimitedSink(this._max);

  final int _max;
  final _builder = BytesBuilder();
  int _total = 0;

  List<int> get bytes => _builder.takeBytes();

  @override
  void add(List<int> data) {
    _total += data.length;
    if (_total > _max) throw const FormatException('datos demasiado grandes');
    _builder.add(data);
  }

  @override
  void close() {}
}

import 'package:equatable/equatable.dart';

enum QuantityUnit {
  gram('g'),
  milliliter('ml');

  const QuantityUnit(this.symbol);

  final String symbol;

  static QuantityUnit? fromSymbol(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'g':
        return QuantityUnit.gram;
      case 'ml':
        return QuantityUnit.milliliter;
      default:
        return null;
    }
  }
}

/// Contenido neto normalizado a gramos o mililitros.
///
/// Es la base para comparar el paquete escaneado con el buscado
/// (ej. 500 g buscado vs 250 g escaneado -> sugerir 2 unidades).
class NetQuantity extends Equatable {
  const NetQuantity(this.value, this.unit);

  final double value;
  final QuantityUnit unit;

  static const _unitPattern =
      r'kilos?|kgs?|gramos?|grs?|g|mg|litros?|lts?|l|ml|cl|dl';

  // "6 x 330 ml", "2x100g"
  static final _multiPack = RegExp(
    r'(\d+)\s*[x×*]\s*(\d+(?:[.,]\d+)*)\s*(' + _unitPattern + r')(?![a-z])',
    caseSensitive: false,
  );

  // "300 g", "1,5 kg", "500ml", "1 L"
  static final _single = RegExp(
    r'(\d+(?:[.,]\d+)*)\s*(' + _unitPattern + r')(?![a-z])',
    caseSensitive: false,
  );

  /// Interpreta textos como "300 g", "1,5 kg", "1 L" o "6 x 330 ml".
  /// Devuelve `null` si no puede (ej. "12 unidades", "1 oz").
  static NetQuantity? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    final multi = _multiPack.firstMatch(raw);
    if (multi != null) {
      final count = double.tryParse(multi.group(1)!);
      final each = _fromParts(multi.group(2)!, multi.group(3)!);
      if (count != null && each != null) {
        return NetQuantity(each.value * count, each.unit);
      }
    }

    final single = _single.firstMatch(raw);
    if (single != null) {
      return _fromParts(single.group(1)!, single.group(2)!);
    }
    return null;
  }

  static NetQuantity? _fromParts(String numberRaw, String unitRaw) {
    final number = _parseNumber(numberRaw);
    if (number == null || number <= 0) return null;

    switch (unitRaw.toLowerCase()) {
      case 'kg':
      case 'kgs':
      case 'kilo':
      case 'kilos':
        return NetQuantity(number * 1000, QuantityUnit.gram);
      case 'mg':
        return NetQuantity(number / 1000, QuantityUnit.gram);
      case 'g':
      case 'gr':
      case 'grs':
      case 'gramo':
      case 'gramos':
        return NetQuantity(number, QuantityUnit.gram);
      case 'l':
      case 'lt':
      case 'lts':
      case 'litro':
      case 'litros':
        return NetQuantity(number * 1000, QuantityUnit.milliliter);
      case 'dl':
        return NetQuantity(number * 100, QuantityUnit.milliliter);
      case 'cl':
        return NetQuantity(number * 10, QuantityUnit.milliliter);
      case 'ml':
        return NetQuantity(number, QuantityUnit.milliliter);
    }
    return null;
  }

  /// "1.000" / "1.000.000" -> separador de miles (formato es-AR).
  /// "1,5" / "1.5"         -> decimal.
  /// Ambiguo por naturaleza: "1.500 kg" se interpreta como 1500 kg.
  static double? _parseNumber(String s) {
    if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
      return double.tryParse(s.replaceAll('.', ''));
    }
    return double.tryParse(s.replaceAll(',', '.'));
  }

  bool sameUnitAs(NetQuantity other) => unit == other.unit;

  /// Cuántas veces entra [other] en este contenido (solo si comparten unidad).
  /// `NetQuantity(500, g).ratioTo(NetQuantity(250, g)) == 2.0`
  double? ratioTo(NetQuantity other) {
    if (!sameUnitAs(other) || other.value == 0) return null;
    return value / other.value;
  }

  /// "300 g", "1,5 kg", "330 ml", "1,98 L"
  String toDisplayString() {
    final v = value;
    if (v >= 1000) {
      final big = unit == QuantityUnit.gram ? 'kg' : 'L';
      return '${_format(v / 1000)} $big';
    }
    return '${_format(v)} ${unit.symbol}';
  }

  static String _format(double n) {
    if (n == n.roundToDouble()) return n.toStringAsFixed(0);
    final fixed = n.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    return fixed.replaceFirst(RegExp(r'\.$'), '').replaceAll('.', ',');
  }

  @override
  List<Object?> get props => [value, unit];
}

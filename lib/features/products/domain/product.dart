import 'package:equatable/equatable.dart';

import 'net_quantity.dart';

/// Producto del catálogo (Open Food Facts), listo para agregar a una lista.
class Product extends Equatable {
  const Product({
    required this.barcode,
    required this.name,
    this.brand,
    this.quantityLabel,
    this.netQuantity,
    this.imageUrl,
    this.libraryId,
  });

  /// Código de barras. Vacío en los productos propios que no tienen código.
  final String barcode;
  final String name;
  final String? brand;

  /// Texto original de OFF, ej. "300 g".
  final String? quantityLabel;

  /// Contenido neto normalizado a g/ml, si se pudo interpretar.
  final NetQuantity? netQuantity;
  /// Dirección de internet (Open Food Facts) o ruta de una foto guardada en el teléfono.
  final String? imageUrl;

  /// Si no es null, es un producto creado por la persona ("Mis productos").
  final String? libraryId;

  bool get isMine => libraryId != null;
  bool get hasBarcode => barcode.isNotEmpty;

  /// "Criollitas · 300 g" (o solo lo que haya).
  String get subtitle {
    final size = netQuantity?.toDisplayString() ?? quantityLabel;
    return [brand, size].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
  }

  /// Convierte un producto de Open Food Facts.
  /// Devuelve `null` si falta el código de barras o el nombre (no sirve para la lista).
  static Product? tryFromOffJson(Map<String, dynamic> json) {
    final barcode = _string(json['code']);
    final name = _firstNonEmpty([
      _string(json['product_name_es']),
      _string(json['product_name']),
      _string(json['generic_name']),
    ]);
    if (barcode == null || name == null) return null;

    final quantityLabel = _string(json['quantity']);

    // Preferimos el texto ("300 g") porque trae la unidad. `product_quantity` es
    // un número normalizado que no siempre indica si son gramos o mililitros.
    var net = NetQuantity.tryParse(quantityLabel);
    if (net == null) {
      final value = _double(json['product_quantity']);
      final unit = QuantityUnit.fromSymbol(_string(json['product_quantity_unit']));
      if (value != null && value > 0 && unit != null) {
        net = NetQuantity(value, unit);
      }
    }

    return Product(
      barcode: barcode,
      name: name,
      brand: _firstBrand(_string(json['brands'])),
      quantityLabel: quantityLabel,
      netQuantity: net,
      imageUrl: _firstNonEmpty([
        // La más grande primero: en tarjetas la chica se ve borrosa.
        _string(json['image_front_url']),
        _string(json['image_front_small_url']),
        _string(json['image_url']),
        _string(json['image_small_url']),
      ]),
    );
  }

  static String? _string(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static double? _double(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  /// OFF devuelve marcas separadas por coma: "Criollitas,Mondelez".
  static String? _firstBrand(String? brands) {
    if (brands == null) return null;
    final first = brands.split(',').first.trim();
    return first.isEmpty ? null : first;
  }

  @override
  List<Object?> get props =>
      [barcode, name, brand, quantityLabel, netQuantity, imageUrl, libraryId];
}

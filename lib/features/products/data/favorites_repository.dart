import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/net_quantity.dart';
import '../domain/product.dart';

/// Productos marcados como favoritos, guardados en el teléfono. Se guarda una copia
/// de los datos (nombre, marca, tamaño, foto) para mostrarlos sin conexión.
class FavoritesRepository {
  FavoritesRepository(this._prefs);

  static const storageKey = 'favorite_products_v1';

  final SharedPreferences _prefs;

  List<Product> load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final products = <Product>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        final product = _fromJson(entry.cast<String, dynamic>());
        if (product != null) products.add(product);
      }
      return products;
    } on FormatException {
      return const [];
    }
  }

  Future<void> save(List<Product> products) {
    return _prefs.setString(
      storageKey,
      jsonEncode([for (final p in products) _toJson(p)]),
    );
  }

  static Map<String, dynamic> _toJson(Product p) => {
        'id': p.libraryId,
        'name': p.name,
        'brand': p.brand,
        'quantityLabel': p.quantityLabel,
        'barcode': p.barcode,
        'image': p.imageUrl,
      };

  static Product? _fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) return null;
    final id = json['id'];
    final barcode = (json['barcode'] as String?) ?? '';
    if ((id is! String || id.isEmpty) && barcode.isEmpty) return null;
    final quantityLabel = json['quantityLabel'] as String?;
    return Product(
      libraryId: id is String && id.isNotEmpty ? id : null,
      name: name,
      brand: json['brand'] as String?,
      quantityLabel: quantityLabel,
      netQuantity: NetQuantity.tryParse(quantityLabel),
      barcode: barcode,
      imageUrl: json['image'] as String?,
    );
  }
}

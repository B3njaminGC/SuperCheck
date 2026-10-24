import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/net_quantity.dart';
import '../domain/product.dart';

/// "Mis productos": los que la persona creó (no están en Open Food Facts o quiere una
/// foto propia). Se guardan en el teléfono, en formato JSON, igual que las listas.
class MyProductsRepository {
  MyProductsRepository(this._prefs);

  static const storageKey = 'my_products_v1';

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
        'imagePath': p.imageUrl,
      };

  static Product? _fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty || name is! String || name.trim().isEmpty) {
      return null;
    }
    final quantityLabel = json['quantityLabel'] as String?;
    return Product(
      libraryId: id,
      name: name,
      brand: json['brand'] as String?,
      quantityLabel: quantityLabel,
      netQuantity: NetQuantity.tryParse(quantityLabel),
      barcode: (json['barcode'] as String?) ?? '',
      imageUrl: json['imagePath'] as String?,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/mode/app_mode.dart';
import '../../../core/utils/barcode_utils.dart';
import '../data/my_products_repository.dart';
import '../data/product_photo_picker.dart';
import '../domain/net_quantity.dart';
import '../domain/product.dart';

final productPhotoPickerProvider =
    Provider<ProductPhotoPicker>((ref) => DevicePhotoPicker());

final myProductsProvider =
    NotifierProvider<MyProductsController, List<Product>>(MyProductsController.new);

/// Productos creados por la persona, ordenados por nombre.
class MyProductsController extends Notifier<List<Product>> {
  late final MyProductsRepository _repo =
      MyProductsRepository(ref.read(sharedPreferencesProvider));

  @override
  List<Product> build() => _sorted(_repo.load());

  static List<Product> _sorted(List<Product> products) {
    final copy = [...products];
    copy.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return copy;
  }

  /// El producto propio con ese código de barras, si existe.
  Product? findByBarcode(String barcode) {
    return state.where((p) => BarcodeUtils.isSame(p.barcode, barcode)).firstOrNull;
  }

  /// Crea un producto (o, con [id], actualiza el existente) y lo devuelve.
  Future<Product> save({
    String? id,
    required String name,
    String? brand,
    String? quantityLabel,
    String? barcode,
    String? imagePath,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const AppException('Escribí el nombre del producto.');
    }
    final digits = (barcode ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isNotEmpty && digits.length < 8) {
      throw const AppException(
        'El código de barras tiene que tener al menos 8 números.',
      );
    }
    if (digits.isNotEmpty) {
      final clash = findByBarcode(digits);
      if (clash != null && clash.libraryId != id) {
        throw AppException('Ya tenés "${clash.name}" con ese código de barras.');
      }
    }

    String? clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    final label = clean(quantityLabel);

    final product = Product(
      libraryId: id ?? DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: cleanName,
      brand: clean(brand),
      quantityLabel: label,
      netQuantity: NetQuantity.tryParse(label),
      barcode: digits,
      imageUrl: clean(imagePath),
    );

    final next = [
      for (final p in state)
        if (p.libraryId != product.libraryId) p,
      product,
    ];
    await _repo.save(next);
    state = _sorted(next);
    return product;
  }

  Future<void> remove(String id) async {
    final next = [
      for (final p in state)
        if (p.libraryId != id) p,
    ];
    await _repo.save(next);
    state = next;
  }

  /// Productos propios que contienen todas las palabras de [query]
  /// (sin importar mayúsculas ni tildes), buscando en nombre, marca y tamaño.
  List<Product> search(String query) {
    final words = _fold(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    return [
      for (final p in state)
        if (_matchesAll(words, _fold('${p.name} ${p.brand ?? ''} ${p.quantityLabel ?? ''}')))
          p,
    ];
  }

  static bool _matchesAll(List<String> words, String haystack) =>
      words.every(haystack.contains);

  static String _fold(String text) {
    const from = 'áàäâéèëêíìïîóòöôúùüûñ';
    const to = 'aaaaeeeeiiiioooouuuun';
    final lower = text.toLowerCase();
    final out = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      final i = from.indexOf(ch);
      out.write(i >= 0 ? to[i] : ch);
    }
    return out.toString();
  }
}

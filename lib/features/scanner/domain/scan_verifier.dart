import '../../products/domain/product.dart';
import '../../shopping_list/domain/shopping_item.dart';
import 'product_matcher.dart';
import 'scan_result.dart';
import 'size_advice.dart';

/// Lógica pura del verificador de góndola (sin red ni UI, fácil de testear).
///
/// Orden de decisión:
/// 1. Código idéntico a un ítem de la lista        -> [ScanExactMatch]
/// 2. Mismo producto (marca + tipo), otro tamaño   -> [ScanSizeDifference]
/// 3. Producto conocido que no está en la lista    -> [ScanNotInList]
/// 4. Código que Open Food Facts no conoce         -> [ScanUnknownBarcode]
abstract final class ScanVerifier {
  /// Paso 1, que se puede resolver sin red: si hay varios ítems con ese código,
  /// prefiere uno pendiente.
  static ScanExactMatch? findExact(String barcode, Iterable<ShoppingItem> items) {
    final matches = items.where((i) => i.matchesBarcode(barcode)).toList();
    if (matches.isEmpty) return null;

    final pending = matches.where((i) => !i.isChecked).firstOrNull;
    return pending != null
        ? ScanExactMatch(pending)
        : ScanExactMatch(matches.first, alreadyChecked: true);
  }

  /// [scannedProduct] es lo que devolvió Open Food Facts para ese código
  /// (`null` si no lo conoce).
  static ScanResult verify({
    required String barcode,
    required Iterable<ShoppingItem> items,
    Product? scannedProduct,
  }) {
    final exact = findExact(barcode, items);
    if (exact != null) return exact;

    if (scannedProduct == null) return ScanUnknownBarcode(barcode);

    final sameFamily = _bestFamilyMatch(items, scannedProduct);
    if (sameFamily != null) {
      return ScanSizeDifference(
        item: sameFamily,
        scanned: scannedProduct,
        advice: SizeAdvice.compute(item: sameFamily, scanned: scannedProduct),
      );
    }
    return ScanNotInList(scannedProduct);
  }

  /// Entre los ítems pendientes, el más parecido al producto escaneado.
  static ShoppingItem? _bestFamilyMatch(
    Iterable<ShoppingItem> items,
    Product scanned,
  ) {
    ShoppingItem? best;
    var bestScore = 0.0;

    for (final item in items) {
      if (item.isChecked) continue;
      final score = ProductMatcher.familyScore(
        nameA: item.name,
        brandA: item.brand,
        nameB: scanned.name,
        brandB: scanned.brand,
      );
      if (score != null && score > bestScore) {
        best = item;
        bestScore = score;
      }
    }
    return best;
  }
}

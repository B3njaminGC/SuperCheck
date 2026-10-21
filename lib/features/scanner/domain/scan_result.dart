import '../../products/domain/product.dart';
import '../../shopping_list/domain/shopping_item.dart';
import 'size_advice.dart';

/// Qué pasó al escanear un producto en la góndola.
sealed class ScanResult {
  const ScanResult();
}

/// El código coincide con un ítem de la lista: es el producto correcto.
class ScanExactMatch extends ScanResult {
  const ScanExactMatch(this.item, {this.alreadyChecked = false});

  final ShoppingItem item;

  /// Ya estaba tachado antes de escanear.
  final bool alreadyChecked;
}

/// Mismo producto (marca y tipo) pero con otro gramaje que el buscado.
class ScanSizeDifference extends ScanResult {
  const ScanSizeDifference({
    required this.item,
    required this.scanned,
    required this.advice,
  });

  final ShoppingItem item;
  final Product scanned;
  final SizeAdvice advice;
}

/// Producto conocido que no está en la lista.
class ScanNotInList extends ScanResult {
  const ScanNotInList(this.scanned);

  final Product scanned;
}

/// Open Food Facts no conoce el código y tampoco está en la lista.
class ScanUnknownBarcode extends ScanResult {
  const ScanUnknownBarcode(this.barcode);

  final String barcode;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/my_products_controller.dart';
import '../../products/presentation/product_providers.dart';
import '../../shopping_list/domain/shopping_item.dart';
import '../../shopping_list/presentation/shopping_list_controller.dart';
import '../domain/scan_result.dart';
import '../domain/scan_verifier.dart';

class ScanState {
  const ScanState({this.loading = false, this.result, this.error, this.barcode});

  final bool loading;
  final ScanResult? result;
  final String? error;

  /// Último código procesado (para reintentar).
  final String? barcode;

  /// Mientras se procesa, o haya un aviso que pide decidir algo, el escáner ignora
  /// nuevas lecturas. Un acierto exacto no frena: permite escanear 4 yogures seguidos.
  bool get isBusy =>
      loading || error != null || (result != null && result is! ScanExactMatch);
}

/// Estado del escáner de una lista (el argumento es el `listId`).
final scanControllerProvider = NotifierProvider.autoDispose
    .family<ScanController, ScanState, String>(ScanController.new);

class ScanController extends AutoDisposeFamilyNotifier<ScanState, String> {
  bool _disposed = false;

  @override
  ScanState build(String listId) {
    ref.onDispose(() => _disposed = true);
    return const ScanState();
  }

  // Evita escribir estado si se cerró la pantalla mientras esperaba la red.
  void _set(ScanState next) {
    if (!_disposed) state = next;
  }

  ShoppingListController get _list =>
      ref.read(shoppingListControllerProvider(arg).notifier);

  List<ShoppingItem> get _items =>
      ref.read(shoppingListControllerProvider(arg)).valueOrNull ?? const [];

  /// Procesa un código leído por la cámara.
  Future<void> onBarcode(String raw) async {
    if (state.isBusy) return;
    final code = raw.replaceAll(RegExp(r'\D'), '');
    if (code.isEmpty) return;

    _set(ScanState(loading: true, barcode: code));
    final items = _items;

    // 1) Coincidencia exacta: se resuelve sin red y tacha el ítem al instante.
    final exact = ScanVerifier.findExact(code, items);
    if (exact != null) {
      try {
        var item = exact.item;
        if (!exact.alreadyChecked) {
          // Cada lectura suma una unidad; el ítem se tacha al llegar a la cantidad pedida.
          item = await _list.pickOne(item.id) ?? item;
        }
        _set(
          ScanState(
            result: ScanExactMatch(item, alreadyChecked: exact.alreadyChecked),
            barcode: code,
          ),
        );
      } on AppException catch (e) {
        _set(ScanState(error: e.message, barcode: code));
      }
      return;
    }

    // 2) Si no está en la lista, se busca primero en "Mis productos" y después en
    //    Open Food Facts, y se compara.
    try {
      final product = ref.read(myProductsProvider.notifier).findByBarcode(code) ??
          await ref.read(productRepositoryProvider).getByBarcode(code);
      _set(
        ScanState(
          result: ScanVerifier.verify(
            barcode: code,
            items: items,
            scannedProduct: product,
          ),
          barcode: code,
        ),
      );
    } on AppException catch (e) {
      _set(ScanState(error: e.message, barcode: code));
    }
  }

  /// "Tachar igual": acepta el paquete escaneado para ese ítem.
  Future<void> checkItem(String itemId) async {
    final item = _items.where((i) => i.id == itemId).firstOrNull;
    try {
      if (item != null && !item.isChecked) await _list.toggleChecked(itemId);
      _set(const ScanState());
    } on AppException catch (e) {
      _set(ScanState(error: e.message, barcode: state.barcode));
    }
  }

  /// Agrega a la lista un producto que no estaba, ya tachado (lo tiene en la mano).
  Future<void> addScannedToList(Product product) async {
    try {
      await _list.addProduct(product, checked: true);
      _set(const ScanState());
    } on AppException catch (e) {
      _set(ScanState(error: e.message, barcode: state.barcode));
    }
  }

  Future<void> retry() async {
    final code = state.barcode;
    if (code == null) return;
    _set(const ScanState());
    await onBarcode(code);
  }

  void dismiss() => _set(const ScanState());
}

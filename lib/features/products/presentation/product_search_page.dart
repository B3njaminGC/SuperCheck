import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/widgets/product_thumb.dart';
import '../../../shared/widgets/snackbars.dart';
import '../../../shared/widgets/state_views.dart';
import '../../shopping_list/presentation/shopping_list_controller.dart';
import '../domain/product.dart';
import 'product_providers.dart';

/// Busca en Open Food Facts y agrega a la lista el producto exacto (marca + tamaño).
/// Lo que no tiene código de barras (verdura, pan) se agrega como texto libre.
class ProductSearchPage extends ConsumerStatefulWidget {
  const ProductSearchPage({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends ConsumerState<ProductSearchPage> {
  final _text = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  // Open Food Facts limita las búsquedas: se espera a que termine de escribir.
  void _onChanged(String value) {
    setState(() {}); // refresca el botón de borrar
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _searchNow(String value) {
    _debounce?.cancel();
    setState(() => _query = value.trim());
  }

  ShoppingListController get _list =>
      ref.read(shoppingListControllerProvider(widget.listId).notifier);

  Future<void> _add(Product product) async {
    try {
      await _list.addProduct(product);
      if (mounted) showMessage(context, '${product.name} agregado');
    } on AppException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  Future<void> _addCustom(String name) async {
    try {
      await _list.addCustomItem(name);
      if (mounted) showMessage(context, '"$name" agregado');
    } on AppException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _text,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Buscar producto (ej. galletitas de agua)',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
          onSubmitted: _searchNow,
        ),
        actions: [
          if (_text.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _debounce?.cancel();
                _text.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: _query.length < 2
          ? const EmptyView(
              icon: Icons.search,
              title: 'Buscá un producto',
              message: 'Escribí el nombre y elegí la marca y el tamaño exactos '
                  'que querés comprar. Si no tiene código de barras (verdura, '
                  'pan), escribilo y elegí "Agregar sin código".',
            )
          : Column(
              children: [
                // Siempre disponible, aunque falle la búsqueda en Open Food Facts.
                _CustomItemTile(text: _query, onAdd: () => _addCustom(_query)),
                const Divider(height: 1),
                Expanded(child: _results()),
              ],
            ),
    );
  }

  Widget _results() {
    final results = ref.watch(productSearchProvider(_query));
    final items =
        ref.watch(shoppingListControllerProvider(widget.listId)).valueOrNull ??
            const [];

    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: messageOf(e),
        onRetry: () => ref.invalidate(productSearchProvider(_query)),
      ),
      data: (products) {
        if (products.isEmpty) {
          return const EmptyView(
            icon: Icons.search_off,
            title: 'No encontré productos',
            message: 'Probá con otro nombre, con menos palabras, o agregalo '
                'sin código con la opción de arriba.',
          );
        }
        return ListView.separated(
          itemCount: products.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final product = products[i];
            final existing = items
                .where((it) => !it.isChecked && it.matchesBarcode(product.barcode))
                .firstOrNull;

            return ListTile(
              leading: ProductThumb(imageUrl: product.imageUrl, size: 52),
              title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                product.subtitle.isEmpty
                    ? 'Sin datos de marca ni tamaño'
                    : product.subtitle,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (existing != null)
                    Text(
                      '×${existing.desiredQty}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  IconButton(
                    icon: const Icon(Icons.add_circle),
                    tooltip: existing == null ? 'Agregar' : 'Sumar una unidad',
                    onPressed: () => _add(product),
                  ),
                ],
              ),
              onTap: () => _add(product),
            );
          },
        );
      },
    );
  }
}

class _CustomItemTile extends StatelessWidget {
  const _CustomItemTile({required this.text, required this.onAdd});

  final String text;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.edit_note)),
      title: Text('Agregar "$text" sin código'),
      subtitle: const Text('Para lo que no tiene código de barras'),
      trailing: const Icon(Icons.add_circle_outline),
      onTap: onAdd,
    );
  }
}

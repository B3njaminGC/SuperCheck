import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/barcode_utils.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/product_thumb.dart';
import '../../../shared/widgets/snackbars.dart';
import '../../../shared/widgets/state_views.dart';
import '../../shopping_list/domain/shopping_item.dart';
import '../../shopping_list/presentation/shopping_list_controller.dart';
import '../domain/product.dart';
import '../domain/product_text.dart';
import 'create_product_page.dart';
import 'favorites_controller.dart';
import 'my_products_controller.dart';
import 'product_providers.dart';

/// Busca en "Mis productos" y en Open Food Facts, y agrega a la lista el producto exacto
/// (marca + tamaño). Lo que no existe se puede crear con foto; lo que no tiene código de
/// barras (verdura, pan) se agrega como texto libre.
class ProductSearchPage extends ConsumerStatefulWidget {
  const ProductSearchPage({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends ConsumerState<ProductSearchPage> {
  final _text = TextEditingController();

  /// Último texto buscado. Open Food Facts limita las búsquedas, así que solo se
  /// consulta cuando la persona toca la lupa o "Buscar" en el teclado.
  String _query = '';

  /// Marca elegida para filtrar los resultados (null = todas).
  String? _brand;

  /// Estante que se muestra antes de buscar (null = el primero que tenga productos).
  _Shelf? _shelf;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _onChanged(String _) => setState(() {}); // refresca lupa, borrar y "sin código"

  void _searchNow([String? value]) {
    final text = (value ?? _text.text).trim();
    if (text.length < 2) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _query = text;
      _brand = null;
    });
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

  /// Abre el formulario para crear un producto y, al guardarlo, lo agrega a la lista.
  Future<void> _create(String name) async {
    final product = await Navigator.of(context).push<Product>(
      MaterialPageRoute(builder: (_) => CreateProductPage(initialName: name)),
    );
    if (product != null && mounted) await _add(product);
  }

  Future<void> _manage(Product product) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: const Text('Producto creado por vos'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Borrar de Mis productos'),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == 'edit') {
      await Navigator.of(context).push<Product>(
        MaterialPageRoute(builder: (_) => CreateProductPage(existing: product)),
      );
    } else {
      final ok = await showConfirmDialog(
        context,
        title: '¿Borrar "${product.name}"?',
        message: 'Se borra solo de Mis productos. Las listas donde ya está agregado '
            'no cambian.',
        confirmLabel: 'Borrar',
        destructive: true,
      );
      if (ok && mounted) {
        await ref.read(myProductsProvider.notifier).remove(product.libraryId!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final typed = _text.text.trim();
    final library = ref.watch(myProductsProvider);
    final favorites = ref.watch(favoriteProductsProvider);
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
              tooltip: 'Borrar',
              onPressed: () {
                _text.clear();
                setState(() {
                  _query = '';
                  _brand = null;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Buscar',
            onPressed: typed.length < 2 ? null : _searchNow,
          ),
        ],
      ),
      body: typed.length < 2 && _query.length < 2
          ? _idle(library, favorites)
          : Column(
              children: [
                // Siempre disponibles, aunque falle la búsqueda en Open Food Facts.
                if (typed.length >= 2) ...[
                  _CustomItemTile(text: typed, onAdd: () => _addCustom(typed)),
                  const Divider(height: 1),
                  _CreateProductTile(text: typed, onCreate: () => _create(typed)),
                  const Divider(height: 1),
                ],
                Expanded(
                  child: _query.length < 2 ? _beforeSearch(typed) : _results(),
                ),
              ],
            ),
    );
  }

  /// Antes de tocar la lupa: ya se muestran los productos propios que coinciden
  /// (no gastan consultas de internet).
  Widget _beforeSearch(String typed) {
    final mine = _localMatches(typed);
    if (mine.isEmpty) {
      return EmptyView(
        icon: Icons.search,
        title: 'Tocá la lupa para buscar',
        message: 'Busca "$typed" en Open Food Facts.',
      );
    }
    return _grid(
      _ranked(mine),
      header: const _SectionTitle('Tus productos y favoritos · tocá la lupa para '
          'buscar también en Open Food Facts'),
    );
  }

  Widget _results() {
    final off = ref.watch(productSearchProvider(_query));
    // Se observan también la biblioteca y los favoritos para que editar/borrar o
    // marcar se refleje al instante.
    ref.watch(myProductsProvider);
    ref.watch(favoriteProductsProvider);
    final mine = _localMatches(_query);

    return off.when(
      loading: () => mine.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _grid(
              _ranked(mine),
              header: const LinearProgressIndicator(minHeight: 2),
            ),
      error: (e, _) => mine.isEmpty
          ? ErrorView(
              message: messageOf(e),
              onRetry: () => ref.invalidate(productSearchProvider(_query)),
            )
          : _grid(
              _ranked(mine),
              header: _Notice(
                message: messageOf(e),
                onRetry: () => ref.invalidate(productSearchProvider(_query)),
              ),
            ),
      data: (found) {
        // Lo propio y los favoritos van primero, y si tienen el mismo código que uno de
        // Open Food Facts, manda el guardado (con su foto).
        final mineCodes = {
          for (final p in mine)
            if (p.hasBarcode) BarcodeUtils.normalize(p.barcode),
        };
        final products = [
          ...mine,
          for (final p in found)
            if (!mineCodes.contains(BarcodeUtils.normalize(p.barcode))) p,
        ];
        if (products.isEmpty) {
          return const EmptyView(
            icon: Icons.search_off,
            title: 'No encontré productos',
            message: 'Probá con otro nombre o con menos palabras. Si no existe, '
                'creá el producto con tu foto, o agregalo sin código con las '
                'opciones de arriba.',
          );
        }
        return _grid(_ranked(products));
      },
    );
  }

  /// Productos propios y favoritos que coinciden con [text] (sin gastar consultas).
  List<Product> _localMatches(String text) {
    final mine = ref.read(myProductsProvider.notifier).search(text);
    final favorites = [
      for (final p in ref.read(favoriteProductsProvider))
        if (!p.isMine && ProductText.matches(text, p)) p,
    ];
    return [...mine, ...favorites];
  }

  /// Orden de los resultados: favoritos, luego productos de una marca favorita, luego
  /// los propios y al final el resto. Dentro de cada grupo se respeta el orden original.
  List<Product> _ranked(List<Product> products) {
    final keys = ref.read(favoriteKeysProvider);
    final brands = ref.read(favoriteBrandsProvider);
    int rank(Product p) {
      if (keys.contains(p.favoriteKey)) return 0;
      final brand = p.brand?.trim().toLowerCase();
      if (brand != null && brands.contains(brand)) return 1;
      return p.isMine ? 2 : 3;
    }

    final indexed = [for (var i = 0; i < products.length; i++) (i, products[i])];
    indexed.sort((a, b) {
      final byRank = rank(a.$2).compareTo(rank(b.$2));
      return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  /// Antes de escribir: los favoritos y "Mis productos", para elegir de un toque.
  Widget _idle(List<Product> library, List<Product> favorites) {
    if (library.isEmpty && favorites.isEmpty) {
      return const EmptyView(
        icon: Icons.search,
        title: 'Buscá un producto',
        message: 'Escribí el nombre, tocá la lupa y elegí la marca y el '
            'tamaño exactos que querés comprar. Tocá la estrella de un producto '
            'para guardarlo en Favoritos. Si no existe, podés crearlo con tu '
            'propia foto; si no tiene código de barras (verdura, pan), elegí '
            '"Agregar sin código".',
      );
    }

    var shelf = _shelf ?? (favorites.isNotEmpty ? _Shelf.favorites : _Shelf.mine);
    if (shelf == _Shelf.favorites && favorites.isEmpty) shelf = _Shelf.mine;
    if (shelf == _Shelf.mine && library.isEmpty) shelf = _Shelf.favorites;

    final Widget header;
    if (favorites.isNotEmpty && library.isNotEmpty) {
      header = Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            ChoiceChip(
              avatar: const Icon(Icons.star, size: 18),
              label: const Text('Favoritos'),
              selected: shelf == _Shelf.favorites,
              onSelected: (_) => setState(() => _shelf = _Shelf.favorites),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Mis productos'),
              selected: shelf == _Shelf.mine,
              onSelected: (_) => setState(() => _shelf = _Shelf.mine),
            ),
          ],
        ),
      );
    } else {
      header = _SectionTitle(favorites.isNotEmpty ? 'Favoritos' : 'Mis productos');
    }
    return _grid(shelf == _Shelf.favorites ? favorites : library, header: header);
  }

  /// Tarjetas con el filtro por marca arriba. [header] se muestra sobre las tarjetas.
  Widget _grid(List<Product> products, {Widget? header}) {
    final items =
        ref.watch(shoppingListControllerProvider(widget.listId)).valueOrNull ??
            const <ShoppingItem>[];

    final counts = <String, int>{};
    for (final p in products) {
      final brand = p.brand;
      if (brand != null) counts[brand] = (counts[brand] ?? 0) + 1;
    }
    final favoriteKeys = ref.watch(favoriteKeysProvider);
    final favoriteBrands = ref.watch(favoriteBrandsProvider);
    bool isFavBrand(String brand) => favoriteBrands.contains(brand.trim().toLowerCase());
    final brands = counts.keys.toList()
      ..sort((a, b) {
        final byFav = (isFavBrand(b) ? 1 : 0).compareTo(isFavBrand(a) ? 1 : 0);
        if (byFav != 0) return byFav;
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    final active = counts.containsKey(_brand) ? _brand : null;
    final shown =
        active == null ? products : products.where((p) => p.brand == active).toList();

    return Column(
      children: [
        if (header != null) header,
        if (brands.length > 1)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('Todas (${products.length})'),
                    selected: active == null,
                    onSelected: (_) => setState(() => _brand = null),
                  ),
                ),
                for (final brand in brands)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${isFavBrand(brand) ? '★ ' : ''}$brand (${counts[brand]})'),
                      selected: active == brand,
                      onSelected: (_) => setState(() => _brand = brand),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.68,
            ),
            itemCount: shown.length,
            itemBuilder: (_, i) {
              final product = shown[i];
              return _ProductCard(
                product: product,
                quantityInList: _inList(items, product)?.desiredQty,
                onAdd: () => _add(product),
                isFavorite: favoriteKeys.contains(product.favoriteKey),
                onToggleFavorite: product.canBeFavorite
                    ? () => ref.read(favoritesProvider.notifier).toggle(product)
                    : null,
                onLongPress: product.isMine ? () => _manage(product) : null,
              );
            },
          ),
        ),
      ],
    );
  }

  /// El renglón pendiente de la lista que corresponde a este producto, si hay.
  static ShoppingItem? _inList(List<ShoppingItem> items, Product product) {
    for (final it in items) {
      if (it.isChecked) continue;
      if (product.hasBarcode) {
        if (it.matchesBarcode(product.barcode)) return it;
      } else if (it.barcode == null &&
          it.name.trim().toLowerCase() == product.name.trim().toLowerCase() &&
          (it.brand ?? '').trim().toLowerCase() ==
              (product.brand ?? '').trim().toLowerCase()) {
        return it;
      }
    }
    return null;
  }
}

enum _Shelf { favorites, mine }

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
  }
}

/// Aviso cuando falla Open Food Facts pero hay productos propios para mostrar.
class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.cloud_off),
      title: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: TextButton(onPressed: onRetry, child: const Text('Reintentar')),
    );
  }
}

/// Tarjeta de producto: imagen grande arriba para reconocer el envase de un vistazo.
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.quantityInList,
    required this.onAdd,
    required this.isFavorite,
    this.onToggleFavorite,
    this.onLongPress,
  });

  final Product product;
  final int? quantityInList;
  final VoidCallback onAdd;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle =
        product.subtitle.isEmpty ? 'Sin datos de marca ni tamaño' : product.subtitle;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onAdd,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LayoutBuilder(
                    builder: (_, c) => ProductThumb(
                      imageUrl: product.imageUrl,
                      size: c.maxWidth,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Tooltip(
                      message: quantityInList == null ? 'Agregar' : 'Sumar una unidad',
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        child: const Icon(Icons.add, size: 20),
                      ),
                    ),
                  ),
                  if (quantityInList != null)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Chip(
                        label: Text('×$quantityInList'),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (product.isMine)
                          Chip(
                            label: const Text('Mío'),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            backgroundColor: theme.colorScheme.tertiaryContainer,
                          ),
                        if (onToggleFavorite != null)
                          IconButton(
                            onPressed: onToggleFavorite,
                            tooltip:
                                isFavorite ? 'Quitar de favoritos' : 'Agregar a favoritos',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              isFavorite ? Icons.star : Icons.star_border,
                              color: isFavorite ? Colors.amber.shade700 : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateProductTile extends StatelessWidget {
  const _CreateProductTile({required this.text, required this.onCreate});

  final String text;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.add_a_photo_outlined)),
      title: Text('Crear producto "$text"'),
      subtitle: const Text('Con marca, tamaño y tu propia foto'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onCreate,
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

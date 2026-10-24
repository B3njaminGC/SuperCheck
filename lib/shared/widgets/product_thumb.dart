import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Miniatura de producto; si no hay imagen (o falla), muestra un ícono.
class ProductThumb extends StatelessWidget {
  const ProductThumb({
    super.key,
    this.imageUrl,
    this.size = 48,
    this.fit = BoxFit.cover,
  });

  final String? imageUrl;
  final double size;

  /// `BoxFit.contain` muestra el envase completo sobre fondo blanco (tarjetas grandes).
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: (url == null || url.isEmpty)
            ? _placeholder(context)
            : ColoredBox(
                color: Colors.white,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: fit,
                  width: size,
                  height: size,
                  placeholder: (_, __) => _placeholder(context),
                  errorWidget: (_, __, ___) => _placeholder(context),
                ),
              ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.shopping_basket_outlined,
        size: size * 0.5,
        color: scheme.outline,
      ),
    );
  }
}

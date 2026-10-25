import 'package:flutter/material.dart';

/// Logo de SuperCheck (carrito con tilde). La imagen se genera con
/// `tools/make_icons.py`.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon/logo.png',
      width: size,
      height: size,
      semanticLabel: 'Logo de SuperCheck',
      // Si faltara la imagen, no se rompe la pantalla.
      errorBuilder: (_, __, ___) => Icon(
        Icons.shopping_cart_checkout,
        size: size,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

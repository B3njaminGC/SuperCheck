import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../products/domain/product.dart';
import '../../products/presentation/create_product_page.dart';
import '../domain/scan_result.dart';
import 'scan_controller.dart';

/// Tarjeta con el resultado del último escaneo, sobre la cámara.
class ScanBanner extends ConsumerWidget {
  const ScanBanner({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scan = ref.watch(scanControllerProvider(listId));
    final controller = ref.read(scanControllerProvider(listId).notifier);

    final Widget? card;
    if (scan.loading) {
      card = const _LoadingCard(key: ValueKey('loading'));
    } else if (scan.error != null) {
      card = _BannerCard(
        key: const ValueKey('error'),
        color: Colors.red.shade700,
        icon: Icons.cloud_off,
        title: 'No pude verificar el producto',
        body: scan.error,
        actions: [
          _primary('Reintentar', controller.retry),
          _secondary('Cerrar', controller.dismiss),
        ],
      );
    } else {
      card = _forResult(context, scan.result, controller);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: card ?? const SizedBox.shrink(key: ValueKey('empty')),
    );
  }

  Widget? _forResult(
    BuildContext context,
    ScanResult? result,
    ScanController controller,
  ) {
    switch (result) {
      case null:
        return null;

      case ScanExactMatch(:final item, :final alreadyChecked):
        final partial = !alreadyChecked && !item.isChecked;
        final title = alreadyChecked
            ? 'Ya lo tenías completo'
            : partial
                ? 'Correcto: llevás ${item.pickedQty} de ${item.desiredQty}'
                : '¡Es el correcto!';
        return _BannerCard(
          key: ValueKey('exact-${item.id}-${item.pickedQty}'),
          color: Colors.green.shade700,
          icon: Icons.check_circle,
          title: title,
          body: [
            item.name,
            if (item.subtitle.isNotEmpty) item.subtitle,
            if (partial)
              'Escaneá ${item.remainingQty} más.'
            else if (!alreadyChecked && item.desiredQty > 1)
              'Ya tenés las ${item.desiredQty} unidades.',
          ].join('\n'),
        );

      case ScanSizeDifference(:final item, :final scanned, :final advice):
        return _BannerCard(
          key: ValueKey('size-${scanned.barcode}'),
          color: Colors.orange.shade800,
          icon: Icons.balance,
          title: 'Mismo producto, otro tamaño',
          body: 'Buscabas: ${_line(item.name, item.subtitle)}\n'
              'Escaneaste: ${_line(scanned.name, scanned.subtitle)}\n\n'
              '${advice.message}',
          actions: [
            _primary('Tachar igual', () => controller.checkItem(item.id)),
            _secondary('Seguir', controller.dismiss),
          ],
        );

      case ScanNotInList(:final scanned):
        return _BannerCard(
          key: ValueKey('new-${scanned.barcode}'),
          color: Colors.blueGrey.shade700,
          icon: Icons.info_outline,
          title: 'No está en tu lista',
          body: _line(scanned.name, scanned.subtitle),
          actions: [
            _primary('Agregar y tachar', () => controller.addScannedToList(scanned)),
            _secondary('Seguir', controller.dismiss),
          ],
        );

      case ScanUnknownBarcode(:final barcode):
        return _BannerCard(
          key: ValueKey('unknown-$barcode'),
          color: Colors.grey.shade800,
          icon: Icons.help_outline,
          title: 'No conozco este código',
          body: 'No encontré $barcode en Open Food Facts, ni en tu lista.\n'
              'Podés crearlo con tu foto y queda guardado en Mis productos.',
          actions: [
            _primary('Crear producto', () async {
              final created = await Navigator.of(context).push<Product>(
                MaterialPageRoute(
                  builder: (_) => CreateProductPage(initialBarcode: barcode),
                ),
              );
              // Lo tiene en la mano: se agrega a la lista ya tachado.
              if (created != null) await controller.addScannedToList(created);
            }),
            _secondary('Seguir', controller.dismiss),
          ],
        );
    }
  }

  static String _line(String name, String subtitle) {
    return subtitle.isEmpty ? name : '$name ($subtitle)';
  }

  static Widget _primary(String label, VoidCallback onPressed) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      child: Text(label),
    );
  }

  static Widget _secondary(String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: Colors.white),
      child: Text(label),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    this.body,
    this.actions = const [],
  });

  final Color color;
  final IconData icon;
  final String title;
  final String? body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: color,
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                style: textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(spacing: 8, children: actions),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 16),
            Text('Buscando producto…', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

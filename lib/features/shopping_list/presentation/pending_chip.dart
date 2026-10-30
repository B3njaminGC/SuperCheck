import 'package:flutter/material.dart';

/// Etiqueta "PENDIENTE" de una lista a la que le quedaron productos sin comprar.
class PendingChip extends StatelessWidget {
  const PendingChip({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'PENDIENTE',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onTertiaryContainer,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

/// El nombre de una lista con la etiqueta PENDIENTE al lado cuando corresponde.
class ListNameWithBadge extends StatelessWidget {
  const ListNameWithBadge({super.key, required this.name, required this.pending});

  final String name;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    if (!pending) return Text(name, overflow: TextOverflow.ellipsis);
    return Row(
      children: [
        Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        const PendingChip(),
      ],
    );
  }
}

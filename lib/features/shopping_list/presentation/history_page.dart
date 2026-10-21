import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/shopping_list.dart';
import 'list_flows.dart';
import 'lists_providers.dart';

/// Pestaña "Historial": listas finalizadas, listas para reutilizar con un toque.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key, required this.onOpen});

  final void Function(String listId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return history.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: messageOf(e),
        onRetry: () => ref.invalidate(historyProvider),
      ),
      data: (lists) {
        if (lists.isEmpty) {
          return const EmptyView(
            icon: Icons.history,
            title: 'Todavía no hay listas finalizadas',
            message: 'Cuando termines de comprar, finalizá la lista y quedará '
                'guardada acá para que puedas reutilizarla sin armarla de nuevo.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: lists.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _HistoryCard(list: lists[i], onOpen: onOpen),
        );
      },
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.list, required this.onOpen});

  final ShoppingList list;
  final void Function(String listId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final date = list.completedAt == null
        ? null
        : 'Finalizada el ${formatShortDate(list.completedAt!)}';
    final count = list.itemCount;
    final countText = count == null
        ? null
        : (count == 1 ? '1 producto' : '$count productos');
    final details = [date, countText].whereType<String>().join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(list.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(list.name, style: theme.textTheme.titleMedium),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  details,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    final newId = await promptAndReuse(context, ref, list);
                    if (newId != null) onOpen(newId);
                  },
                  icon: const Icon(Icons.replay),
                  label: const Text('Reutilizar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

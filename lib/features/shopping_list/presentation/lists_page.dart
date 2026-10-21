import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/widgets/state_views.dart';
import 'lists_providers.dart';

/// Pestaña "Listas": mis listas activas (propias y compartidas).
class ListsPage extends ConsumerWidget {
  const ListsPage({super.key, required this.onOpen});

  final void Function(String listId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(activeListsProvider);

    return lists.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: messageOf(e),
        onRetry: () => ref.invalidate(myListsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyView(
            icon: Icons.shopping_cart_outlined,
            title: 'Todavía no tenés listas',
            message: 'Creá una con el botón "Nueva lista", o unite a la de tu '
                'familia con el ícono de arriba y su código.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final list = items[i];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.list_alt)),
              title: Text(list.name),
              subtitle: Text('Creada el ${formatShortDate(list.createdAt)}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpen(list.id),
            );
          },
        );
      },
    );
  }
}

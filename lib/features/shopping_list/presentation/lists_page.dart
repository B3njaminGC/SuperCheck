import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/mode/app_mode.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/shopping_list.dart';
import 'list_flows.dart';
import 'lists_providers.dart';

/// Pestaña "Listas": mis listas activas (propias y compartidas).
class ListsPage extends ConsumerWidget {
  const ListsPage({super.key, required this.onOpen});

  final void Function(String listId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(activeListsProvider);
    final isLocal = ref.watch(appModeProvider) == AppMode.local;

    return lists.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: messageOf(e),
        onRetry: () => ref.invalidate(myListsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return EmptyView(
            icon: Icons.shopping_cart_outlined,
            title: 'Todavía no tenés listas',
            message: isLocal
                ? 'Creá una con el botón "Nueva lista". Se guarda en este '
                    'teléfono, y cuando termines de comprar la finalizás y '
                    'queda en el historial.'
                : 'Creá una con el botón "Nueva lista", o unite a la de tu '
                    'familia con el ícono de arriba y su código.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) => _ListTile(list: items[i], onOpen: onOpen),
        );
      },
    );
  }
}

class _ListTile extends ConsumerWidget {
  const _ListTile({required this.list, required this.onOpen});

  final ShoppingList list;
  final void Function(String listId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = list.ownerId == ref.watch(currentUserIdProvider);

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.list_alt)),
      title: Text(list.name),
      subtitle: Text('Creada el ${formatShortDate(list.createdAt)}'),
      trailing: PopupMenuButton<String>(
        tooltip: 'Más opciones de ${list.name}',
        onSelected: (value) {
          switch (value) {
            case 'delete':
              confirmAndDeleteList(context, ref, list);
            case 'leave':
              confirmAndLeaveList(context, ref, list);
          }
        },
        itemBuilder: (_) => [
          if (isOwner)
            const PopupMenuItem(value: 'delete', child: Text('Borrar lista'))
          else
            const PopupMenuItem(value: 'leave', child: Text('Salir de la lista')),
        ],
      ),
      onTap: () => onOpen(list.id),
    );
  }
}

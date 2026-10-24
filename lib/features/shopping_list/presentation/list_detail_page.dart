import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/mode/app_mode.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/widgets/product_thumb.dart';
import '../../../shared/widgets/snackbars.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/text_prompt_dialog.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../family/presentation/invite_code_dialog.dart';
import '../../family/presentation/members_sheet.dart';
import '../../products/presentation/product_search_page.dart';
import '../../scanner/presentation/scanner_page.dart';
import '../domain/shopping_item.dart';
import '../domain/shopping_list.dart';
import 'list_flows.dart';
import 'lists_providers.dart';
import 'shopping_list_controller.dart';

/// Detalle de una lista. Si está finalizada (historial) es de solo lectura y
/// ofrece reutilizarla o reabrirla.
class ListDetailPage extends ConsumerWidget {
  const ListDetailPage({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(listByIdProvider(listId));
    final itemsAsync = ref.watch(shoppingListControllerProvider(listId));

    // Mientras la lista no cargó se la trata como de solo lectura.
    final readOnly = list?.isCompleted ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Text(list?.name ?? 'Lista'),
        actions: list == null ? null : _actions(context, ref, list),
      ),
      body: itemsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: messageOf(e),
          onRetry: () => ref.invalidate(shoppingListControllerProvider(listId)),
        ),
        data: (items) => Column(
          children: [
            if (list != null && list.isCompleted) _CompletedBanner(list: list),
            if (items.isNotEmpty) _ProgressHeader(items: items),
            Expanded(
              child: items.isEmpty
                  ? EmptyView(
                      icon: Icons.add_shopping_cart,
                      title: 'La lista está vacía',
                      message: readOnly
                          ? null
                          : 'Agregá productos con el botón de abajo. Elegí la '
                              'marca y el tamaño exactos.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _ItemTile(
                        item: items[i],
                        listId: listId,
                        readOnly: readOnly,
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProductSearchPage(listId: listId),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Agregar producto'),
            ),
    );
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref, ShoppingList list) {
    final isOwner = list.ownerId == ref.read(currentUserIdProvider);
    // Invitar y ver miembros solo tiene sentido con cuenta (listas compartidas).
    final isLocal = ref.read(appModeProvider) == AppMode.local;

    if (list.isCompleted) {
      return [
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'reuse':
                _reuse(context, ref, list);
              case 'reopen':
                _reopen(context, ref);
              case 'share':
                shareListCopy(context, ref, list);
              case 'members':
                _members(context, ref, list);
              case 'delete':
                _delete(context, ref, list);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'reuse', child: Text('Reutilizar esta lista')),
            const PopupMenuItem(value: 'share', child: Text('Enviar copia de la lista')),
            const PopupMenuItem(value: 'reopen', child: Text('Reabrir lista')),
            if (!isLocal)
              const PopupMenuItem(value: 'members', child: Text('Miembros')),
            if (isOwner)
              const PopupMenuItem(value: 'delete', child: Text('Borrar lista')),
          ],
        ),
      ];
    }

    return [
      IconButton(
        icon: const Icon(Icons.qr_code_scanner),
        tooltip: 'Escanear producto',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ScannerPage(listId: listId)),
        ),
      ),
      PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'invite':
              showInviteCodeDialog(
                context,
                code: list.inviteCode,
                listName: list.name,
              );
            case 'share':
              shareListCopy(context, ref, list);
            case 'members':
              _members(context, ref, list);
            case 'rename':
              _rename(context, ref, list);
            case 'finish':
              _finish(context, ref);
            case 'delete':
              _delete(context, ref, list);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'share', child: Text('Enviar copia de la lista')),
          if (!isLocal)
            const PopupMenuItem(value: 'invite', child: Text('Invitar con código')),
          if (!isLocal)
            const PopupMenuItem(value: 'members', child: Text('Miembros')),
          if (isOwner)
            const PopupMenuItem(value: 'rename', child: Text('Renombrar lista')),
          const PopupMenuItem(value: 'finish', child: Text('Finalizar lista')),
          if (isOwner)
            const PopupMenuItem(value: 'delete', child: Text('Borrar lista')),
        ],
      ),
    ];
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    ShoppingList list,
  ) async {
    final name = await showTextPrompt(
      context,
      title: 'Renombrar lista',
      initialValue: list.name,
      confirmLabel: 'Guardar',
    );
    if (name == null || name == list.name || !context.mounted) return;

    try {
      await ref.read(listActionsProvider).rename(list.id, name);
    } on AppException catch (e) {
      if (context.mounted) showMessage(context, e.message);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ShoppingList list,
  ) async {
    final navigator = Navigator.of(context);
    final deleted = await confirmAndDeleteList(context, ref, list);
    if (deleted) navigator.popUntil((route) => route.isFirst);
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final items =
        ref.read(shoppingListControllerProvider(listId)).valueOrNull ?? const [];
    final pending = items.where((i) => !i.isChecked).length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar lista'),
        content: Text(
          [
            if (pending > 0)
              pending == 1
                  ? 'Queda 1 producto sin tachar.'
                  : 'Quedan $pending productos sin tachar.',
            'Se guardará en tu historial para que puedas reutilizarla '
                'cuando quieras.',
          ].join(' '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(listActionsProvider).complete(listId);
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Lista guardada en el historial')),
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Abre la hoja de miembros; si la persona salió de la lista, vuelve al inicio.
  Future<void> _members(
    BuildContext context,
    WidgetRef ref,
    ShoppingList list,
  ) async {
    final isOwner = list.ownerId == ref.read(currentUserIdProvider);
    final left = await showMembersSheet(
      context,
      listId: list.id,
      isOwner: isOwner,
    );
    if (left != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((route) => route.isFirst);
    messenger.showSnackBar(
      SnackBar(content: Text('Saliste de "${list.name}"')),
    );
  }

  Future<void> _reopen(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(listActionsProvider).reopen(listId);
      if (context.mounted) showMessage(context, 'Lista reabierta');
    } on AppException catch (e) {
      if (context.mounted) showMessage(context, e.message);
    }
  }

  Future<void> _reuse(
    BuildContext context,
    WidgetRef ref,
    ShoppingList list,
  ) async {
    final newId = await promptAndReuse(context, ref, list);
    if (newId == null || !context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ListDetailPage(listId: newId)),
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner({required this.list});

  final ShoppingList list;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = list.completedAt == null
        ? ''
        : ' el ${formatShortDate(list.completedAt!)}';

    return Container(
      width: double.infinity,
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.history, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Lista finalizada$date. Usá el menú para reutilizarla o reabrirla.',
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.items});

  final List<ShoppingItem> items;

  @override
  Widget build(BuildContext context) {
    final done = items.where((i) => i.isChecked).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$done de ${items.length} en el carrito',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: done / items.length),
        ],
      ),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({
    required this.item,
    required this.listId,
    required this.readOnly,
  });

  final ShoppingItem item;
  final String listId;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(shoppingListControllerProvider(listId).notifier);

    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
      } on AppException catch (e) {
        if (context.mounted) showMessage(context, e.message);
      }
    }

    // Si lo llevó otra persona de la familia, se aclara quién.
    final myId = ref.watch(currentUserIdProvider);
    final members = ref.watch(listMembersProvider(listId)).valueOrNull;
    final checkedBy = item.checkedBy;
    final who = (item.isChecked && checkedBy != null && checkedBy != myId)
        ? members?.where((m) => m.userId == checkedBy).firstOrNull?.displayName
        : null;

    final subtitleText = [
      item.subtitle,
      item.progressLabel,
      if (who != null) 'Lo llevó $who',
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    final tile = ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: item.isChecked,
            onChanged:
                readOnly ? null : (_) => run(() => notifier.toggleChecked(item.id)),
          ),
          ProductThumb(imageUrl: item.imageUrl, size: 44),
        ],
      ),
      title: Text(
        item.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: item.isChecked
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.outline,
              )
            : null,
      ),
      subtitle: subtitleText.isEmpty ? null : Text(subtitleText),
      trailing: readOnly
          ? Text('×${item.desiredQty}', style: theme.textTheme.titleMedium)
          : _QuantityStepper(
              quantity: item.desiredQty,
              onChanged: (q) => run(() => notifier.setDesiredQty(item.id, q)),
            ),
      onTap: readOnly ? null : () => run(() => notifier.toggleChecked(item.id)),
    );

    if (readOnly) return tile;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => run(() => notifier.removeItem(item.id)),
      child: tile,
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
        ),
        Text('$quantity', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onChanged(quantity + 1),
        ),
      ],
    );
  }
}

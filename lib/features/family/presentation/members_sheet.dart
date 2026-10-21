import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/snackbars.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../shopping_list/presentation/lists_providers.dart';

/// Hoja con las personas de la lista. Devuelve `true` si el usuario salió de la lista.
Future<bool?> showMembersSheet(
  BuildContext context, {
  required String listId,
  required bool isOwner,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => MembersSheet(listId: listId, isOwner: isOwner),
  );
}

class MembersSheet extends ConsumerWidget {
  const MembersSheet({super.key, required this.listId, required this.isOwner});

  final String listId;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(listMembersProvider(listId));
    final me = ref.watch(currentUserIdProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Miembros', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            members.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(32),
                child: Text(messageOf(e)),
              ),
              data: (list) => Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final m in list)
                      ListTile(
                        leading: CircleAvatar(
                          child: Text(m.displayName.characters.first.toUpperCase()),
                        ),
                        title: Text(m.userId == me ? '${m.displayName} (vos)' : m.displayName),
                        subtitle: Text(m.isOwner ? 'Dueño' : 'Miembro'),
                        trailing: (isOwner && m.userId != me)
                            ? IconButton(
                                icon: const Icon(Icons.person_remove_outlined),
                                tooltip: 'Sacar de la lista',
                                onPressed: () => _remove(context, ref, m.userId, m.displayName),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            ),
            if (!isOwner)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Salir de la lista'),
                  onPressed: () => _leave(context, ref),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String name,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Sacar de la lista',
      message: '$name ya no va a poder ver ni editar esta lista.',
      confirmLabel: 'Sacar',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(listActionsProvider).removeMember(listId, userId);
    } on AppException catch (e) {
      if (context.mounted) showMessage(context, e.message);
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Salir de la lista',
      message: 'Dejás de ver esta lista. Para volver a entrar vas a necesitar '
          'un código de invitación.',
      confirmLabel: 'Salir',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(listActionsProvider).leave(listId);
      if (context.mounted) Navigator.of(context).pop(true);
    } on AppException catch (e) {
      if (context.mounted) showMessage(context, e.message);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/mode/app_mode.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/snackbars.dart';
import '../../../shared/widgets/text_prompt_dialog.dart';
import '../domain/shopping_list.dart';
import 'list_transfer.dart';
import 'lists_providers.dart';

/// Pide el nombre y crea una copia de [list] con los mismos productos, sin tachar.
/// Devuelve el id de la lista nueva, o `null` si se canceló o falló.
///
/// Lo usan el historial y el detalle de una lista finalizada.
Future<String?> promptAndReuse(
  BuildContext context,
  WidgetRef ref,
  ShoppingList list,
) async {
  final name = await showTextPrompt(
    context,
    title: 'Reutilizar lista',
    hint: 'Nombre de la nueva lista',
    initialValue: list.name,
    confirmLabel: 'Crear copia',
  );
  if (name == null) return null;

  try {
    return await ref.read(listActionsProvider).reuse(list.id, name: name);
  } on AppException catch (e) {
    if (context.mounted) showMessage(context, e.message);
    return null;
  }
}

/// Pide confirmación y, si se acepta, borra [list]. Devuelve `true` si se borró.
///
/// Lo usan las pestañas de listas e historial y el detalle de la lista. Lo que
/// necesita de `context` y `ref` lo toma antes de esperar: al borrarse la lista, la
/// tarjeta desde la que se llamó puede desaparecer de la pantalla.
Future<bool> confirmAndDeleteList(
  BuildContext context,
  WidgetRef ref,
  ShoppingList list,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final actions = ref.read(listActionsProvider);
  final local = ref.read(appModeProvider) == AppMode.local;

  final ok = await showConfirmDialog(
    context,
    title: 'Borrar lista',
    message: local
        ? '"${list.name}" se borra de este teléfono, junto con sus productos. '
            'Esto no se puede deshacer.'
        : '"${list.name}" se borra para todos sus miembros, junto con sus '
            'productos. Esto no se puede deshacer.',
    confirmLabel: 'Borrar',
    destructive: true,
  );
  if (!ok) return false;

  try {
    await actions.delete(list.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Lista "${list.name}" borrada')));
    return true;
  } on AppException catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

/// Pide confirmación y, si se acepta, saca al usuario de la lista compartida de otra
/// persona. Devuelve `true` si salió.
Future<bool> confirmAndLeaveList(
  BuildContext context,
  WidgetRef ref,
  ShoppingList list,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final actions = ref.read(listActionsProvider);

  final ok = await showConfirmDialog(
    context,
    title: 'Salir de la lista',
    message: 'Dejás de ver "${list.name}". Para volver a entrar vas a necesitar '
        'un código de invitación.',
    confirmLabel: 'Salir',
    destructive: true,
  );
  if (!ok) return false;

  try {
    await actions.leave(list.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Saliste de "${list.name}"')));
    return true;
  } on AppException catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

/// Abre el menú de compartir del teléfono con una copia de [list] (sin cuentas): quien
/// la recibe la importa pegando el mensaje.
Future<void> shareListCopy(
  BuildContext context,
  WidgetRef ref,
  ShoppingList list,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final transfer = ref.read(listTransferProvider);
  debugPrint('DBG shareListCopy');
  try {
    await transfer.send(list);
  } on AppException catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e.message)));
  } catch (e) {
    debugPrint('DBG error $e');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el menú de compartir.')),
      );
  }
}

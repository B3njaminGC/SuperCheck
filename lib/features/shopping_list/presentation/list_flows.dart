import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/widgets/snackbars.dart';
import '../../../shared/widgets/text_prompt_dialog.dart';
import '../domain/shopping_list.dart';
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

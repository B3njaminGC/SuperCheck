import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Muestra el código de invitación para que la familia se una a la lista.
Future<void> showInviteCodeDialog(
  BuildContext context, {
  required String code,
  required String listName,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Invitar a "$listName"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pasale este código a tu familia. Tienen que abrir SuperCheck, '
            'tener su cuenta y elegir "Unirme con código".',
          ),
          const SizedBox(height: 20),
          Center(
            child: SelectableText(
              code,
              style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('Copiar'),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(ctx);
            final navigator = Navigator.of(ctx);
            await Clipboard.setData(ClipboardData(text: code));
            messenger.showSnackBar(
              const SnackBar(content: Text('Código copiado')),
            );
            navigator.pop();
          },
        ),
      ],
    ),
  );
}

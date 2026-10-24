import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/widgets/snackbars.dart';
import '../domain/list_share.dart';
import '../domain/shopping_list.dart';
import 'list_transfer.dart';

/// Recibir una lista que otra persona envió: se pega el mensaje y se importa.
/// Al terminar devuelve (con `Navigator.pop`) el id de la lista para abrirla.
class ImportListPage extends ConsumerStatefulWidget {
  const ImportListPage({super.key});

  @override
  ConsumerState<ImportListPage> createState() => _ImportListPageState();
}

enum _Choice { replace, copy }

class _ImportListPageState extends ConsumerState<ImportListPage> {
  final _text = TextEditingController();
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _pasteIfListThere();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Al abrir, si lo último que se copió tiene una lista, ya se pega.
  Future<void> _pasteIfListThere() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clip?.text;
    if (text != null && text.contains(ListShareCodec.prefix) && mounted && _text.text.isEmpty) {
      setState(() => _text.text = text);
    }
  }

  Future<void> _paste() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = clip?.text;
    if (text == null || text.isEmpty) {
      showMessage(context, 'No hay nada copiado.');
      return;
    }
    setState(() => _text.text = text);
  }

  Future<void> _import(SharedList shared) async {
    if (_importing) return;
    final transfer = ref.read(listTransferProvider);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _importing = true);
    try {
      final ShoppingList? existing = await transfer.existingFor(shared);
      ShoppingList? replacing;
      if (existing != null) {
        if (!mounted) return;
        final choice = await showDialog<_Choice>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Ya tenés esta lista'),
            content: Text(
              '"${existing.name}" ya está en tu teléfono. ¿Querés reemplazar sus '
              'productos por los nuevos (se pierde lo que ya tachaste) o guardar '
              'una copia aparte?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(_Choice.copy),
                child: const Text('Crear otra copia'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(_Choice.replace),
                child: const Text('Reemplazar'),
              ),
            ],
          ),
        );
        if (choice == null) {
          if (mounted) setState(() => _importing = false);
          return;
        }
        if (choice == _Choice.replace) replacing = existing;
      }

      final listId = await transfer.import(shared, replacing: replacing);
      navigator.pop(listId);
    } on AppException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _text.text;
    final shared = ListShareCodec.decode(text);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Importar lista')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Pegá acá el mensaje que te enviaron con la lista (el que termina en un '
            'código que empieza con SC1:).',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            minLines: 4,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Mensaje con la lista',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _paste,
              icon: const Icon(Icons.content_paste),
              label: const Text('Pegar'),
            ),
          ),
          const SizedBox(height: 16),
          if (text.trim().isNotEmpty && shared == null)
            Text(
              'No encontré una lista en ese texto. Copiá el mensaje completo, con el '
              'código SC1:.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
            ),
          if (shared != null) _Preview(shared: shared),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: shared == null || shared.items.isEmpty || _importing
                ? null
                : () => _import(shared),
            icon: const Icon(Icons.download),
            label: const Text('Importar lista'),
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.shared});

  final SharedList shared;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = shared.items.length;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(shared.name, style: theme.textTheme.titleMedium),
            Text(count == 1 ? '1 producto' : '$count productos'),
            const SizedBox(height: 8),
            for (final item in shared.items.take(12))
              Text(
                '• ${item.name}${item.desiredQty > 1 ? ' ×${item.desiredQty}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (count > 12) Text('… y ${count - 12} más'),
          ],
        ),
      ),
    );
  }
}

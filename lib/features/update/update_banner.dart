import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/snackbars.dart';
import 'update_checker.dart';

/// Aviso "Nueva versión disponible" para el inicio. No ocupa lugar si no hay nada nuevo.
class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  bool _hidden = false;

  Future<void> _update(UpdateInfo info) async {
    final opened = await ref.read(urlOpenerProvider)(info.url);
    if (!opened && mounted) {
      showMessage(context, 'No se pudo abrir la descarga. Probá desde la página de Releases.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(updateCheckProvider).valueOrNull;
    if (info == null || _hidden) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.system_update, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nueva versión disponible',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _hidden = true),
              child: const Text('Más tarde'),
            ),
            FilledButton(
              onPressed: () => _update(info),
              child: const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }
}

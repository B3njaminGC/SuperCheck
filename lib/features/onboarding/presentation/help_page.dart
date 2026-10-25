import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/snackbars.dart';
import '../../update/update_checker.dart';
import '../../../shared/widgets/app_logo.dart';
import 'onboarding_page.dart';

/// Ayuda para quien no conoce la app: qué es y cómo se usa cada parte.
class HelpPage extends ConsumerWidget {
  const HelpPage({super.key});

  static const _topics = <(String, String)>[
    (
      'Armar una lista',
      'En "Mis listas" tocá "Nueva lista" y ponele un nombre, por ejemplo "Compras '
          'del mes". Adentro, tocá "Agregar producto", escribí el nombre (ej. leche), '
          'tocá la lupa y elegí el que quieras: se ve con su foto, marca y tamaño. '
          'Tocá un producto otra vez para sumar una unidad.'
    ),
    (
      'Si el producto no aparece',
      'Escribilo igual y elegí "Crear producto": podés ponerle nombre, marca, '
          'tamaño y una foto sacada por vos. Queda guardado en "Mis productos" para '
          'la próxima. Para cosas sin código de barras, como verdura o pan, usá '
          '"Agregar sin código".'
    ),
    (
      'Comprar y tachar',
      'En el súper, tocá cada producto para tacharlo cuando lo pongas en el carrito. '
          'Si necesitás 4 yogures, cada toque cuenta uno. La barra de arriba muestra '
          'cuánto llevás.'
    ),
    (
      'Usar el escáner',
      'Dentro de una lista tocá el ícono del código de barras y apuntá al producto '
          'de la góndola. Si es el que buscabas, se tacha solo (verde). Si es de otra '
          'marca o de otro tamaño, te avisa y te sugiere cuántos llevar para '
          'completar lo que necesitás. Si el código no se conoce, podés crearlo.'
    ),
    (
      'Finalizar y repetir',
      'Al terminar de comprar, tocá los tres puntitos de la lista y "Finalizar '
          'lista". Queda en la pestaña "Historial": desde ahí la podés reutilizar '
          'para armar otra igual sin empezar de cero.'
    ),
    (
      'Favoritos y Mis productos',
      'La estrella de cada producto lo guarda en Favoritos: al buscar aparecen '
          'primero, junto con los de tus marcas preferidas. Si mantenés apretado un '
          'producto tuyo, podés editarlo o borrarlo.'
    ),
    (
      'Enviar una lista a otra persona',
      'En los tres puntitos de la lista tocá "Enviar copia de la lista" y elegí '
          'WhatsApp u otra app. Quien la recibe copia el mensaje, entra a "Mis '
          'listas", toca el ícono de importar (flecha hacia abajo) y pega. Es una '
          'copia: cada uno edita la suya.'
    ),
    (
      'Mis datos',
      'Todo se guarda en tu teléfono, sin cuenta. Si lo desinstalás, las listas se '
          'borran. Para borrar una lista tocá los tres puntitos y "Borrar lista".'
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              const AppLogo(size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Qué es SuperCheck?',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Una lista del supermercado con fotos, que además te ayuda a '
                      'comprobar en la góndola que llevás el producto correcto.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final (title, text) in _topics)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(title, style: theme.textTheme.titleSmall),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(text, style: theme.textTheme.bodyMedium)],
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (ctx) => OnboardingPage(onDone: () => Navigator.of(ctx).pop()),
              ),
            ),
            icon: const Icon(Icons.slideshow_outlined),
            label: const Text('Ver la bienvenida otra vez'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () async {
              final opened =
                  await ref.read(urlOpenerProvider)(Uri.parse(AppConstants.feedbackUrl));
              if (!opened && context.mounted) {
                showMessage(context, 'No se pudo abrir el formulario.');
              }
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Opinar o reportar un error'),
          ),
        ],
      ),
    );
  }
}

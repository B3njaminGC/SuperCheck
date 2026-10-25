import 'package:flutter/material.dart';

import '../../../shared/widgets/app_logo.dart';

/// Bienvenida: unas pantallas cortas que explican para qué sirve SuperCheck.
/// [onDone] se llama al terminar o al saltearla.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _Slide {
  const _Slide({this.icon, required this.title, required this.text});

  /// `null` en la primera pantalla: ahí va el logo.
  final IconData? icon;
  final String title;
  final String text;
}

const _slides = [
  _Slide(
    title: 'Bienvenido a SuperCheck',
    text: 'Tu lista del supermercado, ordenada y a mano. Armala en casa y '
        'comprá sin olvidarte nada.',
  ),
  _Slide(
    icon: Icons.checklist_rounded,
    title: 'Armá tus listas',
    text: 'Buscá cada producto con su foto, marca y tamaño, y sumalo a la lista. '
        'Si algo no está, lo creás con tu propia foto. Mientras comprás, '
        'tocalo para tacharlo.',
  ),
  _Slide(
    icon: Icons.qr_code_scanner_rounded,
    title: 'Escaneá en la góndola',
    text: 'Apuntá la cámara al código de barras y SuperCheck te dice si es el '
        'producto que buscabas. Si el paquete es de otro tamaño, te avisa '
        'cuántos llevar.',
  ),
  _Slide(
    icon: Icons.history_rounded,
    title: 'Guardá y compartí',
    text: 'Al terminar, finalizá la lista y queda en el historial para repetirla '
        'con un toque. Marcá tus favoritos con la estrella y mandale una copia '
        'de la lista a quien quieras.',
  ),
];

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      widget.onDone();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: _isLast
                    ? const SizedBox(height: 48)
                    : TextButton(onPressed: widget.onDone, child: const Text('Saltar')),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_isLast ? 'Empezar' : 'Siguiente'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 360),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (slide.icon == null)
              const AppLogo(size: 140)
            else
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  slide.icon,
                  size: 68,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            const SizedBox(height: 32),
            Text(
              slide.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              slide.text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

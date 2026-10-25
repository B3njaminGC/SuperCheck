import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/mode/app_mode.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_providers.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/shopping_list/presentation/home_page.dart';

class SuperCheckApp extends StatelessWidget {
  const SuperCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const AuthGate(),
    );
  }
}

/// Decide qué pantalla mostrar según el modo:
/// - sin cuenta: directo a las listas guardadas en el teléfono;
/// - con cuenta: el login si no hay sesión, o las listas compartidas si la hay.
///
/// Al cambiar de modo cierra las pantallas que hubiera abiertas encima, para que no
/// queden mostrando listas del otro modo.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AppMode>(appModeProvider, (previous, next) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    });

    final mode = ref.watch(appModeProvider);
    return mode == AppMode.local ? const HomePage() : const _CloudGate();
  }
}

/// Modo con cuenta. Es un widget aparte para que Supabase solo se toque cuando
/// realmente se usa este modo. Si la sesión se pierde (vence o se cierra), cierra las
/// pantallas abiertas para que no muestren datos de una cuenta sin sesión.
class _CloudGate extends ConsumerWidget {
  const _CloudGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<Session?>(sessionProvider, (previous, next) {
      if (next == null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    final session = ref.watch(sessionProvider);
    return session == null ? const LoginPage() : const HomePage();
  }
}

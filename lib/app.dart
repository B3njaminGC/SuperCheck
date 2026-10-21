import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
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
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.green,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Muestra el login o la pantalla principal según haya sesión iniciada.
/// Si la sesión se pierde (vence o se cierra), cierra las pantallas que hubiera
/// abiertas encima para que no queden mostrando datos de una cuenta sin sesión.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

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

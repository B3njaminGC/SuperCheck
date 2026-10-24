import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/mode/app_mode.dart';
import '../../../core/network/supabase_provider.dart';
import '../data/auth_repository.dart';

/// Solo se debe leer en el modo con cuenta: necesita Supabase iniciado.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Sesión actual (o `null`). Se recalcula cada vez que cambia el estado de auth,
/// y como lee `currentSession` directo, ya es correcta antes del primer evento.
/// Solo se debe leer en el modo con cuenta.
final sessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).currentSession;
});

/// Id de quien usa la app: la sesión en el modo con cuenta, o el usuario único del
/// modo local. Es seguro leerlo en cualquier modo (en el local no toca Supabase).
final currentUserIdProvider = Provider<String?>((ref) {
  if (ref.watch(appModeProvider) == AppMode.local) return localUserId;
  return ref.watch(sessionProvider)?.user.id;
});

/// Mail de la cuenta (solo en el modo con cuenta).
final currentUserEmailProvider = Provider<String?>((ref) {
  if (ref.watch(appModeProvider) == AppMode.local) return null;
  return ref.watch(sessionProvider)?.user.email;
});

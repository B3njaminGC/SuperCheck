import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_provider.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Sesión actual (o `null`). Se recalcula cada vez que cambia el estado de auth,
/// y como lee `currentSession` directo, ya es correcta antes del primer evento.
final sessionProvider = Provider<Session?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).currentSession;
});

/// Id del usuario con sesión iniciada (o `null`).
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(sessionProvider)?.user.id;
});

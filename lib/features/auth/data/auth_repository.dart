import 'dart:io' show SocketException;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';

/// Cuenta de usuario (email + contraseña) sobre Supabase Auth.
/// Al registrarse, el trigger `handle_new_user` crea el perfil automáticamente.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  Session? get currentSession => _auth.currentSession;
  User? get currentUser => _auth.currentUser;
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) {
    return _guard(() async {
      await _auth.signInWithPassword(email: email.trim(), password: password);
    });
  }

  /// Devuelve `true` si la sesión quedó iniciada, o `false` si Supabase pide
  /// confirmar el email antes de poder entrar (configurable en Authentication).
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _guard(() async {
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': displayName.trim()},
      );
      return response.session != null;
    });
  }

  Future<void> signOut() => _guard(() => _auth.signOut());

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (e) {
      throw AppException(_translate(e), cause: e);
    } on SocketException catch (e) {
      throw NetworkException('Sin conexión a internet.', cause: e);
    }
  }

  String _translate(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login credentials')) {
      return 'Email o contraseña incorrectos.';
    }
    if (m.contains('already registered') || m.contains('already been registered')) {
      return 'Ya existe una cuenta con ese email.';
    }
    if (m.contains('email not confirmed')) {
      return 'Confirmá tu email desde el link que te enviamos y volvé a entrar.';
    }
    if (m.contains('password') && m.contains('character')) {
      return 'La contraseña es muy corta (mínimo 6 caracteres).';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'Demasiados intentos. Esperá un momento y probá de nuevo.';
    }
    return 'No se pudo completar la operación (${e.message}).';
  }
}

/// Configuración de entorno, inyectada en tiempo de compilación:
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
///
/// La anon key es pública por diseño (la seguridad la dan las políticas RLS),
/// pero igual conviene no commitearla: usá un archivo `--dart-define-from-file`.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Faltan SUPABASE_URL y/o SUPABASE_ANON_KEY. '
        'Pasalos con --dart-define o --dart-define-from-file.',
      );
    }
  }
}

/// Configuración de entorno, inyectada en tiempo de compilación. Es opcional: sin
/// estos valores la app funciona igual, guardando las listas en el teléfono (modo
/// "sin cuenta"); con ellos se habilita crear una cuenta y compartir listas.
///
/// ```
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJ...
/// ```
///
/// `SUPABASE_ANON_KEY` es la clave pública del proyecto (en el panel de Supabase puede
/// aparecer como "publishable key" o como "anon key"; sirven las dos).
/// Es pública por diseño (la seguridad la dan las políticas RLS),
/// pero igual conviene no commitearla: usá un archivo `--dart-define-from-file`.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// `true` si se pasaron la URL y la clave de Supabase al compilar.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

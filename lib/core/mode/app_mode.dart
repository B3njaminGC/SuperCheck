import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cómo guarda sus listas la app.
///
/// - [local]: todo queda en el teléfono. No hace falta cuenta ni internet (salvo para
///   buscar productos en Open Food Facts). Es el modo con el que arranca la app.
/// - [cloud]: con cuenta de Supabase; las listas se comparten en vivo con la familia.
enum AppMode { local, cloud }

/// Id del único usuario del modo local. Se usa como dueño de las listas.
const localUserId = 'local';

/// `SharedPreferences` ya cargado. Se inyecta en `main()` (y en los tests).
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider debe sobrescribirse en el ProviderScope.',
  );
});

/// `true` si la app tiene Supabase configurado e inicializado, o sea que se puede
/// crear una cuenta para compartir listas. Se inyecta en `main()`.
final cloudAvailableProvider = Provider<bool>((ref) => false);

const _modeKey = 'app_mode';

final appModeProvider =
    NotifierProvider<AppModeController, AppMode>(AppModeController.new);

class AppModeController extends Notifier<AppMode> {
  @override
  AppMode build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_modeKey);
    final cloudAvailable = ref.watch(cloudAvailableProvider);
    // Si la app se instaló sin servidor configurado, siempre se usa el modo local,
    // aunque la última vez se hubiera elegido la nube.
    return (saved == AppMode.cloud.name && cloudAvailable)
        ? AppMode.cloud
        : AppMode.local;
  }

  Future<void> set(AppMode mode) async {
    if (mode == AppMode.cloud && !ref.read(cloudAvailableProvider)) return;
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_modeKey, mode.name);
  }
}

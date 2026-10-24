import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/mode/app_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // La nube es opcional: si no se configuró Supabase (o no se pudo iniciar), la
  // app sigue funcionando con las listas guardadas en el teléfono.
  var cloudAvailable = false;
  if (Env.isSupabaseConfigured) {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
      );
      cloudAvailable = true;
    } catch (_) {
      cloudAvailable = false;
    }
  }

  await initializeDateFormatting('es');

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudAvailableProvider.overrideWithValue(cloudAvailable),
      ],
      child: const SuperCheckApp(),
    ),
  );
}

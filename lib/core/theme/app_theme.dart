import 'package:flutter/material.dart';

/// Aspecto de SuperCheck: fresco y limpio, en celeste, con bordes redondeados.
abstract final class AppTheme {
  /// Celeste del logo.
  static const seed = Color(0xFF1E88E5);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    const radius = 16.0;
    final outline = scheme.outlineVariant;

    return base.copyWith(
      // Fondo apenas celeste en claro, para que las tarjetas blancas se despeguen.
      scaffoldBackgroundColor: dark ? scheme.surface : const Color(0xFFF4F8FC),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? scheme.surface : const Color(0xFFF4F8FC),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: dark ? scheme.surfaceContainer : Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? scheme.surfaceContainer : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide(color: outline),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}

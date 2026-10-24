import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supercheck/app.dart';
import 'package:supercheck/core/mode/app_mode.dart';
import 'package:supercheck/features/products/data/product_photo_picker.dart';
import 'package:supercheck/features/products/data/product_repository.dart';
import 'package:supercheck/features/products/presentation/my_products_controller.dart';
import 'package:supercheck/features/products/presentation/product_providers.dart';

/// Abre la app como la ve quien la instala: sin servidor configurado y con las listas
/// guardadas en el teléfono. La búsqueda de Open Food Facts responde "sin resultados".
Future<void> pumpApp(
  WidgetTester tester,
  SharedPreferences prefs, {
  MockClientHandler? offHandler,
  ProductPhotoPicker? photoPicker,
}) async {
  // Pantalla alta, como un teléfono: con los 600 px de alto de la prueba, las tarjetas de
  // resultados quedaban debajo del borde y no se podían tocar.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final products = ProductRepository(
    client: MockClient(
      offHandler ??
          (_) async => http.Response(
                jsonEncode({'products': <Object>[]}),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ),
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudAvailableProvider.overrideWithValue(false),
        productRepositoryProvider.overrideWithValue(products),
        if (photoPicker != null) productPhotoPickerProvider.overrideWithValue(photoPicker),
      ],
      child: const SuperCheckApp(),
    ),
  );
  await settle(tester);
}

/// Deja pasar un rato para que terminen animaciones y tareas asíncronas.
/// (No se usa `pumpAndSettle` porque los indicadores de carga animan sin parar.)
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Cierra la app y libera todo lo que tenía pendiente.
Future<void> closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Usa el botón "Nueva lista" y queda dentro de la lista creada.
Future<void> createListViaUi(WidgetTester tester, String name) async {
  await tester.tap(find.text('Nueva lista'));
  await settle(tester);
  await tester.enterText(find.byType(TextField), name);
  await tester.tap(find.text('Crear'));
  await settle(tester);
}

/// Dentro de una lista: agrega un ítem de texto libre desde la búsqueda y vuelve.
Future<void> addFreeTextItemViaUi(WidgetTester tester, String text) async {
  await tester.tap(find.text('Agregar producto'));
  await settle(tester);
  await tester.enterText(find.byType(TextField), text);
  await settle(tester, frames: 8); // pasa la espera de la búsqueda (450 ms)
  await tester.tap(find.text('Agregar "$text" sin código'));
  await settle(tester);
  tester.state<NavigatorState>(find.byType(Navigator)).pop();
  await settle(tester);
}

/// Dentro de una lista: la finaliza desde el menú y vuelve al inicio.
Future<void> finishListViaUi(WidgetTester tester) async {
  await tester.tap(find.byType(PopupMenuButton<String>));
  await settle(tester);
  await tester.tap(find.text('Finalizar lista'));
  await settle(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'Finalizar'));
  await settle(tester);
}

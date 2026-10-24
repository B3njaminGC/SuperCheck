import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/app_harness.dart';

/// Recorridos completos de la app tal como queda instalada en el teléfono (modo sin
/// cuenta): se manejan las pantallas de verdad, con toques y texto.
void main() {
  late SharedPreferences prefs;

  setUpAll(() => initializeDateFormatting('es'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('arranca directo en las listas, sin pedir cuenta', (tester) async {
    await pumpApp(tester, prefs);

    expect(find.text('Mis listas'), findsOneWidget);
    expect(find.text('Todavía no tenés listas'), findsOneWidget);
    expect(find.text('Entrar'), findsNothing);

    await tester.tap(find.byTooltip('Cuenta'));
    await settle(tester);
    expect(find.text('Listas guardadas en este teléfono'), findsOneWidget);
    // Sin servidor configurado no se ofrece crear una cuenta.
    expect(find.textContaining('Compartir con mi familia'), findsNothing);

    await closeApp(tester);
  });

  testWidgets('crear una lista, agregar un producto, tacharlo y finalizarla',
      (tester) async {
    await pumpApp(tester, prefs);

    await createListViaUi(tester, 'Compras del mes');
    expect(find.text('Compras del mes'), findsWidgets);
    expect(find.text('La lista está vacía'), findsOneWidget);

    await addFreeTextItemViaUi(tester, 'pan');
    expect(find.text('Pan'), findsOneWidget);
    expect(find.text('0 de 1 en el carrito'), findsOneWidget);

    await tester.tap(find.text('Pan'));
    await settle(tester);
    expect(find.text('1 de 1 en el carrito'), findsOneWidget);

    await finishListViaUi(tester);
    expect(find.text('Mis listas'), findsOneWidget);
    expect(find.text('Todavía no tenés listas'), findsOneWidget);

    await tester.tap(find.text('Historial'));
    await settle(tester);
    expect(find.text('Compras del mes'), findsOneWidget);
    expect(find.textContaining('1 producto'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('desde el historial se reutiliza una lista y se borra la vieja',
      (tester) async {
    await pumpApp(tester, prefs);
    await createListViaUi(tester, 'Compras del mes');
    await addFreeTextItemViaUi(tester, 'pan');
    await tester.tap(find.text('Pan'));
    await settle(tester);
    await finishListViaUi(tester);
    await tester.tap(find.text('Historial'));
    await settle(tester);

    // Reutilizar: crea una copia con los mismos productos, sin tachar.
    await tester.tap(find.text('Reutilizar'));
    await settle(tester);
    await tester.tap(find.text('Crear copia'));
    await settle(tester);
    expect(find.text('Pan'), findsOneWidget);
    expect(find.text('0 de 1 en el carrito'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await settle(tester);

    // La lista del historial sigue ahí hasta que se la borra.
    expect(find.text('Compras del mes'), findsOneWidget);
    await tester.tap(find.text('Borrar'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await settle(tester);
    expect(find.text('Todavía no hay listas finalizadas'), findsOneWidget);

    // La copia (la lista activa) no se tocó.
    await tester.tap(find.text('Listas'));
    await settle(tester);
    expect(find.text('Compras del mes'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('una lista activa se borra desde su menú', (tester) async {
    await pumpApp(tester, prefs);
    await createListViaUi(tester, 'Para borrar');
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await settle(tester);
    expect(find.text('Para borrar'), findsOneWidget);

    await tester.tap(find.byTooltip('Más opciones de Para borrar'));
    await settle(tester);
    await tester.tap(find.text('Borrar lista'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await settle(tester);

    expect(find.text('Para borrar'), findsNothing);
    expect(find.text('Todavía no tenés listas'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('las listas siguen ahí al cerrar y volver a abrir la app',
      (tester) async {
    await pumpApp(tester, prefs);
    await createListViaUi(tester, 'Compras del mes');
    await addFreeTextItemViaUi(tester, 'pan');
    await closeApp(tester);

    // "Reiniciar" la app: mismos datos guardados, pantallas nuevas.
    await pumpApp(tester, prefs);
    expect(find.text('Compras del mes'), findsOneWidget);

    await tester.tap(find.text('Compras del mes'));
    await settle(tester);
    expect(find.text('Pan'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('la búsqueda solo consulta al tocar la lupa, no mientras se escribe',
      (tester) async {
    var requests = 0;
    await pumpApp(tester, prefs, offHandler: (request) async {
      requests++;
      return http.Response(
        jsonEncode({
          'hits': [
            {
              'code': '7790001000011',
              'product_name': 'Leche entera',
              'brands': 'La Serenísima',
              'quantity': '1 l',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await createListViaUi(tester, 'Compras');

    await tester.tap(find.text('Agregar producto'));
    await settle(tester);
    for (final text in ['le', 'lec', 'leche']) {
      await tester.enterText(find.byType(TextField), text);
      await settle(tester, frames: 6);
    }
    expect(requests, 0);
    expect(find.text('Tocá la lupa para buscar'), findsOneWidget);
    // Lo que no tiene código se puede agregar sin buscar nada.
    expect(find.text('Agregar "leche" sin código'), findsOneWidget);

    await tester.tap(find.byTooltip('Buscar'));
    await settle(tester);
    expect(requests, 1);
    expect(find.text('Leche entera'), findsOneWidget);

    await tester.tap(find.text('Leche entera'));
    await settle(tester);
    expect(find.text('Leche entera agregado'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('los resultados se muestran en tarjetas y se filtran por marca',
      (tester) async {
    await pumpApp(tester, prefs, offHandler: (request) async {
      return http.Response(
        jsonEncode({
          'hits': [
            {'code': '1', 'product_name': 'Leche entera', 'brands': 'La Serenísima'},
            {'code': '2', 'product_name': 'Leche descremada', 'brands': 'Sancor'},
            {'code': '3', 'product_name': 'Leche chocolatada', 'brands': 'Sancor'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await createListViaUi(tester, 'Compras');
    await tester.tap(find.text('Agregar producto'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'leche');
    await tester.tap(find.byTooltip('Buscar'));
    await settle(tester);

    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Leche entera'), findsOneWidget);
    expect(find.text('Leche descremada'), findsOneWidget);
    expect(find.text('Todas (3)'), findsOneWidget);
    expect(find.text('Sancor (2)'), findsOneWidget);

    await tester.tap(find.text('Sancor (2)'));
    await settle(tester);
    expect(find.text('Leche entera'), findsNothing);
    expect(find.text('Leche descremada'), findsOneWidget);
    expect(find.text('Leche chocolatada'), findsOneWidget);

    await tester.tap(find.text('Todas (3)'));
    await settle(tester);
    expect(find.text('Leche entera'), findsOneWidget);

    await closeApp(tester);
  });
}

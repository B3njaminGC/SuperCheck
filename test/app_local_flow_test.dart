import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:supercheck/features/products/data/product_photo_picker.dart';

import 'helpers/app_harness.dart';

/// Cámara de mentira: "saca" siempre la misma foto.
class _FakePhotoPicker implements ProductPhotoPicker {
  int taken = 0;

  @override
  Future<String?> takePhoto() async {
    taken++;
    return '/no/existe/foto.jpg';
  }

  @override
  Future<String?> pickFromGallery() async => null;
}

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
    await settle(tester, frames: 2); // la lupa se habilita al reconstruirse la pantalla
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

  testWidgets('crear un producto propio con foto: se agrega a la lista y queda en Mis productos',
      (tester) async {
    final picker = _FakePhotoPicker();
    await pumpApp(tester, prefs, photoPicker: picker);
    await createListViaUi(tester, 'Compras');

    await tester.tap(find.text('Agregar producto'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'azucar impalpable');
    await settle(tester, frames: 2);
    await tester.tap(find.text('Crear producto "azucar impalpable"'));
    await settle(tester);

    // El formulario ya trae el nombre escrito.
    expect(find.text('Guardar producto'), findsOneWidget);
    await tester.tap(find.text('Sacar foto'));
    await settle(tester);
    expect(picker.taken, 1);
    expect(find.text('Quitar foto'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Marca'), 'Dos Anclas');
    await tester.enterText(find.widgetWithText(TextField, 'Tamaño'), '300 g');
    await tester.tap(find.text('Guardar producto'));
    await settle(tester);

    // Se agregó a la lista actual...
    expect(find.text('azucar impalpable agregado'), findsOneWidget);

    // ...y queda en la biblioteca, visible al abrir la búsqueda vacía.
    await tester.tap(find.byTooltip('Borrar'));
    await settle(tester);
    expect(find.text('Mis productos'), findsOneWidget);
    expect(find.text('azucar impalpable'), findsOneWidget);
    expect(find.text('Dos Anclas · 300 g'), findsOneWidget);
    expect(find.text('Mío'), findsOneWidget);

    // También aparece al buscarlo.
    await tester.enterText(find.byType(TextField), 'impalpable');
    await settle(tester, frames: 2);
    await tester.tap(find.byTooltip('Buscar'));
    await settle(tester);
    expect(find.text('azucar impalpable'), findsOneWidget);
    expect(find.text('Mío'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('un producto propio sin código no se duplica: al agregarlo de nuevo suma',
      (tester) async {
    await pumpApp(tester, prefs, photoPicker: _FakePhotoPicker());
    await createListViaUi(tester, 'Compras');
    await tester.tap(find.text('Agregar producto'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'pan casero');
    await settle(tester, frames: 2);
    await tester.tap(find.text('Crear producto "pan casero"'));
    await settle(tester);
    await tester.tap(find.text('Guardar producto'));
    await settle(tester);

    // Tocar la tarjeta (ahora en la biblioteca) lo suma en vez de duplicarlo.
    await tester.tap(find.byTooltip('Borrar'));
    await settle(tester);
    expect(find.text('×1'), findsOneWidget);
    await tester.tap(find.text('pan casero'));
    await settle(tester);
    expect(find.text('×2'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('favoritos: la estrella los guarda, salen primero y vuelven al reabrir',
      (tester) async {
    Future<http.Response> leche(http.Request request) async => http.Response(
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

    await pumpApp(tester, prefs, offHandler: leche);
    await createListViaUi(tester, 'Compras');
    await tester.tap(find.text('Agregar producto'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'leche');
    await settle(tester, frames: 2);
    await tester.tap(find.byTooltip('Buscar'));
    await settle(tester);

    // Se marca "Leche chocolatada" desde su tarjeta.
    final card = find.ancestor(
      of: find.text('Leche chocolatada'),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(of: card, matching: find.byTooltip('Agregar a favoritos')),
    );
    await settle(tester);
    expect(find.byTooltip('Quitar de favoritos'), findsOneWidget);

    // La marca del favorito queda destacada y sus productos suben.
    expect(find.text('★ Sancor (2)'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Leche descremada')).dy,
      lessThan(tester.getTopLeft(find.text('Leche entera')).dy),
    );

    // Sin texto, se ofrece la sección Favoritos.
    await tester.tap(find.byTooltip('Borrar'));
    await settle(tester);
    expect(find.text('Favoritos'), findsOneWidget);
    expect(find.text('Leche chocolatada'), findsOneWidget);
    expect(find.text('Leche entera'), findsNothing);

    // Al cerrar y abrir la app siguen ahí.
    await closeApp(tester);
    await pumpApp(tester, prefs, offHandler: leche);
    await tester.tap(find.text('Compras'));
    await settle(tester);
    await tester.tap(find.text('Agregar producto'));
    await settle(tester);
    expect(find.text('Favoritos'), findsOneWidget);
    expect(find.text('Leche chocolatada'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('enviar una copia de la lista y recibirla pegando el mensaje',
      (tester) async {
    final sharer = FakeListSharer();
    await pumpApp(tester, prefs, listSharer: sharer);
    await createListViaUi(tester, 'Compras del mes');
    await addFreeTextItemViaUi(tester, 'pan');

    // Enviar: el menú de la lista abre el menú de compartir con el mensaje.
    await tester.tap(find.byType(PopupMenuButton<String>));
    await settle(tester);
    await tester.tap(find.text('Enviar copia de la lista'));
    await realWait(tester);
    final avisos = find.descendant(of: find.byType(SnackBar), matching: find.byType(Text));
    expect(
      sharer.sent,
      hasLength(1),
      reason: avisos.evaluate().isEmpty
          ? 'sin aviso en pantalla'
          : 'aviso: ${tester.widgetList<Text>(avisos).map((t) => t.data).join(' | ')}',
    );
    expect(sharer.sent.single, contains('• Pan'));
    expect(sharer.sent.single, contains('SC1:'));

    // Recibir: desde Mis listas se importa pegando el mensaje.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await settle(tester);
    await tester.tap(find.byTooltip('Importar lista'));
    await settle(tester);
    expect(find.text('Importar lista'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'Hola, esta es la lista:\n${sharer.sent.single}');
    await settle(tester, frames: 2);
    expect(find.text('1 producto'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Importar lista'));
    await realWait(tester);

    // En el mismo teléfono ya existe: pregunta qué hacer.
    expect(find.text('Ya tenés esta lista'), findsOneWidget);
    await tester.tap(find.text('Crear otra copia'));
    await realWait(tester);

    // Se abre la copia nueva con el producto.
    expect(find.text('Pan'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await settle(tester);
    expect(find.text('Compras del mes'), findsNWidgets(2));

    await closeApp(tester);
  });

  testWidgets('importar con un texto que no es una lista avisa y no deja importar',
      (tester) async {
    await pumpApp(tester, prefs);
    await tester.tap(find.byTooltip('Importar lista'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'esto no es una lista');
    await settle(tester, frames: 2);

    expect(find.textContaining('No encontré una lista'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Importar lista'),
    );
    expect(button.onPressed, isNull);

    await closeApp(tester);
  });
}

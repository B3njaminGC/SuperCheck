import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supercheck/app.dart';
import 'package:supercheck/core/mode/app_mode.dart';
import 'package:supercheck/features/onboarding/presentation/onboarding_controller.dart';
import 'package:supercheck/features/products/data/product_photo_picker.dart';
import 'package:supercheck/features/update/apk_downloader.dart';
import 'package:supercheck/features/update/update_checker.dart';
import 'package:supercheck/features/products/data/product_repository.dart';
import 'package:supercheck/features/products/presentation/my_products_controller.dart';
import 'package:supercheck/features/products/presentation/product_providers.dart';
import 'package:supercheck/features/shopping_list/presentation/list_transfer.dart';

/// Abre la app como la ve quien la instala: sin servidor configurado y con las listas
/// guardadas en el teléfono. La búsqueda de Open Food Facts responde "sin resultados".
Future<void> pumpApp(
  WidgetTester tester,
  SharedPreferences prefs, {
  MockClientHandler? offHandler,
  ProductPhotoPicker? photoPicker,
  ListSharer? listSharer,
  bool showOnboarding = false,
  UpdateInfo? newVersion,
  FakeUrlOpener? urlOpener,
  FakeApkDownloader? downloader,
  FakeApkInstaller? installer,
}) async {
  // Pantalla alta, como un teléfono: con los 600 px de alto de la prueba, las tarjetas de
  // resultados quedaban debajo del borde y no se podían tocar.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Salvo que la prueba lo pida, la bienvenida ya se vio.
  if (!showOnboarding) await prefs.setBool(OnboardingController.storageKey, true);

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
        updateCheckProvider.overrideWith((ref) async => newVersion),
        apkDownloaderProvider.overrideWithValue(downloader ?? FakeApkDownloader()),
        apkInstallerProvider.overrideWithValue(installer ?? FakeApkInstaller()),
        urlOpenerProvider.overrideWithValue((urlOpener ?? FakeUrlOpener()).open),
        productRepositoryProvider.overrideWithValue(products),
        if (photoPicker != null) productPhotoPickerProvider.overrideWithValue(photoPicker),
        if (listSharer != null) listSharerProvider.overrideWithValue(listSharer),
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

/// Deja correr un instante de tiempo real: las acciones que leen las listas "una vez"
/// (enviar, importar) esperan un stream y no avanzan solo con `pump`.
Future<void> realWait(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await settle(tester);
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

/// Dentro de una lista: crea un producto propio con ese nombre (sin código ni foto), que
/// queda agregado a la lista, y vuelve.
Future<void> addOwnProductViaUi(WidgetTester tester, String name) async {
  await tester.tap(find.text('Agregar producto'));
  await settle(tester);
  await tester.enterText(find.byType(TextField), name);
  await settle(tester, frames: 2);
  await tester.tap(find.text('Crear producto "$name"'));
  await settle(tester);
  await tester.tap(find.text('Guardar producto'));
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

/// Reemplaza el menú de compartir del teléfono: guarda lo que se enviaría.
class FakeListSharer implements ListSharer {
  final sent = <String>[];

  @override
  Future<void> share(String text, {String? subject}) async {
    sent.add(text);
  }
}

/// Reemplaza la apertura de links: guarda lo que se habría abierto.
class FakeUrlOpener {
  final opened = <Uri>[];

  Future<bool> open(Uri url) async {
    opened.add(url);
    return true;
  }
}

/// Reemplaza la descarga del APK: no toca la red ni el disco.
class FakeApkDownloader implements ApkDownloader {
  FakeApkDownloader({this.gate, this.error});

  /// Si se pasa, la descarga queda "en curso" hasta que se complete.
  final Completer<void>? gate;

  /// Si se pasa, la descarga falla con esto.
  final Object? error;

  final requested = <UpdateInfo>[];

  @override
  Future<File> download(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
    DownloadCancel? cancel,
  }) async {
    requested.add(info);
    onProgress?.call(10 * 1024 * 1024, 20 * 1024 * 1024);
    await gate?.future;
    final failure = error;
    if (failure != null) throw failure;
    return File('/fake/SuperCheck-${info.build}.apk');
  }
}

/// Reemplaza el instalador de Android: guarda lo que se habría instalado.
class FakeApkInstaller implements ApkInstaller {
  FakeApkInstaller([this.outcome = InstallOutcome.launched]);

  final InstallOutcome outcome;
  final installed = <String>[];

  @override
  Future<InstallOutcome> install(String path) async {
    installed.add(path);
    return outcome;
  }
}

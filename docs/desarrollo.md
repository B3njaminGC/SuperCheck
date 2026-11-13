# Guía de desarrollo

Esto es para quien quiera tocar el código o sacar una versión. Si solo querés usar la app, mirá el
[README](../README.md).

## Tecnología

Flutter y Dart 3 (canal estable), Riverpod 2 para el estado, `mobile_scanner` para la cámara,
`shared_preferences` para guardar las listas en el teléfono y `http` para consultar Open Food Facts.
Solo se publica para Android.

## Estructura del código

```
lib/
├── main.dart, app.dart          # arranque y pantalla inicial (bienvenida → inicio)
├── core/                        # constantes, errores, modo de uso, red, tema, utilidades
└── features/
    ├── shopping_list/           # listas, ítems, historial, compartir copia (SC2), pantallas
    │   ├── domain/              # modelos y el código de compartir (list_share.dart)
    │   ├── data/                # repositorio local (teléfono) y de la nube (experimental)
    │   └── presentation/        # inicio, detalle, historial, controladores
    ├── products/                # búsqueda y consulta de productos, favoritos, productos propios
    ├── scanner/                 # cámara y lógica que compara lo escaneado con la lista
    ├── update/                  # aviso de versión nueva y descarga/instalación del APK
    ├── onboarding/              # bienvenida y ayuda
    ├── auth/, family/           # login y miembros: solo para el modo con cuenta (experimental)
    └── ...
test/                            # pruebas de Flutter (lógica y recorridos de pantalla)
tests/                           # pruebas en Python de los scripts de tools/ y del flujo de publicación
tools/                           # parches de Android, ícono y firma, usados por el flujo de APK
supabase/migrations/             # SQL del modo con cuenta (experimental)
.github/workflows/               # ci.yml (verificación) y apk.yml (publicación)
```

Ideas de diseño que conviene conocer:

- **Dos modos.** Sin cuenta (el único que trae la versión publicada) las listas viven en
  `SharedPreferences` (`LocalShoppingListRepository`). Existe un modo con cuenta y listas
  compartidas en vivo sobre Supabase (`SupabaseShoppingListRepository`), pero está **desactivado en
  la versión publicada y nunca se probó contra un servidor real**: tomalo como experimental.
- **Estado de un ítem**: `isChecked == (pickedQty >= desiredQty)`; todos los cambios pasan por
  `withPicked`, `withDesiredQty` y `toggled`, que son lógica pura con pruebas.
- **Productos**: `ProductRepository` busca primero en Search-a-licious y cae al buscador clásico de
  Open Food Facts (que limita a 10 búsquedas por minuto por IP). Si hay pocos resultados, o el
  código no existe, consulta también Open Products Facts y Open Beauty Facts. La búsqueda por texto
  espera 0,8 s sin escribir y arranca desde 3 letras.
- **Compartir una copia**: `ListShareCodec` genera un código `SC2:` (binario compacto, deflate y
  base64). Todo lo que se importa se trata como dato de un tercero: se limita el tamaño y se
  limpia cada campo (las fotos solo pueden ser de los dominios de Open Food Facts). Los códigos
  `SC1:` anteriores se siguen leyendo.

## Preparar el entorno

Con el SDK de Flutter instalado:

```bash
flutter pub get
flutter analyze
flutter test
python -m pip install pytest && python -m pytest tests
```

Las carpetas `android/` e `ios/` **no están en el repositorio** (están en el `.gitignore`): las crea
`flutter create`. Para correr la app en un teléfono o emulador:

```bash
flutter create --platforms=android --org com.supercheck --project-name supercheck .
python tools/patch_android_manifest.py android/app/src/main/AndroidManifest.xml
python tools/patch_android_gradle.py android/app
flutter run
```

Los parches agregan los permisos (internet, cámara, instalar actualizaciones), el nombre visible y
desactivan R8, que con la cámara activa rompía el escáner.

## Cómo sacar una versión

1. Asegurate de que la CI de `main` esté en verde y de probar la app a mano en un teléfono.
2. En GitHub: **Actions → APK de Android → Run workflow** (rama `main`). Tarda unos 10 minutos.
3. El flujo arma el APK firmado, comprueba la firma y publica una **release** con la etiqueta
   `app-N` y el archivo `SuperCheck.apk`.
4. Editá las notas de la release (a partir del [CHANGELOG](../CHANGELOG.md)) y agregá la entrada de
   la versión en el CHANGELOG.

**Reglas que no hay que romper** (las vigilan las pruebas de `tests/test_release_workflow.py`):

- `N` es el número de ejecución del flujo y se usa también como número de compilación
  (`versionCode`). El aviso de actualización de la app compara el `N` de la última release con el
  suyo; por eso no hay que publicar releases con otros nombres de etiqueta (el disparador por
  etiquetas `v*` del flujo no sirve para esto).
- El archivo publicado se tiene que llamar `SuperCheck.apk`: la app lo busca por ese nombre.
- **La llave de firma no puede cambiar.** Android solo acepta instalar una versión encima de otra
  si están firmadas con la misma llave; con otra, hay que desinstalar y se pierden las listas.

### Llave de firma

El flujo firma con una llave guardada como **secretos del repositorio** (*Settings → Secrets and
variables → Actions*): `ANDROID_KEYSTORE_BASE64` (el archivo `.keystore` en base64) y
`ANDROID_KEYSTORE_PASSWORD`. El alias es `supercheck`. Nunca se sube al repositorio y hay que
guardar una copia fuera de GitHub: si se pierde, no se podrá actualizar la app. Para crear una (por
ejemplo, en un fork):

```bash
keytool -genkeypair -keystore supercheck.keystore -storetype PKCS12 -alias supercheck \
  -keyalg RSA -keysize 2048 -validity 36500
base64 -w0 supercheck.keystore   # pegar el resultado en ANDROID_KEYSTORE_BASE64
```

## Qué no cubren las pruebas automáticas

La cámara real y el escáner en la góndola, la cámara y la galería para fotos de productos, el
instalador de Android y los permisos, los menús de compartir de otras apps, el comportamiento de los
servidores reales de Open Food Facts (límites, caídas, datos) y el modo con cuenta contra Supabase.
Todo eso hay que probarlo a mano en un teléfono antes de publicar.

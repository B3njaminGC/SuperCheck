# SuperCheck

Lista de supermercado compartida en tiempo real, con cuenta, historial de listas reutilizables y
verificador de productos por código de barras.

## Qué hace

- **Cuenta**: registro e inicio de sesión con email y contraseña (Supabase Auth). Si la sesión se
  pierde, la app vuelve sola al login.
- **Listas compartidas**: se crean con un código de invitación de 8 caracteres; la familia se une con
  "Unirme con código". Lo que agrega o tacha cada uno se ve al instante en los demás.
- **Miembros**: desde el menú de la lista se ve quién participa; el dueño puede sacar gente y el resto
  puede salir de la lista.
- **Quién llevó qué**: en una lista compartida, los productos que tachó otra persona dicen
  "Lo llevó Ana".
- **Renombrar y borrar**: el dueño puede renombrar la lista y borrarla (para todos sus miembros)
  desde el menú; hay confirmación antes de borrar.
- **Historial**: al terminar de comprar se **finaliza** la lista y queda guardada (solo lectura).
  Desde el historial, **Reutilizar** crea una lista nueva con los mismos productos y cantidades, sin
  tachar. También se puede **reabrir** una lista finalizada.
- **Búsqueda**: Open Food Facts por nombre, eligiendo marca y tamaño exactos. Lo que no tiene código de
  barras (verdura, pan) se agrega como **texto libre** con "Agregar sin código".
- **Conteo por unidad**: si pedís 4 yogures, cada escaneo suma uno ("llevás 2 de 4") y el ítem se tacha
  recién al llegar a 4. Tocar el renglón completa o reinicia el ítem de golpe.
- **Escáner en la góndola**:
  - código idéntico a un ítem → suma una unidad y tacha al completar (verde);
  - mismo producto con otro gramaje → aviso con sugerencia, ej. *"Este paquete es de 250 g. Te
    sugerimos llevar 2 unidades (500 g en total)"*; la cuenta descuenta lo que ya está en el carrito;
  - producto que no estaba en la lista → "Agregar y tachar";
  - código que Open Food Facts no conoce → aviso.

## Estructura

```
supercheck/
├── pubspec.yaml
├── analysis_options.yaml
├── .github/workflows/ci.yml           # flutter analyze + flutter test en cada push
├── supabase/migrations/               # ejecutar en orden
│   ├── 0001_init.sql                  # tablas, RLS, invitaciones, realtime
│   ├── 0002_history.sql               # estado de lista, finalizar/reabrir/reutilizar
│   ├── 0003_picked_qty.sql            # conteo por unidad
│   └── 0004_leave_lists.sql           # salir de una lista / sacar miembros
├── lib/
│   ├── main.dart  app.dart            # init + AuthGate (login o inicio)
│   ├── core/                          # config, errores, red, utilidades
│   ├── features/
│   │   ├── auth/                      # AuthRepository, LoginPage, sesión
│   │   ├── family/                    # ListMember, hoja de miembros, diálogo de invitación
│   │   ├── products/                  # Open Food Facts: Product, NetQuantity, búsqueda
│   │   ├── scanner/
│   │   │   ├── domain/                # ScanVerifier, SizeAdvice, ProductMatcher (lógica pura)
│   │   │   └── presentation/          # cámara, controlador y banner de resultados
│   │   └── shopping_list/
│   │       ├── domain/                # ShoppingList, ShoppingItem
│   │       ├── data/                  # repositorio Supabase
│   │       └── presentation/          # inicio, listas, historial, detalle, controladores
│   └── shared/widgets/
└── test/                              # barcode, cantidades, repositorio OFF, ítems, verificador
```

## Puesta en marcha

1. Crear el proyecto base y copiar estos archivos encima:
   ```
   flutter create supercheck --org com.tuorg
   # copiá lib/, test/, supabase/, pubspec.yaml y analysis_options.yaml de esta carpeta
   cd supercheck && flutter pub get
   ```
2. En Supabase (plan Free), *SQL Editor*: ejecutar **en orden** los cuatro archivos de
   `supabase/migrations/`.
3. *Authentication → Providers*: Email habilitado. Para probar rápido, desactivá *Confirm email*
   (si no, el registro pide confirmar el mail antes de entrar).
4. Permisos de cámara (los archivos de plataforma los genera `flutter create`):
   - **Android** `android/app/src/main/AndroidManifest.xml`:
     `<uses-permission android:name="android.permission.CAMERA"/>` y en
     `android/app/build.gradle` `minSdkVersion 23` (o superior).
   - **iOS** `ios/Runner/Info.plist`: clave `NSCameraUsageDescription` con un texto como
     "Usamos la cámara para escanear códigos de barras".
5. Editá `offUserAgent` en `lib/core/constants/app_constants.dart` con un mail de contacto real.
6. Ejecutar:
   ```
   flutter run \
     --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY
   ```
7. Tests: `flutter test`

## Notas de diseño

- **Estado de un ítem**: `isChecked == (pickedQty >= desiredQty)`. Todos los cambios pasan por
  `withPicked`, `withDesiredQty` y `toggled` de `ShoppingItem` (lógica pura, con tests). Subir la
  cantidad de un ítem completo lo vuelve pendiente; bajarla por debajo de lo llevado lo completa.
- **Historial**: una lista tiene `status` (`active` / `completed`). Las funciones SQL `complete_list`,
  `reopen_list` y `duplicate_list` hacen el trabajo; cualquier miembro puede finalizar (suele hacerlo
  quien está en el súper). Una lista finalizada rechaza cambios de ítems por RLS hasta reabrirla.
  La copia al reutilizar es del usuario que la pide, con su propio código de invitación y sin avance.
- **Miembros**: la fila del dueño no se puede borrar (lo impide la política RLS de `0004`); el dueño
  finaliza o borra la lista en vez de salir.
- **Comparación de gramaje**: ver `scanner/domain/`. El mismo producto se reconoce por marca + nombre
  (heurística, porque Open Food Facts no trae un identificador de familia); la UI siempre muestra qué se
  escaneó para que la persona decida. Se compara lo que falta llevar (paquete × unidades pendientes) con
  el paquete escaneado, con 2 % de tolerancia.
- **Búsqueda por nombre**: `searchByName` usa `/cgi/search.pl` (el endpoint `/api/v2/search` filtra por
  etiquetas pero no hace texto libre), priorizando productos de Argentina con fallback mundial.
- **Códigos de barras**: se comparan normalizados (sin ceros a la izquierda) para que UPC-A y EAN-13 coincidan.

## Sin verificar y pendientes

- **Nada de esto se compiló ni se corrió todavía** (el entorno donde se escribió no tiene el SDK de
  Flutter). Lo primero: `flutter pub get`, `flutter analyze` y `flutter test`, o subirlo a GitHub y
  mirar el resultado del CI. La parte más probable de necesitar ajustes es `scanner_page.dart`, porque
  la API de `mobile_scanner` cambia entre versiones. `flutter analyze` falla también por avisos de nivel
  "info": si el CI sale rojo solo por estilo, cambiá el paso a `flutter analyze --no-fatal-infos`.
- Riverpod 2.x: si actualizás a Riverpod 3 hay que migrar los notifiers.
- Sin modo offline: Hive está en el `pubspec` pero aún no se usa.
- Los ítems de texto libre solo se emparejan con el escáner si el nombre coincide casi exacto con el
  producto escaneado (sin marca se exige un solapamiento alto).

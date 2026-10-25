# SuperCheck

**La lista del supermercado con fotos, que además comprueba en la góndola que llevás el producto correcto.**
Gratis, para Android y sin necesidad de crear una cuenta.

## Qué ofrece

- **Listas con fotos**: buscá productos por nombre y elegí marca y tamaño exactos.
- **Escáner de código de barras**: confirma que el producto es el de tu lista y te sugiere cuántas unidades llevar si el tamaño cambia.
- **Productos propios y favoritos**: creá lo que no esté en la base con tu foto y marcá tus favoritos.
- **Historial**: finalizá cada compra y reutilizá listas anteriores con un toque.
- **Compartir sin cuenta**: enviá una copia de la lista por WhatsApp; quien la recibe la importa pegando el mensaje.
- Todo se guarda en tu teléfono. Compartir en vivo con la familia es opcional (ver más abajo).

## Descargar (Android)

1. Entrá a **[Releases](https://github.com/B3njaminGC/SuperCheck/releases/latest)** desde tu celular y tocá **SuperCheck.apk**.
2. Abrí el archivo. Si Android avisa que bloquea instalar apps de esta fuente, tocá **Configuración** y activá
   **Permitir de esta fuente**. Si Play Protect avisa de una app "no verificada", tocá *Instalar de todos
   modos*: es normal en apps que no vienen de la tienda.
3. Abrí SuperCheck: entra directo a tus listas. La primera vez que escanees, Android pide permiso para la cámara.
4. Para actualizar, instalá el APK nuevo **encima**: las listas se conservan. No desinstales antes.

## Cómo sacar un APK nuevo

En GitHub: pestaña **Actions** → **APK de Android** → **Run workflow**. Tarda unos 10 minutos y deja el archivo
en **Releases** (hacen falta los secretos de firma, ver *Firma del APK*).

## Cuentas y compartir en vivo (opcional)

Sin esto la app ya funciona completa para una persona. Para compartir listas con la familia:

1. Crear un proyecto gratis en <https://supabase.com> (plan Free, sin tarjeta).
2. *SQL Editor*: ejecutar **en orden** los cuatro archivos de `supabase/migrations/`.
3. *Authentication → Providers*: Email habilitado. Para probar rápido, desactivá *Confirm email*.
4. En GitHub: *Settings → Secrets and variables → Actions → New repository secret*, crear
   `SUPABASE_URL` (la URL del proyecto) y `SUPABASE_ANON_KEY` (la clave pública/publishable).
5. Sacar un APK nuevo (sección anterior). Desde ese momento el login muestra además "Seguir sin
   cuenta", y el menú de la app permite pasar a la cuenta.

Aviso del plan Free de Supabase: pausa el proyecto tras una semana sin uso (se reactiva desde su
panel con un clic) y no incluye copias de seguridad.

Las listas del teléfono y las de la cuenta son **independientes**: no se pasan de un modo al otro.

## Qué hace

- **Bienvenida y ayuda**: la primera vez que se abre, cuatro pantallas cortas explican para qué sirve la
  app (se puede saltear). El ícono **?** de la pantalla de inicio abre la ayuda con cada función explicada
  y permite ver la bienvenida otra vez. El menú de cuenta solo aparece si hay servidor configurado.
- **Crear producto**: si algo no está en Open Food Facts (o querés tu propia foto), se crea con
  nombre, marca, tamaño, código de barras opcional y foto (cámara o galería). Queda en **Mis
  productos**, aparece al buscar y el escáner lo reconoce por su código.
- **Favoritos**: la estrella de cada tarjeta guarda el producto. Antes de escribir se ven tus
  favoritos, y al buscar salen primero ellos y los productos de sus marcas (marcadas con ★).
- **Enviar una copia de la lista (sin cuenta)**: menú de la lista → *Enviar copia de la lista*
  abre el menú de compartir (WhatsApp, etc.) con la lista en texto y un código `SC1:`. Quien la
  recibe copia el mensaje y, en *Mis listas*, toca el ícono de importar y pega. Es una **copia**, no
  una lista en vivo: para editar juntos en tiempo real hace falta la cuenta opcional. Si la lista ya
  estaba, se elige entre reemplazarla o crear otra copia. Las fotos propias no viajan.
- **Sin cuenta**: las listas se guardan en el teléfono. Se pueden **borrar** desde la pestaña
  Listas (menú de cada una) y desde el Historial, con confirmación.
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
├── .github/workflows/apk.yml          # arma el APK y lo publica en Releases
├── tools/                             # parches de Android, ícono y firma del APK
├── supabase/migrations/               # ejecutar en orden
│   ├── 0001_init.sql                  # tablas, RLS, invitaciones, realtime
│   ├── 0002_history.sql               # estado de lista, finalizar/reabrir/reutilizar
│   ├── 0003_picked_qty.sql            # conteo por unidad
│   └── 0004_leave_lists.sql           # salir de una lista / sacar miembros
├── lib/
│   ├── main.dart  app.dart            # init + AuthGate (login o inicio)
│   ├── core/                          # config, modo (sin cuenta / cuenta), errores, red
│   ├── features/
│   │   ├── auth/                      # AuthRepository, LoginPage, sesión
│   │   ├── family/                    # ListMember, hoja de miembros, diálogo de invitación
│   │   ├── products/                  # Open Food Facts: Product, NetQuantity, búsqueda
│   │   ├── scanner/
│   │   │   ├── domain/                # ScanVerifier, SizeAdvice, ProductMatcher (lógica pura)
│   │   │   └── presentation/          # cámara, controlador y banner de resultados
│   │   └── shopping_list/
│   │       ├── domain/                # ShoppingList, ShoppingItem
│   │       ├── data/                  # repositorio local (teléfono) y Supabase
│   │       └── presentation/          # inicio, listas, historial, detalle, controladores
│   └── shared/widgets/
└── test/                              # barcode, cantidades, repositorio OFF, ítems, verificador
```

## Desarrollo

Con el SDK de Flutter instalado: `flutter create --platforms=android .`, `flutter pub get`,
`flutter test` y `flutter run` (con `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
si querés probar la cuenta). Editá `offUserAgent` en `lib/core/constants/app_constants.dart` con un mail
de contacto real.

## Firma del APK

La llave de firma **no está en el repositorio**: vive como secretos de GitHub (*Settings → Secrets and
variables → Actions*): `ANDROID_KEYSTORE_BASE64` (el archivo `.keystore` en base64) y
`ANDROID_KEYSTORE_PASSWORD`. Alias de la llave: `supercheck`. Tiene que ser siempre la misma: si cambia,
Android no deja actualizar encima y hay que desinstalar la app (se pierden las listas). Para armar tu propio
APK desde un fork, generá una llave con `keytool -genkeypair` y cargá esos dos secretos.

## Licencia y datos

Código bajo licencia [MIT](LICENSE). Los datos y las fotos de productos vienen de
[Open Food Facts](https://world.openfoodfacts.org), una base abierta y colaborativa (licencia ODbL;
las imágenes, CC BY-SA).

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

## Pendientes

- El escáner con la cámara real y el uso en la góndola solo se pueden probar en un teléfono: los tests
  automáticos cubren la lógica de comparación, las listas y los recorridos de pantalla.
- Pasar listas del teléfono a la cuenta (hoy son independientes).
- Riverpod 2.x: si actualizás a Riverpod 3 hay que migrar los notifiers.

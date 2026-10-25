# SuperCheck

**La lista del supermercado con fotos, que además comprueba en la góndola que llevás el producto correcto.**
Gratis, para Android y sin necesidad de crear una cuenta.

## Qué ofrece

- **Listas con fotos**: buscá productos por nombre y elegí marca y tamaño exactos.
- **Escáner de código de barras**: confirma que el producto es el de tu lista y te sugiere cuántas unidades llevar si el tamaño cambia.
- **Productos propios y favoritos**: creá lo que no esté en la base con tu foto y marcá tus favoritos.
- **Historial**: finalizá cada compra y reutilizá listas anteriores con un toque.
- **Compartir sin cuenta**: enviá una copia de la lista por WhatsApp; quien la recibe la importa pegando el mensaje.
- Todo se guarda en tu teléfono.

## Descargar (Android)

1. Entrá a **[Releases](https://github.com/B3njaminGC/SuperCheck/releases/latest)** desde tu celular y tocá **SuperCheck.apk**.
2. Abrí el archivo. Si Android avisa que bloquea instalar apps de esta fuente, tocá **Configuración** y activá
   **Permitir de esta fuente**. Si Play Protect avisa de una app "no verificada", tocá *Instalar de todos
   modos*: es normal en apps que no vienen de la tienda.
3. Abrí SuperCheck: entra directo a tus listas. La primera vez que escanees, Android pide permiso para la cámara.
4. Para actualizar, instalá el APK nuevo **encima**: las listas se conservan. No desinstales antes.

## Cómo sacar un APK nuevo

En GitHub: pestaña **Actions** → **APK de Android** → **Run workflow**. Tarda unos 10 minutos y deja el archivo
en **Releases**.

## Opiniones y errores

¿Algo no anda o tenés una idea? Contalo en este
[formulario](https://docs.google.com/forms/d/e/1FAIpQLSfiamKhFf6ihGTKJTh6bf4VJarRt_sqiqk5viALKzsQwnfYog/viewform)
(no hace falta cuenta) o abrí un [issue](https://github.com/B3njaminGC/SuperCheck/issues/new/choose).
También está en la app: ícono **?** → *Opinar o reportar un error*.

Cuando sale una versión nueva, la app avisa al abrirse con un botón **Actualizar**.

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

## Licencia y datos

Código bajo licencia [MIT](LICENSE). Los datos y las fotos de productos vienen de
[Open Food Facts](https://world.openfoodfacts.org), una base abierta y colaborativa (licencia ODbL;
las imágenes, CC BY-SA).

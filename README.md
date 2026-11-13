<div align="center">

# SuperCheck

**Tu lista del supermercado con fotos, y un escáner que te dice si llevás el producto correcto.**

[![CI](https://github.com/B3njaminGC/SuperCheck/actions/workflows/ci.yml/badge.svg)](https://github.com/B3njaminGC/SuperCheck/actions/workflows/ci.yml)
![Plataforma: Android](https://img.shields.io/badge/plataforma-Android-3DDC84)
[![Licencia: MIT](https://img.shields.io/badge/licencia-MIT-blue)](LICENSE)

[**⬇ Descargar la app**](https://github.com/B3njaminGC/SuperCheck/releases/latest) ·
[Opinar o reportar un error](https://docs.google.com/forms/d/e/1FAIpQLSfiamKhFf6ihGTKJTh6bf4VJarRt_sqiqk5viALKzsQwnfYog/viewform)

</div>

## Qué es y qué no es

SuperCheck es una app gratuita para **Android**, sin cuenta y sin anuncios. Armás tu lista con
la foto, la marca y el tamaño de cada producto y, en el súper, escaneás el código de barras de
lo que agarrás para comprobar que es el que buscabas.

**No es** una tienda ni un comparador de precios (no muestra precios). **No es** una app
oficial de Open Food Facts ni de ningún supermercado. **No** sincroniza listas en vivo entre
teléfonos. **No** hay versión para iPhone y **no** está en Google Play.

## Qué puede hacer

- **Listas con fotos**: buscás el producto por nombre y elegís la marca y el tamaño exactos. Mientras comprás, lo tocás para tacharlo.
- **Escáner de código de barras**: confirma si el producto es el de tu lista. Si el paquete es de otro tamaño, te sugiere cuántas unidades llevar para completar lo que necesitás.
- **Productos propios**: si algo no aparece (o no tiene código de barras, como la verdura), lo creás con tu foto.
- **Favoritos**: marcás con la estrella lo que comprás siempre y aparece primero al buscar.
- **Historial**: al terminar la compra, la lista queda guardada y la reutilizás con un toque.
- **Compra pendiente**: si no conseguiste todo, lo comprado va al historial y la lista queda con lo que falta, marcada como PENDIENTE.
- **Enviar una copia** de la lista por WhatsApp u otra app. Quien la recibe la importa pegando el mensaje.
- **Ayuda integrada**: una bienvenida la primera vez y una guía (ícono **?**).

## Instalación

1. Desde tu celular Android, entrá a **[Releases](https://github.com/B3njaminGC/SuperCheck/releases/latest)** y tocá **SuperCheck.apk**.
2. Abrí el archivo descargado. Si Android avisa que bloquea instalar apps de esta fuente, tocá **Configuración** y activá **Permitir de esta fuente**.
3. Si Play Protect avisa de una app "no verificada", tocá *Instalar de todos modos*: la app no viene de la tienda de Google.
4. Abrí SuperCheck. La primera vez que escanees, Android pide permiso para la cámara.

## Actualizar

La app avisa cuando hay una versión nueva. El botón **Actualizar** descarga el archivo dentro de la
app (con barra de progreso), comprueba que esté completo y abre el instalador de Android. La primera
vez, Android pide activar **Permitir de esta fuente** para SuperCheck.

Si la actualización dentro de la app falla, descargá el APK nuevo desde
[Releases](https://github.com/B3njaminGC/SuperCheck/releases/latest) e instalalo **encima**: las
listas se conservan. **No desinstales antes**, porque borrarías las listas.

## Limitaciones conocidas

- **Los datos de productos son colaborativos.** Vienen de [Open Food Facts](https://world.openfoodfacts.org) y, para limpieza e higiene, de Open Products Facts y Open Beauty Facts. La cobertura de productos argentinos es parcial: pueden faltar productos o fotos, y los nombres, marcas o envases pueden estar desactualizados (por ejemplo, un rediseño reciente).
- **Buscar y escanear necesitan internet.** Las listas ya armadas se ven sin conexión. Esos servicios gratuitos limitan las consultas: a veces la búsqueda falla por saturación y hay que reintentar.
- **Tus datos viven solo en tu teléfono.** No hay copia de seguridad ni sincronización: desinstalar la app borra las listas. *Enviar copia* es una copia, no una lista compartida en vivo.
- **Tus productos y fotos propias no viajan** con las copias de listas que enviás.
- **El escáner depende de la cámara y de la luz.** Fue probado en pocos teléfonos; si te falla con alguno, avisanos.
- **La actualización dentro de la app depende de Android.** Algunos equipos o versiones pueden pedir pasos extra para instalar; en ese caso se instala a mano desde Releases.

## Tus datos

Las listas se guardan **solo en tu teléfono**; no hay cuenta ni servidor propio. La app consulta
Open Food Facts (y sus bases hermanas) para buscar productos y GitHub para saber si hay una versión
nueva. No recopila datos personales.

## Opiniones y errores

Contanos en el [formulario](https://docs.google.com/forms/d/e/1FAIpQLSfiamKhFf6ihGTKJTh6bf4VJarRt_sqiqk5viALKzsQwnfYog/viewform)
(no hace falta cuenta) o abrí un [issue](https://github.com/B3njaminGC/SuperCheck/issues/new/choose).
También está dentro de la app: ícono **?** → *Opinar o reportar un error*. Si encontrás un fallo de
seguridad, mirá [CONTRIBUTING.md](CONTRIBUTING.md#fallos-de-seguridad) antes de publicarlo.

## Desarrollo

SuperCheck se desarrolla **con ayuda de Claude**, un asistente de inteligencia artificial de
Anthropic que escribe gran parte del código. Esto no se oculta: los commits llevan la línea
`Co-Authored-By: Claude` y el historial no se reescribe. El autor decide qué hace la app, la prueba
a mano en un teléfono Android y resuelve qué se publica.

Cómo se verifica cada cambio:

- **Pruebas automáticas en cada push** (GitHub Actions): análisis estático de Dart, pruebas de Flutter (lógica de listas, escáner, búsqueda, compartir, pantallas) y pruebas en Python de los scripts de publicación.
- **Prueba manual en un teléfono Android** antes de publicar una versión. Las pruebas automáticas no usan la cámara real, el instalador de Android ni los servidores reales de Open Food Facts.

Estructura del código, cómo compilar y cómo sacar una versión: [docs/desarrollo.md](docs/desarrollo.md).
Historial de versiones: [CHANGELOG.md](CHANGELOG.md). Cómo colaborar: [CONTRIBUTING.md](CONTRIBUTING.md).

## Créditos y licencia

Los datos y las fotos de productos vienen de [Open Food Facts](https://world.openfoodfacts.org),
una base abierta y colaborativa (datos bajo licencia ODbL; imágenes bajo CC BY-SA). Si un producto
no aparece o tiene un dato equivocado, podés corregirlo ahí y se va a ver en SuperCheck.

El código está bajo licencia [MIT](LICENSE).

# Historial de cambios

Todos los cambios importantes de SuperCheck se anotan acá. El formato sigue
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

Las versiones se numeran con el número de compilación (`app-N`, la etiqueta de cada
[release](https://github.com/B3njaminGC/SuperCheck/releases)). No hay números del tipo 1.2.3: la app
compara ese `N` para saber si hay una versión nueva.

## [Sin publicar]

### Agregado
- Pruebas en Python de los scripts de compilación y de las reglas de publicación (`tests/`), que ahora corren en cada push.
- `CHANGELOG.md`, `CONTRIBUTING.md` y `docs/desarrollo.md`.

### Cambiado
- El README ahora es solo para quien usa la app: dice qué es y qué no es, las limitaciones conocidas y cómo se desarrolla (con ayuda de Claude).
- `.gitignore` reordenado y sin los `.gitkeep` que sobraban.

## [app-17] - 2026-11-11

### Agregado
- Para productos de limpieza e higiene, la búsqueda y el escáner también consultan Open Products Facts y Open Beauty Facts cuando Open Food Facts no los tiene.

## [app-16] - 2026-11-04

### Agregado
- Actualización dentro de la app: descarga el APK con barra de progreso, comprueba tamaño y SHA-256, permite cancelar y abre el instalador de Android. Si algo falla, ofrece abrir la página de descarga en el navegador.

## [app-15] - 2026-10-30

### Cambiado
- La búsqueda muestra resultados mientras escribís (desde 3 letras y con una pequeña espera), sin tener que tocar la lupa.

## [app-14] - 2026-10-30

### Agregado
- Compra pendiente: con el botón del reloj, lo ya tachado pasa al historial y la lista queda con lo que falta, marcada como PENDIENTE.

### Cambiado
- El código al enviar una copia de la lista es mucho más corto (formato `SC2:`). Los códigos anteriores (`SC1:`) se siguen pudiendo importar.

### Eliminado
- La opción de agregar un producto sin código de barras desde la búsqueda; para eso están los productos propios.

## [app-13] - 2026-10-25

Primera versión pública ("SuperCheck 1.0").

### Agregado
- Aviso de versión nueva con botón **Actualizar**.
- Botón para opinar o reportar errores, formularios de issues y licencia MIT.
- Botones directos de eliminar y enviar en cada lista, y botón flotante para tachar con un toque.

### Cambiado
- Las versiones se firman con una llave nueva guardada como secreto del repositorio (la anterior se retiró). Quien tenga instaladas las pruebas anteriores debe desinstalarlas antes de instalar esta.

## app-1 a app-12 - 24 y 25 de octubre de 2026

Versiones de prueba, no recomendadas para usar (sus releases se eliminaron). Primero se armó la base:

### Agregado
- Compilación del APK con GitHub Actions y modo sin cuenta, con las listas guardadas en el teléfono.
- Búsqueda de productos en Open Food Facts, con filtro por marca y tarjetas con foto.
- Escáner de código de barras que verifica el producto contra la lista.
- Crear productos propios con foto, favoritos e historial de compras.
- Eliminar listas y enviar/importar una copia (código `SC1:`).
- Tema celeste, logo e ícono, bienvenida y ayuda.

### Corregido
- Cámara que fallaba en la versión compilada (se desactivó R8).

[Sin publicar]: https://github.com/B3njaminGC/SuperCheck/compare/app-17...HEAD
[app-17]: https://github.com/B3njaminGC/SuperCheck/compare/app-16...app-17
[app-16]: https://github.com/B3njaminGC/SuperCheck/compare/app-15...app-16
[app-15]: https://github.com/B3njaminGC/SuperCheck/compare/app-14...app-15
[app-14]: https://github.com/B3njaminGC/SuperCheck/compare/app-13...app-14
[app-13]: https://github.com/B3njaminGC/SuperCheck/compare/app-12...app-13

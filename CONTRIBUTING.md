# Cómo colaborar

¡Gracias por querer ayudar! SuperCheck es un proyecto chico, así que las reglas también lo son.

## Antes de empezar

- Para un cambio grande, abrí primero un [issue](https://github.com/B3njaminGC/SuperCheck/issues/new/choose) contando la idea.
- Un **cambio por idea**: un pull request o commit trata un solo tema. Es más fácil de revisar y de deshacer.
- Los mensajes de commit van **en español** y explican **por qué** se hace el cambio, no solo qué.

## Pruebas

Todo cambio de lógica trae su prueba. Antes de subir:

```bash
flutter analyze
flutter test
python -m pytest tests   # scripts de tools/ y reglas de publicación
```

La CI corre lo mismo en cada push; un cambio con pruebas en rojo no se publica. Cómo preparar el
entorno: [docs/desarrollo.md](docs/desarrollo.md).

## Nada personal en el repositorio

No subas datos personales ni secretos: mails, nombres reales, rutas de tu computadora, tokens,
claves de API, llaves de firma (`*.keystore`), archivos `env.json` o `.env`. El `.gitignore` ya
excluye los más comunes, pero revisá tu cambio (`git diff`) antes de subirlo. Las capturas y los
logs que adjuntes a un issue tampoco deben mostrar datos tuyos.

## Fallos de seguridad

**No publiques los detalles en un issue.** Usá el aviso privado de GitHub: pestaña **Security** →
**Report a vulnerability** (si no aparece esa opción, abrí un issue que diga solo "quiero
reportar un tema de seguridad", sin detalles, y te respondemos por ahí cómo seguir). Contanos qué
pasa y cómo reproducirlo, sin incluir datos reales de nadie.

## Uso de IA

El proyecto se desarrolla con ayuda de Claude y no lo oculta (ver el README). Si usás una
herramienta de IA para tu contribución, estás en tu derecho, pero revisá y probá lo que sube: la
responsabilidad del cambio es de quien lo envía.

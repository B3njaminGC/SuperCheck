# Firma de la app

`debug.keystore` es la llave con la que se firma el APK. Tiene que ser **siempre la misma**:
si cambiara, Android no dejaría actualizar la app instalada y habría que desinstalarla
(y se perderían las listas guardadas en el teléfono).

Este repositorio es privado, por eso la llave puede vivir acá. Si alguna vez lo hacés
público, antes sacá este archivo del repositorio y guardalo como secreto.

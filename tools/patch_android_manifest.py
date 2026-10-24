"""Ajusta el AndroidManifest que genera `flutter create` para SuperCheck.

- INTERNET: las versiones release de Flutter no la traen y sin ella no hay búsqueda de
  productos ni sincronización.
- CAMERA: para el lector de códigos de barras (la cámara no es obligatoria).
- Nombre visible de la app.
"""
import re
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()

extra = (
    '    <uses-permission android:name="android.permission.INTERNET"/>\n'
    '    <uses-permission android:name="android.permission.CAMERA"/>\n'
    '    <uses-feature android:name="android.hardware.camera" android:required="false"/>\n'
    '    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false"/>\n'
)

if "android.permission.INTERNET" not in text:
    text, n = re.subn(r"(<manifest[^>]*>\s*\n)", lambda m: m.group(1) + extra, text, count=1)
    assert n == 1, "no encontré la etiqueta <manifest>"

text, n = re.subn(r'android:label="[^"]*"', 'android:label="SuperCheck"', text, count=1)
assert n == 1, "no encontré android:label"

open(path, "w", encoding="utf-8").write(text)
print("AndroidManifest.xml ajustado")

"""Apaga el compactador y ofuscador de código (R8) en las versiones release.

Con R8 activo, las clases del lector de códigos de barras (mobile_scanner/CameraX) quedan
renombradas y la cámara falla con "Attempt to invoke virtual method ... on a null object
reference". `flutter build apk --no-shrink` no alcanza: hay que decírselo a Gradle.
Funciona con el build.gradle.kts (Kotlin) y con el build.gradle (Groovy) que genera Flutter.
"""
import os
import re
import sys

app_dir = sys.argv[1]
kts = os.path.join(app_dir, "build.gradle.kts")
groovy = os.path.join(app_dir, "build.gradle")

if os.path.exists(kts):
    path, is_kts = kts, True
elif os.path.exists(groovy):
    path, is_kts = groovy, False
else:
    sys.exit("no encontré android/app/build.gradle(.kts)")

text = open(path, encoding="utf-8").read()

# Fuera cualquier ajuste previo de compactación (el último que se asigna gana).
text = re.sub(
    r"^[ \t]*(isMinifyEnabled|isShrinkResources|minifyEnabled|shrinkResources)\b[^\n]*\n",
    "",
    text,
    flags=re.M,
)

lines = (
    "            isMinifyEnabled = false\n            isShrinkResources = false\n"
    if is_kts
    else "            minifyEnabled false\n            shrinkResources false\n"
)

text, n = re.subn(r"(\brelease\s*\{[ \t]*\n)", lambda m: m.group(1) + lines, text, count=1)
if n != 1:
    sys.exit("no encontré el bloque buildTypes { release { ... } }")

open(path, "w", encoding="utf-8").write(text)
print(f"{os.path.basename(path)}: R8 desactivado en release")

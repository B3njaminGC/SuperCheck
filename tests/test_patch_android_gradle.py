"""Pruebas de tools/patch_android_gradle.py (apaga R8 en el APK release).

Con R8 activo, la cámara del escáner dejaba de funcionar: esta regla no puede romperse.
"""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "patch_android_gradle.py"

KTS = """android {
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}
"""

GROOVY = """android {
    buildTypes {
        release {
            signingConfig signingConfigs.debug
            minifyEnabled true
        }
    }
}
"""


def run_script(filename, text):
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / filename
        path.write_text(text, encoding="utf-8")
        result = subprocess.run(
            [sys.executable, str(SCRIPT), folder], capture_output=True, text=True
        )
        return result, path.read_text(encoding="utf-8")


class PatchGradleTest(unittest.TestCase):
    def test_kotlin_apaga_el_ofuscado_y_la_compactacion(self):
        result, text = run_script("build.gradle.kts", KTS)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("isMinifyEnabled = false", text)
        self.assertIn("isShrinkResources = false", text)
        self.assertNotIn("= true", text)

    def test_groovy_apaga_el_ofuscado_y_la_compactacion(self):
        result, text = run_script("build.gradle", GROOVY)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("minifyEnabled false", text)
        self.assertIn("shrinkResources false", text)
        self.assertNotIn("minifyEnabled true", text)

    def test_conserva_el_resto_de_la_configuracion(self):
        _, text = run_script("build.gradle.kts", KTS)
        self.assertIn('signingConfig = signingConfigs.getByName("debug")', text)

    def test_los_ajustes_quedan_dentro_del_bloque_release(self):
        _, text = run_script("build.gradle.kts", KTS)
        self.assertLess(text.index("release {"), text.index("isMinifyEnabled = false"))

    def test_falla_si_no_hay_archivo_de_gradle(self):
        with tempfile.TemporaryDirectory() as folder:
            result = subprocess.run(
                [sys.executable, str(SCRIPT), folder], capture_output=True, text=True
            )
        self.assertNotEqual(result.returncode, 0)

    def test_falla_si_no_encuentra_el_bloque_release(self):
        result, _ = run_script("build.gradle.kts", "android { }\n")
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()

"""Pruebas de tools/patch_android_manifest.py (permisos y nombre de la app)."""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "patch_android_manifest.py"

# Lo mínimo de lo que genera `flutter create` para Android.
SAMPLE = """<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="supercheck"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
    </application>
</manifest>
"""


def run_script(text):
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / "AndroidManifest.xml"
        path.write_text(text, encoding="utf-8")
        result = subprocess.run(
            [sys.executable, str(SCRIPT), str(path)], capture_output=True, text=True
        )
        return result, path.read_text(encoding="utf-8")


class PatchManifestTest(unittest.TestCase):
    def test_agrega_los_permisos_que_la_app_necesita(self):
        result, text = run_script(SAMPLE)
        self.assertEqual(result.returncode, 0, result.stderr)
        for permission in ("INTERNET", "CAMERA", "REQUEST_INSTALL_PACKAGES"):
            self.assertIn(f"android.permission.{permission}", text)

    def test_la_camara_no_es_obligatoria(self):
        _, text = run_script(SAMPLE)
        self.assertIn('android.hardware.camera" android:required="false"', text)

    def test_pone_el_nombre_visible(self):
        _, text = run_script(SAMPLE)
        self.assertIn('android:label="SuperCheck"', text)
        self.assertNotIn('android:label="supercheck"', text)

    def test_correrlo_dos_veces_no_duplica_permisos(self):
        _, once = run_script(SAMPLE)
        _, twice = run_script(once)
        self.assertEqual(twice.count("android.permission.INTERNET"), 1)
        self.assertEqual(twice.count("android.permission.REQUEST_INSTALL_PACKAGES"), 1)

    def test_falla_si_el_manifest_no_tiene_el_formato_esperado(self):
        result, _ = run_script("<manifest></manifest>\n")
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()

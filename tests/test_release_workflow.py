"""Reglas del flujo de publicación de las que depende el aviso de actualización de la app.

La app compara el número de la etiqueta `app-N` de la última release con su propio número de
compilación y baja el archivo `SuperCheck.apk`. Si el flujo o la app cambian uno de esos
nombres por separado, las actualizaciones dentro de la app dejan de funcionar sin avisar.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = (ROOT / ".github" / "workflows" / "apk.yml").read_text(encoding="utf-8")
CHECKER = (ROOT / "lib" / "features" / "update" / "update_checker.dart").read_text(
    encoding="utf-8"
)
MANIFEST_PATCH = (ROOT / "tools" / "patch_android_manifest.py").read_text(encoding="utf-8")


class ReleaseWorkflowTest(unittest.TestCase):
    def test_el_numero_de_compilacion_es_el_numero_de_ejecucion(self):
        self.assertIn("--build-number=${{ github.run_number }}", WORKFLOW)

    def test_la_etiqueta_es_app_numero_de_ejecucion(self):
        self.assertIn('tag="app-${GITHUB_RUN_NUMBER}"', WORKFLOW)

    def test_la_app_entiende_esa_etiqueta(self):
        self.assertIn(r"^app-(\d+)$", CHECKER)

    def test_el_archivo_publicado_se_llama_como_lo_busca_la_app(self):
        self.assertIn("gh release create \"$tag\" SuperCheck.apk", WORKFLOW)
        self.assertIn("a['name'] == 'SuperCheck.apk'", CHECKER)

    def test_el_apk_se_firma_con_la_llave_de_los_secretos(self):
        for secret in ("ANDROID_KEYSTORE_BASE64", "ANDROID_KEYSTORE_PASSWORD"):
            self.assertIn(f"secrets.{secret}", WORKFLOW)

    def test_no_hay_llaves_de_firma_en_el_repositorio(self):
        found = [
            p.name
            for p in ROOT.rglob("*")
            if p.is_file()
            and ".git" not in p.parts
            and p.suffix in {".keystore", ".jks", ".p12", ".pem"}
        ]
        self.assertEqual(found, [])

    def test_el_manifest_pide_el_permiso_para_instalar_actualizaciones(self):
        self.assertIn("REQUEST_INSTALL_PACKAGES", MANIFEST_PATCH)

    def test_el_flujo_de_publicacion_comprueba_la_firma(self):
        self.assertTrue(re.search(r"verify --print-certs", WORKFLOW))


if __name__ == "__main__":
    unittest.main()

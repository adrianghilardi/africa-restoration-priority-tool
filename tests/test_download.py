"""Network-free tests of download integrity and safe reuse."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("climate_download", Path(__file__).resolve().parents[1] / "scripts/00_download_climate.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class DownloadTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "raw").mkdir()
        self.data = b"CDF\x01small-test-payload"
        self.row = {"key":"data/test.nc", "bytes":len(self.data), "etag":hashlib.md5(self.data).hexdigest(), "url":"https://example.invalid/test.nc"}

    def tearDown(self):
        self.tmp.cleanup()

    def test_verified_reuse(self):
        p = self.root / "raw/test.nc"
        p.write_bytes(self.data)
        old = {"test.nc":{"sha256":mod.sha256(p), "etag":self.row["etag"], "downloaded_utc":"test"}}
        with patch.object(mod, "urlopen", side_effect=AssertionError("Network should not be used")):
            self.assertEqual(mod.download(self.row, self.root, old)["downloaded_utc"], "test")

    def test_unknown_existing_file_is_preserved(self):
        p = self.root / "raw/test.nc"
        p.write_bytes(self.data)
        with self.assertRaisesRegex(RuntimeError, "matching provenance"):
            mod.download(self.row, self.root, {})
        self.assertEqual(p.read_bytes(), self.data)

    def test_different_size_is_preserved(self):
        p = self.root / "raw/test.nc"
        p.write_bytes(b"other")
        with self.assertRaisesRegex(RuntimeError, "Refusing to overwrite"):
            mod.download(self.row, self.root, {})
        self.assertEqual(p.read_bytes(), b"other")

    def test_changed_etag_is_rejected(self):
        p = self.root / "raw/test.nc"
        p.write_bytes(self.data)
        old = {"test.nc":{"sha256":mod.sha256(p), "etag":"different", "downloaded_utc":"test"}}
        with self.assertRaisesRegex(RuntimeError, "matching provenance"):
            mod.download(self.row, self.root, old)


if __name__ == "__main__":
    unittest.main()

import importlib.util
import json
import os
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("make_patches", ROOT / "tool" / "make_patches.py")
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class MakePatchesTest(unittest.TestCase):
    def write_json(self, path, value):
        Path(path).write_text(json.dumps(value), encoding="utf-8")

    def run_manifest(self, manifest, result, version=10):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest_path, result_path = root / "manifest.json", root / "result.json"
            apk, output = root / "new.apk", root / "update.json"
            apk.write_bytes(b"new-apk")
            self.write_json(manifest_path, manifest)
            self.write_json(result_path, result)
            args = MODULE.argparse.Namespace(
                manifest=str(manifest_path), result=str(result_path), new_apk=str(apk),
                version_code=str(version), version_name=f"1.0.{version}",
                apk_url=f"{MODULE.PREFIX}v1.0.{version}/app-release.apk",
                apk_sha256=MODULE.sha256_file(apk),
                release_prefix=f"{MODULE.PREFIX}v1.0.{version}/", output=str(output))
            self.assertEqual(MODULE.do_manifest(args), 0)
            return json.loads(output.read_text(encoding="utf-8"))

    def test_history_seeding_and_drop_newer_entries(self):
        manifest = {
            "versionCode": 10,
            "apkUrl": f"{MODULE.PREFIX}v1.0.10/app-release.apk",
            "sha256": "a" * 64,
            "history": [
                {"versionCode": 12, "apkUrl": f"{MODULE.PREFIX}v1.0.12/app-release.apk", "sha256": "b" * 64},
                {"versionCode": 9, "apkUrl": f"{MODULE.PREFIX}v1.0.9/app-release.apk", "sha256": "c" * 64},
            ],
        }
        self.assertEqual([x["versionCode"] for x in MODULE.candidates(manifest, 11)], [10, 9])
        self.assertEqual(MODULE.candidates({"versionCode": 10, "apkUrl": f"{MODULE.PREFIX}v1.0.10/app-release.apk", "sha256": "a" * 64}, 11)[0]["versionCode"], 10)

    def test_replacing_same_version_and_trimming_to_five(self):
        history = [
            {"versionCode": i, "apkUrl": f"{MODULE.PREFIX}v1.0.{i}/app-release.apk", "sha256": str(i) * 64}
            for i in range(2, 7)
        ]
        history.append({"versionCode": 7, "apkUrl": f"{MODULE.PREFIX}v1.0.7/app-release.apk", "sha256": "7" * 64})
        out = self.run_manifest(
            {"versionCode": 7, "versionName": "1.0.7", "apkUrl": history[0]["apkUrl"], "sha256": "a" * 64, "history": history},
            {"patches": [], "skipped": []}, version=7)
        self.assertEqual(len(out["history"]), 5)
        self.assertEqual(out["history"][0]["versionCode"], 7)
        self.assertEqual(out["history"][0]["sha256"], out["sha256"])
        self.assertEqual(len({x["versionCode"] for x in out["history"]}), 5)

    def test_legacy_fields_use_highest_base(self):
        out = self.run_manifest(
            {"versionCode": 84, "versionName": "1.0.84", "apkUrl": f"{MODULE.PREFIX}quick-v1.0.84/app-release.apk", "sha256": "c" * 64},
            {"patches": [
                {"baseVersionCode": 82, "baseSha256": "2" * 64, "sha256": "a" * 64, "size": 20},
                {"baseVersionCode": 84, "baseSha256": "4" * 64, "sha256": "b" * 64, "size": 10},
            ], "skipped": []}, version=85)
        self.assertEqual(out["patchBaseVersionCode"], 84)
        self.assertTrue(out["patchUrl"].endswith("/patch-from-84.bin"))
        self.assertEqual(out["patchSha256"], "b" * 64)

    def test_legacy_fields_null_without_patches(self):
        out = self.run_manifest(
            {"versionCode": 84, "versionName": "1.0.84", "apkUrl": f"{MODULE.PREFIX}quick-v1.0.84/app-release.apk", "sha256": "c" * 64},
            {"patches": [], "skipped": []}, version=85)
        self.assertIsNone(out["patchUrl"])
        self.assertIsNone(out["patchSha256"])
        self.assertIsNone(out["patchBaseVersionCode"])

    def test_seventy_percent_threshold(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            new_apk = root / "new.apk"
            new_apk.write_bytes(b"0123456789")
            candidate = {"versionCode": 8, "apkUrl": "https://example.invalid/old.apk", "sha256": MODULE.sha256_file(new_apk)}
            old = Path("old-8.apk")
            patch = Path("patch-from-8.bin")
            rebuilt = Path("reconstructed-8.apk")

            def fake_run(args, timeout):
                if args[0] == "curl":
                    old.write_bytes(new_apk.read_bytes())
                elif "build_patch.dart" in args:
                    patch.write_bytes(b"1234567")
                elif "validate_patch.dart" in args:
                    rebuilt.write_bytes(new_apk.read_bytes())
                return mock.Mock(returncode=0)

            old_cwd = os.getcwd()
            os.chdir(root)
            try:
                with mock.patch.object(MODULE, "run", side_effect=fake_run):
                    kept, skipped = MODULE.build_one(candidate, new_apk, MODULE.sha256_file(new_apk), time.monotonic())
            finally:
                os.chdir(old_cwd)
            self.assertIsNone(kept)
            self.assertIn("70%", skipped["reason"])

    def test_base_sha_mismatch_is_skipped(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            new_apk = root / "new.apk"
            new_apk.write_bytes(b"new")
            candidate = {"versionCode": 8, "apkUrl": "https://example.invalid/old.apk", "sha256": "0" * 64}
            old = Path("old-8.apk")

            def fake_run(args, timeout):
                old.write_bytes(b"wrong-old")
                return mock.Mock(returncode=0)

            old_cwd = os.getcwd()
            os.chdir(root)
            try:
                with mock.patch.object(MODULE, "run", side_effect=fake_run):
                    kept, skipped = MODULE.build_one(candidate, new_apk, MODULE.sha256_file(new_apk), time.monotonic())
            finally:
                os.chdir(old_cwd)
            self.assertIsNone(kept)
            self.assertIn("sha256 mismatch", skipped["reason"])

    def test_build_never_raises(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            output = root / "result.json"
            args = MODULE.argparse.Namespace(
                manifest=str(root / "missing.json"), new_apk=str(root / "missing.apk"),
                new_version_code="10", output=str(output))
            self.assertEqual(MODULE.do_build(args), 0)
            self.assertIn("skipped", json.loads(output.read_text(encoding="utf-8")))


if __name__ == "__main__":
    unittest.main()

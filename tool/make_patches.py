#!/usr/bin/env python3
"""Best-effort incremental APK patch builder and update.json writer."""
from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import os
import subprocess
import time
from pathlib import Path

PREFIX = "https://github.com/alhmeemzool-ops/phonek-app/releases/download/"
BUDGET = 20 * 60


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_json(path):
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else {}
    except Exception:
        return {}


def candidates(manifest, new_code):
    history = manifest.get("history")
    if not isinstance(history, list):
        history = [{"versionCode": manifest.get("versionCode"),
                    "apkUrl": manifest.get("apkUrl"),
                    "sha256": manifest.get("sha256")}]
    out = []
    for item in history:
        if not isinstance(item, dict):
            continue
        try:
            code = int(item["versionCode"])
        except (KeyError, TypeError, ValueError):
            continue
        if code >= new_code:
            continue
        url, digest = item.get("apkUrl"), item.get("sha256")
        if (not isinstance(url, str) or not url.startswith(PREFIX) or
                not isinstance(digest, str) or len(digest) != 64):
            continue
        out.append({"versionCode": code, "apkUrl": url, "sha256": digest.lower()})
    out.sort(key=lambda x: x["versionCode"], reverse=True)
    return out[:max(0, int(os.environ.get("PHONEK_MAX_PATCH_BASES", "2")))]


def run(cmd, timeout):
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True, check=False, timeout=timeout)


def build_one(item, new_apk, new_sha, started):
    base = int(item["versionCode"])
    old = Path(f"old-{base}.apk")
    patch = Path(f"patch-from-{base}.bin")
    rebuilt = Path(f"reconstructed-{base}.apk")
    began = time.monotonic()
    old_size = 0
    try:
        if time.monotonic() - started >= BUDGET:
            return None, {"baseVersionCode": base, "reason": "20-minute budget exceeded"}
        p = run(["curl", "-fL", "--retry", "5", "--retry-delay", "3",
                 "--retry-all-errors", "-o", str(old), item["apkUrl"]], 900)
        if p.returncode or not old.exists():
            return None, {"baseVersionCode": base, "reason": f"download failed (exit {p.returncode})"}
        old_size = old.stat().st_size
        if sha256_file(old) != item["sha256"]:
            return None, {"baseVersionCode": base, "reason": "base APK sha256 mismatch"}
        if time.monotonic() - started >= BUDGET:
            return None, {"baseVersionCode": base, "reason": "20-minute budget exceeded"}
        p = run(["timeout", "900", "dart", "run", "tool/build_patch.dart",
                 str(old), str(new_apk), str(patch)], 915)
        if p.returncode or not patch.exists() or patch.stat().st_size == 0:
            return None, {"baseVersionCode": base, "reason": f"patch build failed (exit {p.returncode})"}
        p = run(["timeout", "900", "dart", "run", "tool/validate_patch.dart",
                 str(old), str(patch), str(rebuilt)], 915)
        if p.returncode or not rebuilt.exists():
            return None, {"baseVersionCode": base, "reason": f"patch validation failed (exit {p.returncode})"}
        if sha256_file(rebuilt) != new_sha:
            return None, {"baseVersionCode": base, "reason": "reconstructed APK sha256 differs from new APK"}
        patch_size, new_size = patch.stat().st_size, new_apk.stat().st_size
        ratio = patch_size / new_size
        if ratio > 0.70:
            return None, {"baseVersionCode": base, "reason": f"patch ratio {ratio * 100:.2f}% exceeds 70%"}
        return {
            "baseVersionCode": base, "baseSha256": item["sha256"],
            "file": str(patch), "sha256": sha256_file(patch), "size": patch_size,
            "_oldSize": old_size, "_newSize": new_size,
            "_seconds": time.monotonic() - began,
        }, None
    except Exception as exc:
        return None, {"baseVersionCode": base, "reason": f"exception: {exc}"}
    finally:
        for p in (old, rebuilt):
            try:
                p.unlink()
            except FileNotFoundError:
                pass
            except Exception:
                pass
        if patch.exists():
            try:
                if not patch.stat().st_size or not (patch.name.startswith("patch-from-") and not patch.name.endswith(".bin.tmp")):
                    patch.unlink()
            except Exception:
                pass


def write_summary(rows):
    target = os.environ.get("GITHUB_STEP_SUMMARY")
    if not target:
        return
    lines = [
        "## PhoneK incremental patch table", "",
        "| base | old APK size | new APK size | patch size | ratio % | seconds | status/reason |",
        "|---:|---:|---:|---:|---:|---:|---|",
    ]
    for row in rows:
        if "_oldSize" in row:
            lines.append(f"| {row['baseVersionCode']} | {row['_oldSize']} | {row['_newSize']} | "
                         f"{row['size']} | {row['size'] / row['_newSize'] * 100:.2f} | "
                         f"{row['_seconds']:.1f} | kept |")
        else:
            lines.append(f"| {row.get('baseVersionCode', '—')} | — | — | — | — | — | {row['reason']} |")
    Path(target).write_text("\n".join(lines) + "\n", encoding="utf-8")


def do_build(args):
    result = {"patches": [], "skipped": []}
    rows = []
    started = time.monotonic()
    try:
        manifest = read_json(args.manifest)
        new_apk = Path(args.new_apk)
        new_sha = sha256_file(new_apk)
        items = candidates(manifest, int(args.new_version_code))
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures = []
            for item in items:
                if time.monotonic() - started >= BUDGET:
                    result["skipped"].append({"baseVersionCode": item["versionCode"], "reason": "20-minute budget exceeded"})
                    continue
                futures.append(pool.submit(build_one, item, new_apk, new_sha, started))
            for future in futures:
                kept, skipped = future.result()
                if kept:
                    result["patches"].append(kept)
                    rows.append(kept)
                elif skipped:
                    result["skipped"].append(skipped)
                    rows.append(skipped)
        result["patches"].sort(key=lambda x: x["baseVersionCode"], reverse=True)
    except Exception as exc:
        result["skipped"].append({"baseVersionCode": None, "reason": f"script exception: {exc}"})
    finally:
        Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        write_summary(rows)
    return 0


def do_manifest(args):
    current = read_json(args.manifest)
    result = read_json(args.result)
    new_code = int(args.version_code)
    apk_url = args.apk_url
    patches = []
    for item in result.get("patches", []):
        if not isinstance(item, dict):
            continue
        base = int(item["baseVersionCode"])
        url = f"{args.release_prefix}patch-from-{base}.bin"
        assert url.startswith(PREFIX)
        patches.append({
            "baseVersionCode": base,
            "baseSha256": str(item["baseSha256"]).lower(),
            "url": url,
            "sha256": str(item["sha256"]).lower(),
            "size": int(item["size"]),
        })
    patches.sort(key=lambda x: x["baseVersionCode"], reverse=True)

    old_history = current.get("history")
    if not isinstance(old_history, list):
        old_history = [{"versionCode": current.get("versionCode"),
                        "apkUrl": current.get("apkUrl"),
                        "sha256": current.get("sha256")}]
    history = []
    replaced = False
    for item in old_history:
        if not isinstance(item, dict):
            continue
        try:
            code = int(item["versionCode"])
        except (KeyError, TypeError, ValueError):
            continue
        if code == new_code:
            if not replaced:
                history.append({"versionCode": new_code, "apkUrl": apk_url, "sha256": args.apk_sha256})
                replaced = True
            continue
        if isinstance(item.get("apkUrl"), str) and isinstance(item.get("sha256"), str):
            history.append({"versionCode": code, "apkUrl": item["apkUrl"], "sha256": item["sha256"].lower()})
    if not replaced:
        history.append({"versionCode": new_code, "apkUrl": apk_url, "sha256": args.apk_sha256})
    history.sort(key=lambda x: x["versionCode"], reverse=True)
    history = history[:5]

    legacy = patches[0] if patches else None
    output = {
        "versionCode": new_code,
        "versionName": args.version_name,
        "apkUrl": apk_url,
        "sha256": args.apk_sha256.lower(),
        "patchUrl": legacy["url"] if legacy else None,
        "patchSha256": legacy["sha256"] if legacy else None,
        "patchBaseVersionCode": legacy["baseVersionCode"] if legacy else None,
        "minSupportedVersionCode": current.get("minSupportedVersionCode", 58),
        "mandatory": current.get("mandatory", False),
        "notes": current.get("notes", ""),
        "apkSize": Path(args.new_apk).stat().st_size,
        "patches": patches,
        "history": history,
    }
    Path(args.output).write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    b = sub.add_parser("build")
    b.add_argument("--manifest", required=True)
    b.add_argument("--new-apk", required=True)
    b.add_argument("--new-version-code", required=True)
    b.add_argument("--output", default="patch-results.json")
    m = sub.add_parser("manifest")
    m.add_argument("--manifest", required=True)
    m.add_argument("--result", required=True)
    m.add_argument("--new-apk", required=True)
    m.add_argument("--version-code", required=True)
    m.add_argument("--version-name", required=True)
    m.add_argument("--apk-url", required=True)
    m.add_argument("--apk-sha256", required=True)
    m.add_argument("--release-prefix", required=True)
    m.add_argument("--output", default="update.json")
    args = parser.parse_args()
    try:
        return do_build(args) if args.command == "build" else do_manifest(args)
    except Exception:
        return 0


if __name__ == "__main__":
    raise SystemExit(main())

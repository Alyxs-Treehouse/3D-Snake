#!/usr/bin/env python3
"""Inspect the built APK's signature, architecture, runtime libraries and manifest."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import zipfile
import argparse
import re

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument("--apk", type=Path, default=root / "builds/spatial-snake.apk")
parser.add_argument("--promote", type=Path)
options = parser.parse_args()
apk = options.apk
sdk = Path(os.environ.get("SNAKE_ANDROID_SDK", Path.home() / "Library/Android/sdk"))
jdk = Path(os.environ.get("SNAKE_JAVA_HOME", Path.home() / "Library/Java/JavaVirtualMachines/microsoft-17.jdk/Contents/Home"))
build_tools = sdk / "build-tools/34.0.0"
environment = dict(os.environ, JAVA_HOME=str(jdk))

def run(*args):
    return subprocess.check_output([str(a) for a in args], text=True, env=environment)

badging = run(build_tools / "aapt", "dump", "badging", apk)
manifest = run(build_tools / "aapt", "dump", "xmltree", apk, "AndroidManifest.xml")
signature = run(build_tools / "apksigner", "verify", "--verbose", apk)
assert "package: name='com.xuanyu.spatialsnake'" in badging
presets = (root / "export_presets.cfg").read_text()
version_name = re.search(r'version/name="([^"]+)"', presets).group(1)
version_code = re.search(r'version/code=(\d+)', presets).group(1)
assert f"versionName='{version_name}'" in badging
assert f"versionCode='{version_code}'" in badging
assert "native-code: 'arm64-v8a'" in badging
assert "sdkVersion:'29'" in badging and "targetSdkVersion:'34'" in badging
assert "android.permission.RECORD_AUDIO" in badging
assert 'handtracking' in manifest
with zipfile.ZipFile(apk) as archive:
    names = set(archive.namelist())
    required = {"lib/arm64-v8a/" + name for name in [
        "libgodot_android.so", "libopenxr_loader.so", "libgodotopenxrvendors.so",
    ]}
    assert required <= names, f"Missing runtime libraries: {required - names}"
    assert not any(n.startswith(("assets/tests/", "assets/tools/")) for n in names), "Development scripts leaked into APK"
    assert not any(n.startswith("lib/") and not n.startswith("lib/arm64-v8a/") for n in names)
if options.promote:
    apk.replace(options.promote)
    apk = options.promote
report = {
    "apk": str(apk),
    "bytes": apk.stat().st_size,
    "sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
    "package": "com.xuanyu.spatialsnake",
    "version_name": version_name,
    "version_code": int(version_code),
    "abi": "arm64-v8a",
    "min_sdk": 29,
    "target_sdk": 34,
    "pico_loader_present": True,
    "handtracking_manifest_present": True,
    "record_audio_permission_present": True,
    "signature_verified": True,
    "device_tested": False,
}
(root / "builds/apk-verification.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))

#!/usr/bin/env python3
"""Inspect the built APK's signature, architecture, runtime libraries and manifest."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import zipfile

root = Path(__file__).resolve().parent.parent
apk = root / "builds/spatial-snake.apk"
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
    assert not any(n.startswith("lib/") and not n.startswith("lib/arm64-v8a/") for n in names)
report = {
    "apk": str(apk),
    "bytes": apk.stat().st_size,
    "sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
    "package": "com.xuanyu.spatialsnake",
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

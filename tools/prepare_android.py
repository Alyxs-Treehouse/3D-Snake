#!/usr/bin/env python3
"""Restore the engine's Android Gradle template from its installed export templates."""
from pathlib import Path
import zipfile
import os
import re
import shutil
import json
import sys

root = Path(__file__).resolve().parent.parent
godot_data = Path.home() / "Library/Application Support/Godot" if sys.platform == "darwin" else Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "godot"
version = (root / ".godot-version").read_text().strip()
templates = Path(os.environ.get("SNAKE_GODOT_TEMPLATES", godot_data / "export_templates" / version))
source = templates / "android_source.zip"
build = root / "android/build"
if not source.exists():
    raise SystemExit(f"Install Godot 4.4.1 export templates first: {source}")
if not (build / "build.gradle").exists():
    build.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(source) as archive:
        archive.extractall(build)
    print("Restored Godot 4.4.1 Android build template")
(build / "gradlew").chmod(0o755)
(root / "android/.gdignore").touch()
(root / "android/.build_version").write_text("4.4.1.stable\n")
wrapper = build / "gradle/wrapper/gradle-wrapper.properties"
wrapper_text = wrapper.read_text()
if "distributionSha256Sum=" not in wrapper_text:
    wrapper.write_text(wrapper_text + "\ndistributionSha256Sum=38f66cd6eef217b4c35855bb11ea4e9fbc53594ccccb5fb82dfd317ef8c2c5a3\n")

if "--configure-editor" in __import__("sys").argv:
    settings = godot_data / "editor_settings-4.4.tres"
    if not settings.exists():
        settings.parent.mkdir(parents=True, exist_ok=True)
        settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n')
    backup = root / ".cache/editor_settings-4.4.before-xr.tres"
    backup.parent.mkdir(exist_ok=True)
    if not backup.exists():
        shutil.copy2(settings, backup)
    text = settings.read_text()
    paths = {
        "java_sdk_path": os.environ["SNAKE_JAVA_HOME"],
        "android_sdk_path": os.environ["SNAKE_ANDROID_SDK"],
    }
    for key, path in paths.items():
        line = f"export/android/{key} = {json.dumps(path, ensure_ascii=False)}"
        pattern = rf"^export/android/{key} = .*?$"
        if re.search(pattern, text, flags=re.M):
            text = re.sub(pattern, lambda _: line, text, flags=re.M)
        else:
            text = text.replace("[resource]\n", "[resource]\n" + line + "\n", 1)
    settings.write_text(text)
    print("Configured Godot Java and Android SDK paths; original settings backed up")

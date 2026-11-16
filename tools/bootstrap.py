#!/usr/bin/env python3
"""Install pinned third-party artifacts. All downloads are hash-checked before extraction."""
import argparse
import hashlib
import json
import shutil
import stat
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCK = json.loads((ROOT / "dependencies.lock.json").read_text())
CACHE = ROOT / ".cache/downloads"


def download(spec, algorithm="sha256"):
    CACHE.mkdir(parents=True, exist_ok=True)
    (ROOT / ".cache/.gdignore").touch()
    archive = CACHE / spec["url"].rsplit("/", 1)[-1]
    expected = spec[algorithm]
    if not archive.exists() or hashlib.new(algorithm, archive.read_bytes()).hexdigest() != expected:
        partial = archive.with_suffix(".partial")
        print(f"Downloading {archive.name}", flush=True)
        with urllib.request.urlopen(spec["url"], timeout=60) as source, partial.open("wb") as output:
            shutil.copyfileobj(source, output)
        if hashlib.new(algorithm, partial.read_bytes()).hexdigest() != expected:
            partial.unlink()
            raise RuntimeError(f"Checksum mismatch for {archive.name}")
        partial.replace(archive)
    return archive


def install_vendors():
    spec = LOCK["openxr_vendors"]
    target = ROOT / "addons/godotopenxrvendors"
    marker = target / ".installed-sha256"
    if marker.exists() and marker.read_text().strip() == spec["sha256"]:
        if (target / "plugin.gdextension").exists():
            print("OpenXR Vendors already installed at pinned version")
            return
    archive = download(spec)
    with zipfile.ZipFile(archive) as package:
        prefix = "asset/addons/godotopenxrvendors/"
        members = [entry for entry in package.infolist() if entry.filename.startswith(prefix)]
        if not members:
            raise RuntimeError("Archive lacks expected addon directory")
        for entry in members:
            destination = (target / entry.filename[len(prefix):]).resolve()
            if not destination.is_relative_to(target.resolve()):
                raise RuntimeError("Archive path escapes addon directory")
            if stat.S_ISLNK(entry.external_attr >> 16):
                raise RuntimeError("Unexpected archive symlink")
            if entry.is_dir():
                destination.mkdir(parents=True, exist_ok=True)
            else:
                destination.parent.mkdir(parents=True, exist_ok=True)
                with package.open(entry) as source, destination.open("wb") as output:
                    shutil.copyfileobj(source, output)
                destination.chmod((entry.external_attr >> 16) & 0o777 or 0o644)
    marker.write_text(spec["sha256"] + "\n")
    print("Installed OpenXR Vendors " + spec["version"])


def install_linux_engine():
    archive = download(LOCK["godot_linux"], "sha512")
    target = ROOT / ".cache/godot"
    target.mkdir(exist_ok=True)
    name = "Godot_v4.4.1-stable_linux.x86_64"
    with zipfile.ZipFile(archive) as package:
        with package.open(name) as source, (target / name).open("wb") as output:
            shutil.copyfileobj(source, output)
    (target / name).chmod(0o755)
    print(target / name)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--linux-engine", action="store_true")
    options = parser.parse_args()
    install_vendors()
    if options.linux_engine:
        install_linux_engine()

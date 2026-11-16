#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${SNAKE_GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
SDK_DIR="${SNAKE_ANDROID_SDK:-$HOME/Library/Android/sdk}"
JDK_DIR="${SNAKE_JAVA_HOME:-$HOME/Library/Java/JavaVirtualMachines/microsoft-17.jdk/Contents/Home}"
APK_PATH="$PROJECT_DIR/builds/spatial-snake.apk"
PACKAGE_NAME="com.xuanyu.spatialsnake"
ADB_BIN="$SDK_DIR/platform-tools/adb"

cd "$PROJECT_DIR"
case "${1:-help}" in
  prepare)
    export SNAKE_JAVA_HOME="$JDK_DIR"
    export SNAKE_ANDROID_SDK="$SDK_DIR"
    python3 "$PROJECT_DIR/tools/prepare_android.py" --configure-editor
    if [[ ! -f "$PROJECT_DIR/openxr_action_map.tres" ]]; then
      "$GODOT_BIN" --headless --xr-mode off --path "$PROJECT_DIR" --script res://tools/configure_editor.gd
    fi
    ;;
  editor)
    exec "$GODOT_BIN" --editor --xr-mode off --path "$PROJECT_DIR"
    ;;
  preview)
    exec "$GODOT_BIN" --xr-mode off --path "$PROJECT_DIR"
    ;;
  lab)
    exec "$GODOT_BIN" --xr-mode off --path "$PROJECT_DIR" res://scenes/input_lab.tscn
    ;;
  screenshot)
    exec "$GODOT_BIN" --xr-mode off --path "$PROJECT_DIR" -- --capture-preview
    ;;
  check)
    mkdir -p "$PROJECT_DIR/builds"
    CHECK_LOG="$PROJECT_DIR/builds/validation.log"
    {
      "$GODOT_BIN" --headless --editor --xr-mode off --path "$PROJECT_DIR" --import --quit
      "$GODOT_BIN" --headless --xr-mode off --path "$PROJECT_DIR" --script res://tools/test_hand_input.gd
      "$GODOT_BIN" --headless --xr-mode off --path "$PROJECT_DIR" --script res://tools/test_snake.gd
      "$GODOT_BIN" --headless --xr-mode off --path "$PROJECT_DIR" --script res://tools/test_steering.gd
      "$GODOT_BIN" --headless --xr-mode off --path "$PROJECT_DIR" --script res://tools/test_walls.gd
      "$GODOT_BIN" --headless --xr-mode off --path "$PROJECT_DIR" --script res://tools/test_hold_motion.gd
      "$GODOT_BIN" --headless --xr-mode off --path "$PROJECT_DIR" --quit-after 120
    } 2>&1 | tee "$CHECK_LOG"
    # Godot can exit 0 after a script error; inspect diagnostics as well.
    if rg -q 'SCRIPT ERROR:|ERROR:|Parse Error:' "$CHECK_LOG"; then
      echo "Validation failed; inspect $CHECK_LOG" >&2
      exit 1
    fi
    ;;
  build)
    test -x "$JDK_DIR/bin/java" || { echo "Missing JDK 17: $JDK_DIR" >&2; exit 1; }
    mkdir -p "$PROJECT_DIR/builds" "$PROJECT_DIR/.cache/gradle"
    touch "$PROJECT_DIR/builds/.gdignore" "$PROJECT_DIR/.cache/.gdignore"
    export JAVA_HOME="$JDK_DIR"
    export ANDROID_HOME="$SDK_DIR"
    export GRADLE_USER_HOME="$PROJECT_DIR/.cache/gradle"
    python3 "$PROJECT_DIR/tools/prepare_android.py"
    "$GODOT_BIN" --headless --editor --xr-mode off --path "$PROJECT_DIR" --import --quit
    "$GODOT_BIN" --headless --xr-mode off --path "$PROJECT_DIR" --export-debug "PICO 4" "$APK_PATH"
    export SNAKE_JAVA_HOME="$JDK_DIR"
    export SNAKE_ANDROID_SDK="$SDK_DIR"
    python3 "$PROJECT_DIR/tools/verify_apk.py"
    ;;
  devices)
    exec "$ADB_BIN" devices -l
    ;;
  deploy)
    test -f "$APK_PATH" || { echo "Build first: ./tools/dev.sh build" >&2; exit 1; }
    if [[ -n "${2:-}" ]]; then
      DEVICE_ID="$2"
    else
      DEVICE_ID="$($ADB_BIN devices | awk 'NR>1 && $2=="device" {print $1}')"
      DEVICE_COUNT="$(printf '%s\n' "$DEVICE_ID" | awk 'NF {n++} END {print n+0}')"
      [[ "$DEVICE_COUNT" == 1 ]] || { echo "Connect and authorize ONE PICO 4, or provide its serial: ./tools/dev.sh deploy SERIAL" >&2; exit 1; }
    fi
    DEVICE_MODEL="$($ADB_BIN -s "$DEVICE_ID" shell getprop ro.product.model | tr -d '\r')"
    DEVICE_VENDOR="$($ADB_BIN -s "$DEVICE_ID" shell getprop ro.product.manufacturer | tr -d '\r')"
    if [[ "$DEVICE_VENDOR" != "Pico" && "$DEVICE_VENDOR" != "PICO" && "$DEVICE_VENDOR" != "pico" ]]; then
      echo "Refusing automatic install on unexpected device: $DEVICE_MODEL" >&2
      exit 1
    fi
    "$ADB_BIN" -s "$DEVICE_ID" install -r "$APK_PATH"
    exec "$ADB_BIN" -s "$DEVICE_ID" shell am start -n "$PACKAGE_NAME/com.godot.game.GodotApp"
    ;;
  *)
    echo "Usage: ./tools/dev.sh {prepare|editor|preview|lab|screenshot|check|build|devices|deploy [SERIAL]}"
    ;;
esac

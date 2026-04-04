#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_DIR="${ROOT_DIR}/tools/godot-linux"
GODOT_BIN="${GODOT_DIR}/Godot_v4.6.1-stable_linux.x86_64"
GODOT_ZIP_URL="https://github.com/godotengine/godot/releases/download/4.6.1-stable/Godot_v4.6.1-stable_linux.x86_64.zip"
PYTHON_BIN="${ROOT_DIR}/.venv-gui/bin/python"

mkdir -p "${GODOT_DIR}"

if [[ ! -x "${GODOT_BIN}" ]]; then
  tmp_zip="$(mktemp /tmp/godot-linux-XXXXXX.zip)"
  trap 'rm -f "${tmp_zip}"' EXIT
  echo "[setup] Downloading Godot Linux binary"
  curl -L -o "${tmp_zip}" "${GODOT_ZIP_URL}"
  echo "[setup] Extracting Godot"
  if command -v busybox >/dev/null 2>&1; then
    busybox unzip -o "${tmp_zip}" -d "${GODOT_DIR}"
  elif command -v unzip >/dev/null 2>&1; then
    unzip -o "${tmp_zip}" -d "${GODOT_DIR}"
  else
    python3 - <<PY
from zipfile import ZipFile
ZipFile("${tmp_zip}").extractall("${GODOT_DIR}")
PY
  fi
  chmod +x "${GODOT_BIN}"
fi

if [[ ! -x "${PYTHON_BIN}" ]]; then
  echo "[setup] Creating GUI automation venv"
  python3 -m venv "${ROOT_DIR}/.venv-gui"
fi

echo "[setup] Installing GUI automation packages"
"${PYTHON_BIN}" -m pip install pyautogui pillow python-xlib pyscreeze

echo "[setup] Done"
echo "[setup] Godot: ${GODOT_BIN}"
echo "[setup] Python: ${PYTHON_BIN}"

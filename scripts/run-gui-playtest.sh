#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON_BIN="${ROOT_DIR}/.venv-gui/bin/python"

if [[ ! -x "${PYTHON_BIN}" ]]; then
  echo "[gui-playtest] Missing ${PYTHON_BIN}" >&2
  echo "[gui-playtest] Create .venv-gui and install python-xlib + pillow first." >&2
  exit 1
fi

cd "${ROOT_DIR}"
exec "${PYTHON_BIN}" scripts/gui_playtest.py

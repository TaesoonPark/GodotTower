#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")/resolve-godot-path.sh"

GODOT_BIN="$(resolve_godot_path || true)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUNTIME_ROOT="${ROOT_DIR}/.godot-runtime"
if [[ -z "${GODOT_BIN}" ]]; then
  echo "[godot-mcp bootstrap] Godot executable not found." >&2
  echo "[godot-mcp bootstrap] Set GODOT_PATH or install Godot in /Applications." >&2
  exit 1
fi

export GODOT_PATH="${GODOT_BIN}"
export DEBUG="${DEBUG:-true}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-${RUNTIME_ROOT}/xdg-data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${RUNTIME_ROOT}/xdg-config}"
mkdir -p "${XDG_DATA_HOME}" "${XDG_CONFIG_HOME}"

exec npx -y @coding-solo/godot-mcp

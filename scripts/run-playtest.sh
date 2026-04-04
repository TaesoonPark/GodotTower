#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "${ROOT_DIR}/scripts/resolve-godot-path.sh"

SCENE_PATH="${1:-res://scenes/tests/RtsControlSmokeTest.tscn}"
TIMEOUT_SEC="${PLAYTEST_TIMEOUT_SEC:-90}"
GODOT_BIN="$(resolve_godot_path || true)"
RUNTIME_ROOT="${ROOT_DIR}/.godot-runtime"
export XDG_DATA_HOME="${XDG_DATA_HOME:-${RUNTIME_ROOT}/xdg-data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${RUNTIME_ROOT}/xdg-config}"

if [[ -z "${GODOT_BIN}" ]]; then
  echo "[playtest] Godot executable not found." >&2
  echo "[playtest] Set GODOT_PATH or install Godot." >&2
  exit 1
fi

mkdir -p "${XDG_DATA_HOME}" "${XDG_CONFIG_HOME}"

echo "[playtest] godot=${GODOT_BIN}"
echo "[playtest] scene=${SCENE_PATH}"
echo "[playtest] timeout=${TIMEOUT_SEC}s"

if ! command -v timeout >/dev/null 2>&1; then
  echo "[playtest] 'timeout' command not found." >&2
  exit 1
fi

set +e
timeout "${TIMEOUT_SEC}s" "${GODOT_BIN}" --path "${ROOT_DIR}" --headless "${SCENE_PATH}"
EXIT_CODE=$?
set -e

if [[ "${EXIT_CODE}" -eq 0 ]]; then
  echo "[playtest] PASS"
  exit 0
fi

if [[ "${EXIT_CODE}" -eq 124 ]]; then
  echo "[playtest] TIMEOUT" >&2
  exit 124
fi

echo "[playtest] FAIL (exit=${EXIT_CODE})" >&2
exit "${EXIT_CODE}"

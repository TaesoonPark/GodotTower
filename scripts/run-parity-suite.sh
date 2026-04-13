#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "${ROOT_DIR}/scripts/resolve-godot-path.sh"

GODOT_BIN="$(resolve_godot_path || true)"
RUNTIME_ROOT="${ROOT_DIR}/.godot-runtime"
export HOME="${HOME:-${RUNTIME_ROOT}/home}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-${RUNTIME_ROOT}/xdg-data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${RUNTIME_ROOT}/xdg-config}"

if [[ -z "${GODOT_BIN}" ]]; then
  echo "[parity-suite] Godot executable not found." >&2
  exit 1
fi

mkdir -p "${HOME}" "${XDG_DATA_HOME}" "${XDG_CONFIG_HOME}"

SCENES=(
  "res://scenes/tests/SystemParitySmokeTest.tscn"
  "res://scenes/tests/GatherHaulParitySmokeTest.tscn"
  "res://scenes/tests/BuildParitySmokeTest.tscn"
  "res://scenes/tests/CraftParitySmokeTest.tscn"
  "res://scenes/tests/ResearchParitySmokeTest.tscn"
  "res://scenes/tests/RepairParitySmokeTest.tscn"
  "res://scenes/tests/TrapMaintenanceParitySmokeTest.tscn"
  "res://scenes/tests/CombatParitySmokeTest.tscn"
)

run_scene() {
  local scene="$1"
  echo "[parity-suite] START ${scene}"
  set +e
  "${GODOT_BIN}" --path "${ROOT_DIR}" --headless "${scene}"
  local exit_code=$?
  set -e
  if [[ ${exit_code} -ne 0 ]]; then
    echo "[parity-suite] FAIL ${scene} exit=${exit_code}" >&2
    return "${exit_code}"
  fi
  echo "[parity-suite] PASS ${scene}"
}

for scene in "${SCENES[@]}"; do
  run_scene "${scene}"
done

echo "[parity-suite] ALL PASS"

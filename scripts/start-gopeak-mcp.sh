#!/usr/bin/env bash
set -euo pipefail

resolve_godot_path() {
  if [[ -n "${GODOT_PATH:-}" && -x "${GODOT_PATH}" ]]; then
    echo "${GODOT_PATH}"
    return 0
  fi

  local candidates=(
    "/Users/parkts/Downloads/Godot.app/Contents/MacOS/Godot"
    "/Applications/Godot.app/Contents/MacOS/Godot"
    "${HOME}/Applications/Godot.app/Contents/MacOS/Godot"
  )

  local c
  for c in "${candidates[@]}"; do
    if [[ -x "${c}" ]]; then
      echo "${c}"
      return 0
    fi
  done

  return 1
}

GODOT_BIN="$(resolve_godot_path || true)"
if [[ -z "${GODOT_BIN}" ]]; then
  echo "[gopeak bootstrap] Godot executable not found." >&2
  echo "[gopeak bootstrap] Set GODOT_PATH to your Godot binary." >&2
  exit 1
fi

export GODOT_PATH="${GODOT_BIN}"
export GOPEAK_TOOL_PROFILE="${GOPEAK_TOOL_PROFILE:-compact}"
export DEBUG="${DEBUG:-true}"

# Use npm exec with --ignore-scripts to avoid failing package postinstall hooks.
exec npm exec --yes --ignore-scripts --package gopeak gopeak

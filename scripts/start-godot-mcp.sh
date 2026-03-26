#!/usr/bin/env bash
set -euo pipefail

resolve_godot_path() {
  if [[ -n "${GODOT_PATH:-}" && -x "${GODOT_PATH}" ]]; then
    echo "${GODOT_PATH}"
    return 0
  fi

  local candidates=(
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

  local from_process
  from_process="$(ps aux 2>/dev/null | awk '{for(i=1;i<=NF;i++){if($i ~ /Godot\.app\/Contents\/MacOS\/Godot$/){print $i; exit}}}')"
  if [[ -n "${from_process}" && -x "${from_process}" ]]; then
    echo "${from_process}"
    return 0
  fi

  return 1
}

GODOT_BIN="$(resolve_godot_path || true)"
if [[ -z "${GODOT_BIN}" ]]; then
  echo "[godot-mcp bootstrap] Godot executable not found." >&2
  echo "[godot-mcp bootstrap] Set GODOT_PATH or install Godot in /Applications." >&2
  exit 1
fi

export GODOT_PATH="${GODOT_BIN}"
export DEBUG="${DEBUG:-true}"

exec npx -y @coding-solo/godot-mcp

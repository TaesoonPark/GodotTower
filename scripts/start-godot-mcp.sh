#!/usr/bin/env bash
set -euo pipefail

resolve_godot_path() {
  if [[ -n "${GODOT_PATH:-}" && -x "${GODOT_PATH}" ]]; then
    echo "${GODOT_PATH}"
    return 0
  fi

  local from_path
  for from_path in godot godot4 godot-mono; do
    if command -v "${from_path}" >/dev/null 2>&1; then
      command -v "${from_path}"
      return 0
    fi
  done

  local candidates=(
    "/Applications/Godot.app/Contents/MacOS/Godot"
    "${HOME}/Applications/Godot.app/Contents/MacOS/Godot"
    "/usr/bin/godot"
    "/usr/bin/godot4"
    "/usr/local/bin/godot"
    "/usr/local/bin/godot4"
    "${HOME}/bin/godot"
    "${HOME}/bin/godot4"
    "/mnt/c/Program Files/Godot/Godot_v4.6.1-stable_win64_console.exe"
    "/mnt/c/Program Files/Godot/Godot_v4.6.1-stable_win64.exe"
    "/mnt/c/Program Files/Godot/Godot_v4.6-stable_win64_console.exe"
    "/mnt/c/Program Files/Godot/Godot_v4.6-stable_win64.exe"
    "/mnt/d/Godot_v4.6.1-stable_win64/Godot_v4.6.1-stable_win64_console.exe"
    "/mnt/d/Godot_v4.6.1-stable_win64/Godot_v4.6.1-stable_win64.exe"
  )

  local c
  for c in "${candidates[@]}"; do
    if [[ -x "${c}" ]]; then
      echo "${c}"
      return 0
    fi
  done

  local from_process
  from_process="$(ps aux 2>/dev/null | awk '
    {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /Godot\.app\/Contents\/MacOS\/Godot$/ ||
            $i ~ /(^|\/)godot4?$/ ||
            $i ~ /Godot_v[0-9.]+-stable_win64(_console)?\.exe$/) {
          print $i
          exit
        }
      }
    }'
  )"
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

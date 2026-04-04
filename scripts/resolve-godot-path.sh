#!/usr/bin/env bash
set -euo pipefail

resolve_godot_path() {
  local script_dir repo_root
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  repo_root="$(cd "${script_dir}/.." && pwd)"

  if [[ -n "${GODOT_PATH:-}" && -x "${GODOT_PATH}" ]]; then
    echo "${GODOT_PATH}"
    return 0
  fi

  local local_candidates=(
    "${repo_root}/tools/godot-linux/Godot_v4.6.1-stable_linux.x86_64"
    "${repo_root}/tools/godot-linux/Godot_linux.x86_64"
  )

  local candidate
  for candidate in "${local_candidates[@]}"; do
    if [[ -x "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done

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
    "${HOME}/Downloads/Godot.app/Contents/MacOS/Godot"
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

  for candidate in "${candidates[@]}"; do
    if [[ -x "${candidate}" ]]; then
      echo "${candidate}"
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

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARTIFACT_DIR="${ROOT_DIR}/artifacts/self-check"
STAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="${ARTIFACT_DIR}/${STAMP}"
mkdir -p "${RUN_DIR}"

HEADLESS_LOG="${RUN_DIR}/headless.log"
RAID_LOG="${RUN_DIR}/raid.log"
GUI_LOG="${RUN_DIR}/gui.log"
SUMMARY_LOG="${RUN_DIR}/summary.txt"

CHANGED_FILES_RAW=""
if git -C "${ROOT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  CHANGED_FILES_RAW+="$(git -C "${ROOT_DIR}" diff --name-only HEAD 2>/dev/null || true)"$'\n'
  CHANGED_FILES_RAW+="$(git -C "${ROOT_DIR}" ls-files --others --exclude-standard 2>/dev/null || true)"
fi
CHANGED_FILES="$(printf '%s\n' "${CHANGED_FILES_RAW}" | sed '/^$/d' | sort -u)"

should_run_gui() {
  if [[ "${SELF_CHECK_GUI:-auto}" == "1" || "${SELF_CHECK_GUI:-auto}" == "true" ]]; then
    return 0
  fi
  if [[ "${SELF_CHECK_GUI:-auto}" == "0" || "${SELF_CHECK_GUI:-auto}" == "false" ]]; then
    return 1
  fi
  if [[ -z "${CHANGED_FILES}" ]]; then
    return 1
  fi
  while IFS= read -r path; do
    [[ -z "${path}" ]] && continue
    case "${path}" in
      scenes/ui/*|scripts/core/HUDController.gd|scripts/core/MainController.gd|scripts/gui_playtest.py|scripts/run-gui-playtest.sh|project.godot)
        return 0
        ;;
    esac
  done <<< "${CHANGED_FILES}"
  return 1
}

should_run_raid() {
  if [[ "${SELF_CHECK_RAID:-auto}" == "1" || "${SELF_CHECK_RAID:-auto}" == "true" ]]; then
    return 0
  fi
  if [[ "${SELF_CHECK_RAID:-auto}" == "0" || "${SELF_CHECK_RAID:-auto}" == "false" ]]; then
    return 1
  fi
  return 0
}

run_step() {
  local label="$1"
  local logfile="$2"
  shift 2
  echo "[self-check] START ${label}" | tee -a "${SUMMARY_LOG}"
  set +e
  (
    cd "${ROOT_DIR}"
    "$@"
  ) > >(tee "${logfile}") 2>&1
  local exit_code=$?
  set -e
  if [[ ${exit_code} -eq 0 ]]; then
    echo "[self-check] PASS ${label}" | tee -a "${SUMMARY_LOG}"
  else
    echo "[self-check] FAIL ${label} exit=${exit_code}" | tee -a "${SUMMARY_LOG}"
  fi
  return ${exit_code}
}

emit_feedback() {
  local label="$1"
  local logfile="$2"
  {
    echo ""
    echo "[feedback] ${label}"
    if [[ ! -f "${logfile}" ]]; then
      echo "- no log"
      return
    fi
    if rg -n "RTS_TEST_PASS|GUI_PLAYTEST_PASS|GUI_EVENT_BUILD_COMPLETED" "${logfile}" >/dev/null 2>&1; then
      echo "- success markers present"
    fi
    if rg -n "raid spawn failed" "${logfile}" >/dev/null 2>&1; then
      echo "- raid path regressed"
    fi
    if rg -n "colonists not spawned|single select failed|drag selection failed|move command failed|build site not registered" "${logfile}" >/dev/null 2>&1; then
      echo "- core RTS smoke regressed"
    fi
    if rg -n "GUI_PLAYTEST_FAIL|Timed out waiting for expected GUI playtest output" "${logfile}" >/dev/null 2>&1; then
      echo "- GUI route failed or stalled"
    fi
    if rg -n "GUI_PLAYTEST_WARN" "${logfile}" >/dev/null 2>&1; then
      echo "- GUI warnings present"
    fi
    if rg -n "Godot executable not found|Missing .*\\.venv-gui|Could not create directory" "${logfile}" >/dev/null 2>&1; then
      echo "- environment setup issue"
    fi
  } | tee -a "${SUMMARY_LOG}"
}

{
  echo "Self Check Run: ${STAMP}"
  echo "Run Dir: ${RUN_DIR}"
  echo "Changed Files:"
  if [[ -n "${CHANGED_FILES}" ]]; then
    printf '%s\n' "${CHANGED_FILES}"
  else
    echo "(none detected)"
  fi
  echo ""
} | tee "${SUMMARY_LOG}"

HEADLESS_STATUS=0
RAID_STATUS=0
GUI_STATUS=0

run_step "headless" "${HEADLESS_LOG}" bash scripts/run-playtest.sh || HEADLESS_STATUS=$?
emit_feedback "headless" "${HEADLESS_LOG}"

if should_run_raid; then
  run_step "raid" "${RAID_LOG}" env PLAYTEST_INCLUDE_RAID=1 bash scripts/run-playtest.sh || RAID_STATUS=$?
  emit_feedback "raid" "${RAID_LOG}"
else
  echo "[self-check] SKIP raid" | tee -a "${SUMMARY_LOG}"
fi

if should_run_gui; then
  run_step "gui" "${GUI_LOG}" bash scripts/run-gui-playtest.sh || GUI_STATUS=$?
  emit_feedback "gui" "${GUI_LOG}"
else
  echo "[self-check] SKIP gui" | tee -a "${SUMMARY_LOG}"
fi

OVERALL_STATUS=0
if [[ ${HEADLESS_STATUS} -ne 0 || ${RAID_STATUS} -ne 0 || ${GUI_STATUS} -ne 0 ]]; then
  OVERALL_STATUS=1
fi

{
  echo ""
  echo "Result:"
  echo "- headless=${HEADLESS_STATUS}"
  echo "- raid=${RAID_STATUS}"
  echo "- gui=${GUI_STATUS}"
  echo "- overall=${OVERALL_STATUS}"
} | tee -a "${SUMMARY_LOG}"

exit ${OVERALL_STATUS}

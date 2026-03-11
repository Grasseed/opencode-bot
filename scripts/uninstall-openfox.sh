#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename -- "$0")"
TARGET_DIR="${1:-${OPENFOX_INSTALL_DIR:-$HOME/OpenFox}}"
REMOVE_OPENCODE="${OPENFOX_UNINSTALL_REMOVE_OPENCODE:-no}"
AUTO_YES="${OPENFOX_UNINSTALL_YES:-no}"
DRY_RUN="${OPENFOX_UNINSTALL_DRY_RUN:-no}"
REMOVE_OPENCODE_EXPLICIT=0

if [[ -n "${OPENFOX_UNINSTALL_REMOVE_OPENCODE+x}" ]]; then
  REMOVE_OPENCODE_EXPLICIT=1
fi

log() {
  printf '[%s] %s\n' "$SCRIPT_NAME" "$*"
}

warn() {
  printf '[%s] WARN: %s\n' "$SCRIPT_NAME" "$*" >&2
}

fail() {
  printf '[%s] ERROR: %s\n' "$SCRIPT_NAME" "$*" >&2
  exit 1
}

is_truthy() {
  local value="${1:-}"
  [[ "$value" =~ ^(1|true|yes|on)$ ]]
}

confirm() {
  local prompt="$1"
  local default_answer="$2"
  local reply=""

  if is_truthy "$AUTO_YES"; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    [[ "$default_answer" == "yes" ]]
    return
  fi

  if [[ "$default_answer" == "yes" ]]; then
    read -r -p "$prompt [Y/n] " reply
    reply="${reply:-Y}"
  else
    read -r -p "$prompt [y/N] " reply
    reply="${reply:-N}"
  fi

  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

run_cmd() {
  if is_truthy "$DRY_RUN"; then
    log "[dry-run] $*"
    return 0
  fi
  "$@"
}

stop_openfox_process() {
  local pid_file="$TARGET_DIR/openfox.pid"
  if [[ ! -f "$pid_file" ]]; then
    return
  fi

  local pid=""
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  if [[ -z "$pid" ]]; then
    warn "PID file exists but is empty: $pid_file"
    run_cmd rm -f "$pid_file"
    return
  fi

  if kill -0 "$pid" 2>/dev/null; then
    log "Stopping OpenFox process: $pid"
    run_cmd kill -TERM "$pid"
  else
    warn "No running process found for PID: $pid"
  fi

  run_cmd rm -f "$pid_file"
}

remove_openfox_files() {
  if [[ ! -e "$TARGET_DIR" ]]; then
    warn "OpenFox directory not found: $TARGET_DIR"
    return
  fi

  log "Removing OpenFox directory: $TARGET_DIR"
  run_cmd rm -rf "$TARGET_DIR"
}

remove_openfox_launcher() {
  local launcher_path="$HOME/.local/bin/openfox"
  if [[ ! -f "$launcher_path" ]]; then
    return
  fi

  if grep -Fq "$TARGET_DIR/scripts/openfox.sh" "$launcher_path" 2>/dev/null; then
    log "Removing OpenFox launcher: $launcher_path"
    run_cmd rm -f "$launcher_path"
  else
    warn "Launcher exists but points elsewhere, skipped: $launcher_path"
  fi
}

resolve_remove_opencode() {
  if is_truthy "$REMOVE_OPENCODE"; then
    return 0
  fi

  if [[ $REMOVE_OPENCODE_EXPLICIT -eq 1 ]]; then
    return 1
  fi

  if ! command -v opencode >/dev/null 2>&1; then
    return 1
  fi

  if confirm 'Also remove opencode from this machine?' no; then
    return 0
  fi

  return 1
}

uninstall_opencode() {
  if ! resolve_remove_opencode; then
    log 'Keeping opencode installed.'
    return
  fi

  log 'Removing opencode from this machine...'

  if command -v opencode >/dev/null 2>&1; then
    local uninstall_args=(uninstall --force)
    if is_truthy "$DRY_RUN"; then
      uninstall_args+=(--dry-run)
    fi

    log 'Running opencode self-uninstall...'
    run_cmd opencode "${uninstall_args[@]}" || warn 'opencode self-uninstall failed; falling back to package manager cleanup.'
  fi

  if command -v brew >/dev/null 2>&1; then
    if brew list --formula 2>/dev/null | grep -qx 'opencode'; then
      run_cmd brew uninstall opencode || true
    fi
    if brew list --formula 2>/dev/null | grep -qx 'anomalyco/tap/opencode'; then
      run_cmd brew uninstall anomalyco/tap/opencode || true
    fi
  fi

  if command -v npm >/dev/null 2>&1; then
    if npm ls -g opencode-ai --depth=0 >/dev/null 2>&1; then
      run_cmd npm uninstall -g opencode-ai || true
    fi
  fi

  if command -v opencode >/dev/null 2>&1; then
    warn 'opencode command still exists in PATH. Run `command -v opencode` to inspect remaining installation.'
  else
    log 'opencode appears to be removed from PATH.'
  fi
}

main() {
  [[ "$TARGET_DIR" == */ ]] && TARGET_DIR="${TARGET_DIR%/}"

  log "OpenFox target directory: $TARGET_DIR"
  if is_truthy "$REMOVE_OPENCODE"; then
    log 'opencode will also be removed if found.'
  fi
  if is_truthy "$DRY_RUN"; then
    log 'Dry-run mode enabled. No files will be deleted.'
  fi

  if ! confirm 'Proceed with uninstall?' no; then
    fail 'Uninstall cancelled by user.'
  fi

  stop_openfox_process
  remove_openfox_files
  remove_openfox_launcher
  uninstall_opencode

  log 'Uninstall completed.'
}

main "$@"

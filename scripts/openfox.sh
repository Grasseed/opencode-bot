#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

usage() {
  cat <<'EOF'
OpenFox command line helper

Usage:
  openfox start
  openfox stop
  openfox status
  openfox configure
  openfox uninstall
  openfox help

Notes:
  - `openfox uninstall` runs the guided uninstall flow.
  - You can pass uninstall flags through environment variables:
      OPENFOX_UNINSTALL_REMOVE_OPENCODE=yes
      OPENFOX_UNINSTALL_YES=yes
      OPENFOX_UNINSTALL_DRY_RUN=yes
EOF
}

start_openfox() {
  npm --prefix "$PROJECT_ROOT" start
}

stop_openfox() {
  local pid_file="$PROJECT_ROOT/openfox.pid"
  if [[ ! -f "$pid_file" ]]; then
    printf 'OpenFox is not running (no pid file found).\n'
    return 0
  fi

  local pid
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  if [[ -z "$pid" ]]; then
    printf 'OpenFox pid file is empty, removing stale file.\n'
    rm -f "$pid_file"
    return 0
  fi

  if kill -0 "$pid" 2>/dev/null; then
    printf 'Stopping OpenFox (PID %s)...\n' "$pid"
    kill -TERM "$pid"
  else
    printf 'OpenFox process %s is not running, removing stale pid file.\n' "$pid"
  fi

  rm -f "$pid_file"
}

status_openfox() {
  local pid_file="$PROJECT_ROOT/openfox.pid"
  if [[ ! -f "$pid_file" ]]; then
    printf 'OpenFox status: stopped\n'
    return 0
  fi

  local pid
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    printf 'OpenFox status: running (PID %s)\n' "$pid"
  else
    printf 'OpenFox status: stopped (stale pid file)\n'
  fi
}

uninstall_openfox() {
  bash "$SCRIPT_DIR/uninstall-openfox.sh" "$PROJECT_ROOT"
}

configure_openfox() {
  OPENFOX_INSTALL_DIR="$PROJECT_ROOT" OPENFOX_SKIP_REPO_UPDATE=yes OPENFOX_START_NOW=no bash "$SCRIPT_DIR/install-openfox.sh" "$PROJECT_ROOT"
}

main() {
  local command="${1:-help}"
  case "$command" in
    start)
      start_openfox
      ;;
    stop)
      stop_openfox
      ;;
    status)
      status_openfox
      ;;
    configure)
      configure_openfox
      ;;
    uninstall)
      uninstall_openfox
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      printf 'Unknown command: %s\n\n' "$command" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"

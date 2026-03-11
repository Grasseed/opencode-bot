#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename -- "$0")"
TARGET_DIR="${1:-${OPENFOX_INSTALL_DIR:-$HOME/OpenFox}}"
REMOVE_OPENCODE="${OPENFOX_UNINSTALL_REMOVE_OPENCODE:-no}"
AUTO_YES="${OPENFOX_UNINSTALL_YES:-no}"
DRY_RUN="${OPENFOX_UNINSTALL_DRY_RUN:-no}"
REMOVE_OPENCODE_EXPLICIT=0
UNINSTALL_LANG=""

if [[ -n "${OPENFOX_UNINSTALL_REMOVE_OPENCODE+x}" ]]; then
  REMOVE_OPENCODE_EXPLICIT=1
fi

normalize_uninstall_lang() {
  local value="${1:-}"
  value="${value%%.*}"
  value="$(printf '%s' "$value" | command tr '[:upper:]' '[:lower:]')"
  value="${value//_/-}"

  case "$value" in
    zh-tw|zh-hk|zh-mo|zh-hant)
      printf 'zh-TW'
      ;;
    zh|zh-cn|zh-sg|zh-hans)
      printf 'zh-CN'
      ;;
    en|en-us|en-gb)
      printf 'en'
      ;;
    *)
      printf 'en'
      ;;
  esac
}

init_uninstall_lang() {
  UNINSTALL_LANG="$(normalize_uninstall_lang "${OPENFOX_UNINSTALL_LANG:-${OPENFOX_LANG:-${LANG:-en}}}")"
}

i18n_text() {
  local key="$1"
  case "$UNINSTALL_LANG" in
    zh-TW)
      case "$key" in
        lang_title) printf '選擇解除安裝語言';;
        lang_opt_en) printf 'English';;
        lang_opt_zh_tw) printf '繁體中文';;
        lang_opt_zh_cn) printf '简体中文';;
        lang_prompt) printf '請輸入選項（預設 1）: ';;
        log_target_dir) printf 'OpenFox 目標目錄：%%s';;
        log_remove_opencode_enabled) printf '若有安裝，將一併移除 opencode。';;
        log_dry_run_enabled) printf '已啟用 Dry-run，不會刪除任何檔案。';;
        prompt_proceed_uninstall) printf '要繼續解除安裝嗎？';;
        err_uninstall_cancelled) printf '使用者已取消解除安裝。';;
        warn_pid_empty) printf 'PID 檔案存在但內容為空：%%s';;
        log_stopping_process) printf '正在停止 OpenFox 程序：%%s';;
        warn_no_process) printf '找不到仍在執行的 PID：%%s';;
        warn_dir_not_found) printf '找不到 OpenFox 目錄：%%s';;
        log_removing_dir) printf '正在刪除 OpenFox 目錄：%%s';;
        log_removing_launcher) printf '正在刪除 OpenFox 啟動器：%%s';;
        warn_launcher_points_elsewhere) printf '找到啟動器但指向其他路徑，已略過：%%s';;
        prompt_remove_opencode) printf '是否也要移除這台機器上的 opencode？';;
        log_keep_opencode) printf '保留 opencode，不進行移除。';;
        log_removing_opencode) printf '正在移除這台機器上的 opencode...';;
        log_running_self_uninstall) printf '正在執行 opencode 官方卸載...';;
        warn_self_uninstall_failed) printf 'opencode 官方卸載失敗，改用套件管理器清理。';;
        warn_opencode_still_exists) printf 'PATH 中仍可找到 opencode，請執行 `command -v opencode` 檢查剩餘安裝來源。';;
        log_opencode_removed) printf 'PATH 中已找不到 opencode。';;
        log_uninstall_completed) printf '解除安裝完成。';;
        *) printf '%s' "$key";;
      esac
      ;;
    zh-CN)
      case "$key" in
        lang_title) printf '选择卸载语言';;
        lang_opt_en) printf 'English';;
        lang_opt_zh_tw) printf '繁體中文';;
        lang_opt_zh_cn) printf '简体中文';;
        lang_prompt) printf '请输入选项（默认 1）: ';;
        log_target_dir) printf 'OpenFox 目标目录：%%s';;
        log_remove_opencode_enabled) printf '如果存在，将同时移除 opencode。';;
        log_dry_run_enabled) printf '已启用 Dry-run，不会删除任何文件。';;
        prompt_proceed_uninstall) printf '是否继续卸载？';;
        err_uninstall_cancelled) printf '用户已取消卸载。';;
        warn_pid_empty) printf 'PID 文件存在但内容为空：%%s';;
        log_stopping_process) printf '正在停止 OpenFox 进程：%%s';;
        warn_no_process) printf '找不到仍在运行的 PID：%%s';;
        warn_dir_not_found) printf '找不到 OpenFox 目录：%%s';;
        log_removing_dir) printf '正在删除 OpenFox 目录：%%s';;
        log_removing_launcher) printf '正在删除 OpenFox 启动器：%%s';;
        warn_launcher_points_elsewhere) printf '检测到启动器但指向其他路径，已跳过：%%s';;
        prompt_remove_opencode) printf '是否也移除这台机器上的 opencode？';;
        log_keep_opencode) printf '保留 opencode，不执行移除。';;
        log_removing_opencode) printf '正在移除这台机器上的 opencode...';;
        log_running_self_uninstall) printf '正在执行 opencode 官方卸载...';;
        warn_self_uninstall_failed) printf 'opencode 官方卸载失败，改用包管理器清理。';;
        warn_opencode_still_exists) printf 'PATH 中仍能找到 opencode，请执行 `command -v opencode` 检查剩余安装来源。';;
        log_opencode_removed) printf 'PATH 中已找不到 opencode。';;
        log_uninstall_completed) printf '卸载完成。';;
        *) printf '%s' "$key";;
      esac
      ;;
    *)
      case "$key" in
        lang_title) printf 'Choose uninstall language';;
        lang_opt_en) printf 'English';;
        lang_opt_zh_tw) printf '繁體中文';;
        lang_opt_zh_cn) printf '简体中文';;
        lang_prompt) printf 'Enter choice (default 1): ';;
        log_target_dir) printf 'OpenFox target directory: %%s';;
        log_remove_opencode_enabled) printf 'opencode will also be removed if found.';;
        log_dry_run_enabled) printf 'Dry-run mode enabled. No files will be deleted.';;
        prompt_proceed_uninstall) printf 'Proceed with uninstall?';;
        err_uninstall_cancelled) printf 'Uninstall cancelled by user.';;
        warn_pid_empty) printf 'PID file exists but is empty: %%s';;
        log_stopping_process) printf 'Stopping OpenFox process: %%s';;
        warn_no_process) printf 'No running process found for PID: %%s';;
        warn_dir_not_found) printf 'OpenFox directory not found: %%s';;
        log_removing_dir) printf 'Removing OpenFox directory: %%s';;
        log_removing_launcher) printf 'Removing OpenFox launcher: %%s';;
        warn_launcher_points_elsewhere) printf 'Launcher exists but points elsewhere, skipped: %%s';;
        prompt_remove_opencode) printf 'Also remove opencode from this machine?';;
        log_keep_opencode) printf 'Keeping opencode installed.';;
        log_removing_opencode) printf 'Removing opencode from this machine...';;
        log_running_self_uninstall) printf 'Running opencode self-uninstall...';;
        warn_self_uninstall_failed) printf 'opencode self-uninstall failed; falling back to package manager cleanup.';;
        warn_opencode_still_exists) printf 'opencode command still exists in PATH. Run `command -v opencode` to inspect remaining installation.';;
        log_opencode_removed) printf 'opencode appears to be removed from PATH.';;
        log_uninstall_completed) printf 'Uninstall completed.';;
        *) printf '%s' "$key";;
      esac
      ;;
  esac
}

i18n_printf() {
  local key="$1"
  shift
  printf "$(i18n_text "$key")" "$@"
}

choose_uninstall_language() {
  local choice=""

  if [[ ! -t 0 ]]; then
    return
  fi

  if [[ -n "${OPENFOX_UNINSTALL_LANG:-}" || -n "${OPENFOX_LANG:-}" ]]; then
    return
  fi

  printf '\n%s\n' "$(i18n_text 'lang_title')"
  printf '  1) %s\n' "$(i18n_text 'lang_opt_en')"
  printf '  2) %s\n' "$(i18n_text 'lang_opt_zh_tw')"
  printf '  3) %s\n' "$(i18n_text 'lang_opt_zh_cn')"
  read -r -p "$(i18n_text 'lang_prompt')" choice
  choice="${choice:-1}"

  case "$choice" in
    2) UNINSTALL_LANG='zh-TW' ;;
    3) UNINSTALL_LANG='zh-CN' ;;
    *) UNINSTALL_LANG='en' ;;
  esac
}

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
    warn "$(i18n_printf 'warn_pid_empty' "$pid_file")"
    run_cmd rm -f "$pid_file"
    return
  fi

  if kill -0 "$pid" 2>/dev/null; then
    log "$(i18n_printf 'log_stopping_process' "$pid")"
    run_cmd kill -TERM "$pid"
  else
    warn "$(i18n_printf 'warn_no_process' "$pid")"
  fi

  run_cmd rm -f "$pid_file"
}

remove_openfox_files() {
  if [[ ! -e "$TARGET_DIR" ]]; then
    warn "$(i18n_printf 'warn_dir_not_found' "$TARGET_DIR")"
    return
  fi

  log "$(i18n_printf 'log_removing_dir' "$TARGET_DIR")"
  run_cmd rm -rf "$TARGET_DIR"
}

remove_openfox_launcher() {
  local launcher_path="$HOME/.local/bin/openfox"
  if [[ ! -f "$launcher_path" ]]; then
    return
  fi

  if grep -Fq "$TARGET_DIR/scripts/openfox.sh" "$launcher_path" 2>/dev/null; then
    log "$(i18n_printf 'log_removing_launcher' "$launcher_path")"
    run_cmd rm -f "$launcher_path"
  else
    warn "$(i18n_printf 'warn_launcher_points_elsewhere' "$launcher_path")"
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

  if confirm "$(i18n_text 'prompt_remove_opencode')" no; then
    return 0
  fi

  return 1
}

uninstall_opencode() {
  if ! resolve_remove_opencode; then
    log "$(i18n_text 'log_keep_opencode')"
    return
  fi

  log "$(i18n_text 'log_removing_opencode')"

  if command -v opencode >/dev/null 2>&1; then
    local uninstall_args=(uninstall --force)
    if is_truthy "$DRY_RUN"; then
      uninstall_args+=(--dry-run)
    fi

    log "$(i18n_text 'log_running_self_uninstall')"
    run_cmd opencode "${uninstall_args[@]}" || warn "$(i18n_text 'warn_self_uninstall_failed')"
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
    warn "$(i18n_text 'warn_opencode_still_exists')"
  else
    log "$(i18n_text 'log_opencode_removed')"
  fi
}

main() {
  init_uninstall_lang
  choose_uninstall_language
  [[ "$TARGET_DIR" == */ ]] && TARGET_DIR="${TARGET_DIR%/}"

  log "$(i18n_printf 'log_target_dir' "$TARGET_DIR")"
  if is_truthy "$REMOVE_OPENCODE"; then
    log "$(i18n_text 'log_remove_opencode_enabled')"
  fi
  if is_truthy "$DRY_RUN"; then
    log "$(i18n_text 'log_dry_run_enabled')"
  fi

  if ! confirm "$(i18n_text 'prompt_proceed_uninstall')" no; then
    fail "$(i18n_text 'err_uninstall_cancelled')"
  fi

  stop_openfox_process
  remove_openfox_files
  remove_openfox_launcher
  uninstall_opencode

  log "$(i18n_text 'log_uninstall_completed')"
}

main "$@"

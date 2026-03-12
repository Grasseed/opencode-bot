#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename -- "$0")"
REPO_URL="${OPENFOX_REPO_URL:-https://github.com/Grasseed/OpenFox.git}"
TARGET_DIR="${1:-${OPENFOX_INSTALL_DIR:-$HOME/OpenFox}}"
BOT_TOKEN_VALUE="${BOT_TOKEN:-}"
MODEL_VALUE="${OPENCODE_MODEL:-}"
VARIANT_VALUE="${OPENCODE_VARIANT:-medium}"
START_NOW_VALUE="${OPENFOX_START_NOW:-yes}"
LMSTUDIO_BASE_URL="${LMSTUDIO_BASE_URL:-http://127.0.0.1:1234/v1}"
SKIP_OPENCODE_READY_CHECK="${OPENFOX_SKIP_OPENCODE_READY_CHECK:-0}"
SKIP_VALIDATION="${OPENFOX_SKIP_VALIDATION:-0}"
SKIP_REPO_UPDATE="${OPENFOX_SKIP_REPO_UPDATE:-0}"
OS_NAME="$(uname -s)"
PACKAGE_MANAGER=""
PACKAGE_UPDATE_DONE=0
ROOT_PREFIX=()
INTERACTIVE=0
PROMPT_FD=0
OPENCODE_READY=0
READ_KEY_TIMEOUT=1
INSTALL_LANG=""

normalize_install_lang() {
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

init_install_lang() {
  INSTALL_LANG="$(normalize_install_lang "${OPENFOX_LANG:-${LANG:-en}}")"
}

i18n_text() {
  local key="$1"
  case "$INSTALL_LANG" in
    zh-TW)
      case "$key" in
        menu_header) printf 'OpenFox 安裝';;
        menu_hint) printf '\n使用 ↑/↓ 移動，按 Enter 確認。\n';;
        lang_title) printf '選擇安裝語言';;
        lang_opt_en) printf 'English';;
        lang_opt_zh_tw) printf '繁體中文';;
        lang_opt_zh_cn) printf '简体中文';;
        title_bot_token) printf 'Telegram 機器人 Token';;
        opt_enter_bot_token_now) printf '立即輸入 BOT_TOKEN';;
        opt_skip_for_now) printf '先略過';;
        opt_keep_current_bot_token) printf '保留目前 BOT_TOKEN';;
        prompt_enter_bot_token) printf '請輸入 Telegram BOT_TOKEN';;
        title_variant) printf '選擇思考強度';;
        opt_low) printf '低';;
        opt_medium) printf '中';;
        opt_high) printf '高';;
        opt_custom) printf '自訂';;
        prompt_custom_variant) printf '請輸入自訂 variant';;
        title_model) printf '選擇 OpenFox 要使用的模型';;
        title_provider) printf '先選擇模型供應商';;
        title_model_for_provider) printf '選擇供應商 %%s 的模型';;
        opt_use_detected_default) printf '使用偵測到的預設值 (%%s)';;
        opt_keep_current_model) printf '保留目前模型 (%%s)';;
        opt_connect_provider) printf '用 opencode 連線並設定更多供應商';;
        opt_enter_model_manually) printf '手動輸入模型';;
        opt_choose_another_provider) printf '重新選擇供應商';;
        prompt_enter_model_name) printf '請輸入模型名稱';;
        title_opencode_not_ready) printf 'opencode 尚未就緒，要怎麼做？';;
        opt_retry_opencode_check) printf '重試 opencode 檢查';;
        opt_open_opencode_auth_login) printf '開啟 opencode auth login';;
        opt_enter_model_and_continue) printf '手動輸入模型並繼續';;
        opt_skip_model_setup) printf '先略過模型設定';;
        opt_abort_installation) printf '中止安裝';;
        err_installation_cancelled) printf '使用者已取消安裝。';;
        title_start_after_setup) printf '安裝完成後要啟動 OpenFox 嗎？';;
        opt_start_openfox_now) printf '立即啟動 OpenFox';;
        opt_finish_without_starting) printf '先完成但不啟動';;
        err_non_interactive_bot_token_required) printf '非互動模式必須提供 Telegram BOT_TOKEN。';;
        err_model_required) printf '必須提供模型。';;
        err_variant_required) printf '必須提供 variant。';;
        setup_intro) printf 'OpenFox 引導式安裝\n\n你可以先略過 Telegram 或模型設定，稍後再完成。\n\n';;
        prompt_press_enter_continue) printf '按 Enter 繼續。 ';;
        suffix_keep_current_value) printf '按 Enter 保留目前值';;
        err_field_required_non_interactive) printf '非互動模式必須提供：%%s';;
        warn_bot_token_skipped_no_autostart) printf '因為略過 BOT_TOKEN，OpenFox 不會自動啟動。';;
        prompt_press_enter_retry_opencode) printf '按 Enter 重新嘗試 opencode，或按 Ctrl+C 停止。 ';;
        confirm_start_openfox_now) printf '現在在背景啟動 OpenFox？';;
        log_checking_models) printf '設定 OpenFox 前先檢查 opencode 模型...';;
        log_install_complete) printf 'OpenFox 安裝完成。';;
        log_project_directory) printf '專案目錄：%%s';;
        log_change_settings) printf '之後要修改設定，請編輯：%%s/.env';;
        log_reload_shell) printf '如果目前這個終端還找不到 openfox，請重新開一個 shell，或執行：%%s';;
        warn_opencode_needs_setup) printf '完成安裝前，OpenFox 需要可正常運作的 opencode。';;
        warn_hosted_provider_login) printf '若你使用託管服務，安裝器會先開啟 opencode auth login。';;
        warn_local_provider_retry) printf '若你使用 LM Studio 或其他本地 provider，請先啟動後按 Enter 重試。';;
        warn_models_failed) printf 'opencode models 仍然失敗。';;
        err_finish_provider_setup_first) printf '請先完成 opencode provider 設定，再重新執行安裝器。';;
        log_checking_telegram_bot_token) printf '檢查 Telegram bot token...';;
        warn_skip_telegram_token_check) printf '因為尚未設定 BOT_TOKEN，略過 Telegram bot token 檢查。';;
        warn_telegram_network_check_failed) printf '無法連線到 Telegram 驗證 BOT_TOKEN，安裝先繼續。請稍後再檢查網路或防火牆設定。';;
        err_telegram_bot_token_invalid) printf 'Telegram BOT_TOKEN 驗證失敗，請檢查 token 是否正確後重新執行安裝器。';;
        *) printf '%s' "$key";;
      esac
      ;;
    zh-CN)
      case "$key" in
        menu_header) printf 'OpenFox 安装';;
        menu_hint) printf '\n使用 ↑/↓ 移动，按 Enter 确认。\n';;
        lang_title) printf '选择安装语言';;
        lang_opt_en) printf 'English';;
        lang_opt_zh_tw) printf '繁體中文';;
        lang_opt_zh_cn) printf '简体中文';;
        title_bot_token) printf 'Telegram 机器人 Token';;
        opt_enter_bot_token_now) printf '立即输入 BOT_TOKEN';;
        opt_skip_for_now) printf '先跳过';;
        opt_keep_current_bot_token) printf '保留当前 BOT_TOKEN';;
        prompt_enter_bot_token) printf '请输入 Telegram BOT_TOKEN';;
        title_variant) printf '选择思考强度';;
        opt_low) printf '低';;
        opt_medium) printf '中';;
        opt_high) printf '高';;
        opt_custom) printf '自定义';;
        prompt_custom_variant) printf '请输入自定义 variant';;
        title_model) printf '选择 OpenFox 要使用的模型';;
        title_provider) printf '先选择模型供应商';;
        title_model_for_provider) printf '选择供应商 %%s 的模型';;
        opt_use_detected_default) printf '使用检测到的默认值 (%%s)';;
        opt_keep_current_model) printf '保留当前模型 (%%s)';;
        opt_connect_provider) printf '用 opencode 连接并配置更多供应商';;
        opt_enter_model_manually) printf '手动输入模型';;
        opt_choose_another_provider) printf '重新选择供应商';;
        prompt_enter_model_name) printf '请输入模型名称';;
        title_opencode_not_ready) printf 'opencode 尚未就绪，你想怎么做？';;
        opt_retry_opencode_check) printf '重试 opencode 检查';;
        opt_open_opencode_auth_login) printf '打开 opencode auth login';;
        opt_enter_model_and_continue) printf '手动输入模型并继续';;
        opt_skip_model_setup) printf '先跳过模型配置';;
        opt_abort_installation) printf '中止安装';;
        err_installation_cancelled) printf '用户已取消安装。';;
        title_start_after_setup) printf '安装完成后要启动 OpenFox 吗？';;
        opt_start_openfox_now) printf '立即启动 OpenFox';;
        opt_finish_without_starting) printf '先完成但不启动';;
        err_non_interactive_bot_token_required) printf '非交互模式必须提供 Telegram BOT_TOKEN。';;
        err_model_required) printf '必须提供模型。';;
        err_variant_required) printf '必须提供 variant。';;
        setup_intro) printf 'OpenFox 引导式安装\n\n你可以先跳过 Telegram 或模型配置，稍后再完成。\n\n';;
        prompt_press_enter_continue) printf '按 Enter 继续。 ';;
        suffix_keep_current_value) printf '按 Enter 保留当前值';;
        err_field_required_non_interactive) printf '非交互模式必须提供：%%s';;
        warn_bot_token_skipped_no_autostart) printf '因为跳过 BOT_TOKEN，OpenFox 不会自动启动。';;
        prompt_press_enter_retry_opencode) printf '按 Enter 重试 opencode，或按 Ctrl+C 停止。 ';;
        confirm_start_openfox_now) printf '现在要在后台启动 OpenFox 吗？';;
        log_checking_models) printf '配置 OpenFox 前先检查 opencode 模型...';;
        log_install_complete) printf 'OpenFox 安装完成。';;
        log_project_directory) printf '项目目录：%%s';;
        log_change_settings) printf '之后修改配置请编辑：%%s/.env';;
        log_reload_shell) printf '如果当前这个终端还找不到 openfox，请重新打开一个 shell，或执行：%%s';;
        warn_opencode_needs_setup) printf '完成安装前，OpenFox 需要可正常工作的 opencode。';;
        warn_hosted_provider_login) printf '如果你使用托管服务，安装器会先打开 opencode auth login。';;
        warn_local_provider_retry) printf '如果你使用 LM Studio 或其他本地 provider，请先启动后按 Enter 重试。';;
        warn_models_failed) printf 'opencode models 仍然失败。';;
        err_finish_provider_setup_first) printf '请先完成 opencode provider 配置，再重新运行安装器。';;
        log_checking_telegram_bot_token) printf '检查 Telegram bot token...';;
        warn_skip_telegram_token_check) printf '因为尚未配置 BOT_TOKEN，跳过 Telegram bot token 检查。';;
        warn_telegram_network_check_failed) printf '无法连接到 Telegram 验证 BOT_TOKEN，安装先继续。请稍后再检查网络或防火墙设置。';;
        err_telegram_bot_token_invalid) printf 'Telegram BOT_TOKEN 验证失败，请检查 token 是否正确后重新运行安装器。';;
        *) printf '%s' "$key";;
      esac
      ;;
    *)
      case "$key" in
        menu_header) printf 'OpenFox Setup';;
        menu_hint) printf '\nUse ↑/↓ to move, Enter to confirm.\n';;
        lang_title) printf 'Choose installer language';;
        lang_opt_en) printf 'English';;
        lang_opt_zh_tw) printf '繁體中文';;
        lang_opt_zh_cn) printf '简体中文';;
        title_bot_token) printf 'Telegram bot token';;
        opt_enter_bot_token_now) printf 'Enter BOT_TOKEN now';;
        opt_skip_for_now) printf 'Skip for now';;
        opt_keep_current_bot_token) printf 'Keep current BOT_TOKEN';;
        prompt_enter_bot_token) printf 'Enter your Telegram BOT_TOKEN';;
        title_variant) printf 'Choose the thinking variant';;
        opt_low) printf 'low';;
        opt_medium) printf 'medium';;
        opt_high) printf 'high';;
        opt_custom) printf 'custom';;
        prompt_custom_variant) printf 'Enter a custom variant';;
        title_model) printf 'Choose the model OpenFox should use';;
        title_provider) printf 'Choose a model provider first';;
        title_model_for_provider) printf 'Choose a model from provider %%s';;
        opt_use_detected_default) printf 'Use detected default (%%s)';;
        opt_keep_current_model) printf 'Keep current model (%%s)';;
        opt_connect_provider) printf 'Connect and configure more providers with opencode';;
        opt_enter_model_manually) printf 'Enter model manually';;
        opt_choose_another_provider) printf 'Choose another provider';;
        prompt_enter_model_name) printf 'Enter the model name';;
        title_opencode_not_ready) printf 'opencode is not ready yet. What do you want to do?';;
        opt_retry_opencode_check) printf 'Retry opencode check';;
        opt_open_opencode_auth_login) printf 'Open opencode auth login';;
        opt_enter_model_and_continue) printf 'Enter model manually and continue';;
        opt_skip_model_setup) printf 'Skip model setup for now';;
        opt_abort_installation) printf 'Abort installation';;
        err_installation_cancelled) printf 'Installation cancelled by user.';;
        title_start_after_setup) printf 'Start OpenFox after setup?';;
        opt_start_openfox_now) printf 'Start OpenFox now';;
        opt_finish_without_starting) printf 'Finish without starting';;
        err_non_interactive_bot_token_required) printf 'Enter your Telegram BOT_TOKEN is required for non-interactive installation.';;
        err_model_required) printf 'A model is required.';;
        err_variant_required) printf 'A variant is required.';;
        setup_intro) printf 'OpenFox guided setup\n\nYou can skip Telegram or model configuration for now and finish setup first.\n\n';;
        prompt_press_enter_continue) printf 'Press Enter to continue. ';;
        suffix_keep_current_value) printf 'press Enter to keep current value';;
        err_field_required_non_interactive) printf '%%s is required for non-interactive installation.';;
        warn_bot_token_skipped_no_autostart) printf 'BOT_TOKEN was skipped, so OpenFox will not start automatically.';;
        prompt_press_enter_retry_opencode) printf 'Press Enter to retry opencode, or Ctrl+C to stop. ';;
        confirm_start_openfox_now) printf 'Start OpenFox now in the background?';;
        log_checking_models) printf 'Checking opencode models before configuring OpenFox...';;
        log_install_complete) printf 'OpenFox installation is complete.';;
        log_project_directory) printf 'Project directory: %%s';;
        log_change_settings) printf 'To change settings later, edit: %%s/.env';;
        log_reload_shell) printf 'If openfox is not found in this terminal yet, start a new shell or run: %%s';;
        warn_opencode_needs_setup) printf 'OpenFox needs a working opencode setup before installation can finish.';;
        warn_hosted_provider_login) printf 'If you use a hosted provider, the installer will open opencode auth login now.';;
        warn_local_provider_retry) printf 'If you use LM Studio or another local provider, start it now and then press Enter to retry.';;
        warn_models_failed) printf 'opencode models still failed.';;
        err_finish_provider_setup_first) printf 'Finish your opencode provider setup first, then rerun this installer.';;
        log_checking_telegram_bot_token) printf 'Checking Telegram bot token...';;
        warn_skip_telegram_token_check) printf 'Skipping Telegram bot token check because BOT_TOKEN was not configured yet.';;
        warn_telegram_network_check_failed) printf 'Could not reach Telegram to verify BOT_TOKEN. Continuing installation; check your network or firewall settings later.';;
        err_telegram_bot_token_invalid) printf 'Telegram BOT_TOKEN validation failed. Check the token and rerun the installer.';;
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

init_prompt_io() {
  if [[ -t 0 ]]; then
    INTERACTIVE=1
    PROMPT_FD=0
    return
  fi

  if { exec 3<>/dev/tty; } 2>/dev/null; then
    INTERACTIVE=1
    PROMPT_FD=3
    return
  fi

  INTERACTIVE=0
  PROMPT_FD=0
}

close_prompt_io() {
  if [[ "$PROMPT_FD" -eq 3 ]]; then
    exec 3<&-
    exec 3>&-
  fi
}

choose_install_language() {
  if [[ "$INTERACTIVE" -ne 1 ]]; then
    return
  fi

  if [[ -n "${OPENFOX_LANG:-}" ]]; then
    return
  fi

  local choice
  choice="$(menu_prompt "$(i18n_text 'lang_title')" "$(i18n_text 'lang_opt_en')" "$(i18n_text 'lang_opt_zh_tw')" "$(i18n_text 'lang_opt_zh_cn')")"
  case "$choice" in
    0) INSTALL_LANG='en' ;;
    1) INSTALL_LANG='zh-TW' ;;
    2) INSTALL_LANG='zh-CN' ;;
  esac
}

tty_printf() {
  if [[ "$INTERACTIVE" -eq 1 ]]; then
    printf '%b' "$1" >/dev/tty
  fi
}

menu_prompt() {
  local title="$1"
  shift
  local options=("$@")
  local selected=0
  local key=""
  local seq=""
  local key_type=""

  if [[ "$INTERACTIVE" -ne 1 ]]; then
    printf '0'
    return
  fi

  local saved_tty
  saved_tty="$(stty -g </dev/tty 2>/dev/null || true)"

  while true; do
    tty_printf '\033[2J\033[H'
    tty_printf "$(i18n_text 'menu_header')\n\n$title\n\n"

    local i
    for ((i = 0; i < ${#options[@]}; i += 1)); do
      if [[ $i -eq $selected ]]; then
        tty_printf "  \033[36m> ${options[$i]}\033[0m\n"
      else
        tty_printf "    ${options[$i]}\n"
      fi
    done

    tty_printf "$(i18n_text 'menu_hint')"

    stty -echo -icanon min 1 time 0 </dev/tty 2>/dev/null || true
    key=""
    IFS= read -r -s -n 1 -u "$PROMPT_FD" key || true

    if [[ "$key" == $'\x1b' ]]; then
      IFS= read -r -s -n 1 -t "$READ_KEY_TIMEOUT" -u "$PROMPT_FD" seq || true
      key+="$seq"
      seq=""
      IFS= read -r -s -n 1 -t "$READ_KEY_TIMEOUT" -u "$PROMPT_FD" seq || true
      key+="$seq"
    fi
    stty "$saved_tty" </dev/tty 2>/dev/null || true

    key_type="$key"
    case "$key" in
      $'\x1b[A'|$'\x1bOA'|k|K)
        key_type='up'
        ;;
      $'\x1b[B'|$'\x1bOB'|j|J)
        key_type='down'
        ;;
      '')
        key_type='enter'
        ;;
    esac

    case "$key_type" in
      up)
        if [[ $selected -gt 0 ]]; then
          selected=$((selected - 1))
        fi
        ;;
      down)
        if [[ $selected -lt $((${#options[@]} - 1)) ]]; then
          selected=$((selected + 1))
        fi
        ;;
      enter)
        tty_printf '\033[2J\033[H'
        printf '%s' "$selected"
        return
        ;;
    esac
  done
}

load_existing_env_defaults() {
  local env_file="$TARGET_DIR/.env"
  if [[ ! -f "$env_file" ]]; then
    return
  fi

  while IFS='=' read -r key value; do
    [[ -n "$key" ]] || continue
    case "$key" in
      BOT_TOKEN)
        if [[ -z "$BOT_TOKEN_VALUE" ]]; then
          BOT_TOKEN_VALUE="$value"
        fi
        ;;
      OPENCODE_MODEL)
        if [[ -z "$MODEL_VALUE" ]]; then
          MODEL_VALUE="$value"
        fi
        ;;
      OPENCODE_VARIANT)
        if [[ -z "$VARIANT_VALUE" ]]; then
          VARIANT_VALUE="$value"
        fi
        ;;
    esac
  done < "$env_file"
}

choose_bot_token() {
  local default_label=''
  default_label="$(i18n_text 'opt_skip_for_now')"
  if [[ -n "$BOT_TOKEN_VALUE" ]]; then
    default_label="$(i18n_text 'opt_keep_current_bot_token')"
  fi

  local choice
  choice="$(menu_prompt "$(i18n_text 'title_bot_token')" "$(i18n_text 'opt_enter_bot_token_now')" "$default_label")"
  case "$choice" in
    0)
      BOT_TOKEN_VALUE="$(prompt_value "$(i18n_text 'prompt_enter_bot_token')" "$BOT_TOKEN_VALUE" yes)"
      ;;
    *)
      if [[ -z "$BOT_TOKEN_VALUE" ]]; then
        BOT_TOKEN_VALUE=''
      fi
      ;;
  esac
}

choose_variant() {
  local current_variant="${VARIANT_VALUE:-medium}"
  local options=(
    "$(i18n_text 'opt_low')"
    "$(i18n_text 'opt_medium')"
    "$(i18n_text 'opt_high')"
    "$(i18n_text 'opt_custom')"
    "$(i18n_text 'opt_skip_for_now')"
  )
  local choice
  choice="$(menu_prompt "$(i18n_text 'title_variant')" "${options[@]}")"
  case "$choice" in
    0) VARIANT_VALUE='low' ;;
    1) VARIANT_VALUE='medium' ;;
    2) VARIANT_VALUE='high' ;;
    3) VARIANT_VALUE="$(prompt_value "$(i18n_text 'prompt_custom_variant')" "$current_variant")" ;;
    4) : ;;
  esac
}

array_contains() {
  local needle="$1"
  shift
  local value=""
  for value in "$@"; do
    if [[ "$value" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

launch_opencode_provider_setup() {
  if [[ "$INTERACTIVE" -ne 1 ]]; then
    return 1
  fi

  if command -v script >/dev/null 2>&1; then
    script -q /dev/null opencode auth login
  else
    opencode auth login </dev/tty >/dev/tty 2>/dev/tty
  fi
  return 0
}

run_opencode_in_target_dir() {
  if [[ -d "$TARGET_DIR" ]]; then
    (
      cd "$TARGET_DIR"
      opencode "$@"
    )
    return
  fi

  opencode "$@"
}

extract_lmstudio_model_ids_from_json() {
  local models_json="${1:-}"
  [[ -n "$models_json" ]] || return 0

  LMSTUDIO_MODELS_JSON="$models_json" node - <<'EOF'
const payload = process.env.LMSTUDIO_MODELS_JSON || ''
if (!payload) process.exit(0)

let parsed
try {
  parsed = JSON.parse(payload)
} catch {
  process.exit(0)
}

const models = Array.isArray(parsed?.data) ? parsed.data : []
for (const entry of models) {
  const id = typeof entry?.id === 'string' ? entry.id.trim() : ''
  if (!id) continue
  if (/(^|[-/])(embedding|embed)([-/]|$)/i.test(id)) continue
  process.stdout.write(`${id}\n`)
}
EOF
}

fetch_lmstudio_model_ids() {
  local base_url="${LMSTUDIO_BASE_URL%/}"
  local models_json=""

  if ! models_json="$(curl -fsS --max-time 3 "$base_url/models" 2>/dev/null)"; then
    printf ''
    return
  fi

  extract_lmstudio_model_ids_from_json "$models_json"
}

fetch_lmstudio_models_for_opencode() {
  local model_id=""
  while IFS= read -r model_id; do
    [[ -n "$model_id" ]] || continue
    printf 'lmstudio/%s\n' "$model_id"
  done < <(fetch_lmstudio_model_ids)
}

merge_model_lists() {
  awk 'NF && !seen[$0]++'
}

sync_lmstudio_provider_config() {
  local model_ids=""
  model_ids="$(fetch_lmstudio_model_ids)"
  [[ -n "$model_ids" ]] || return 0

  local config_path="$TARGET_DIR/opencode.json"
  mkdir -p "$TARGET_DIR"

  LMSTUDIO_BASE_URL="$LMSTUDIO_BASE_URL" \
  OPENCODE_CONFIG_PATH="$config_path" \
  LMSTUDIO_MODEL_IDS="$model_ids" \
  node - <<'EOF'
const fs = require('fs')
const path = process.env.OPENCODE_CONFIG_PATH
const baseURL = process.env.LMSTUDIO_BASE_URL
const ids = (process.env.LMSTUDIO_MODEL_IDS || '')
  .split(/\r?\n/)
  .map((value) => value.trim())
  .filter(Boolean)

if (!path || !baseURL || ids.length === 0) process.exit(0)

let config = {}
if (fs.existsSync(path)) {
  try {
    config = JSON.parse(fs.readFileSync(path, 'utf8'))
  } catch (error) {
    console.error(`Failed to parse ${path}: ${error.message}`)
    process.exit(1)
  }
}

if (!config || typeof config !== 'object' || Array.isArray(config)) config = {}
if (typeof config.$schema !== 'string' || !config.$schema.trim()) {
  config.$schema = 'https://opencode.ai/config.json'
}
if (!config.provider || typeof config.provider !== 'object' || Array.isArray(config.provider)) {
  config.provider = {}
}

const existingProvider =
  config.provider.lmstudio && typeof config.provider.lmstudio === 'object' && !Array.isArray(config.provider.lmstudio)
    ? config.provider.lmstudio
    : {}
const existingOptions =
  existingProvider.options && typeof existingProvider.options === 'object' && !Array.isArray(existingProvider.options)
    ? existingProvider.options
    : {}
const existingModels =
  existingProvider.models && typeof existingProvider.models === 'object' && !Array.isArray(existingProvider.models)
    ? existingProvider.models
    : {}

const provider = {
  ...existingProvider,
  options: {
    ...existingOptions,
    baseURL
  },
  models: {
    ...existingModels
  }
}

const releaseDate = new Date().toISOString().slice(0, 10)
for (const id of ids) {
  const existingModel =
    provider.models[id] && typeof provider.models[id] === 'object' && !Array.isArray(provider.models[id])
      ? provider.models[id]
      : {}
  provider.models[id] = {
    name: id,
    release_date: releaseDate,
    attachment: false,
    reasoning: true,
    temperature: true,
    tool_call: true,
    limit: {
      context: 32768,
      output: 8192
    },
    ...existingModel
  }
}

config.provider.lmstudio = provider
fs.writeFileSync(path, `${JSON.stringify(config, null, 2)}\n`)
EOF
}

sync_local_provider_configs() {
  sync_lmstudio_provider_config
}

normalize_model_value_with_available_models() {
  local current_model="${1:-}"
  local models_text="${2:-}"
  local line=""
  local matches=()

  [[ -n "$current_model" ]] || return 0

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    if [[ "$line" == "$current_model" ]]; then
      printf '%s' "$current_model"
      return 0
    fi
    if [[ "${line#*/}" == "$current_model" ]]; then
      matches+=("$line")
    fi
  done <<< "$models_text"

  if [[ ${#matches[@]} -eq 1 ]]; then
    printf '%s' "${matches[0]}"
    return 0
  fi

  printf '%s' "$current_model"
}

refresh_available_models() {
  local models_output=""
  local models_error=""
  local opencode_models=""
  local lmstudio_models=""
  models_output="$(mktemp)"
  models_error="$(mktemp)"
  trap 'rm -f "$models_output" "$models_error"' RETURN

  sync_local_provider_configs
  if run_opencode_in_target_dir models --refresh >"$models_output" 2>"$models_error"; then
    opencode_models="$(cat "$models_output")"
  elif run_opencode_in_target_dir models >"$models_output" 2>"$models_error"; then
    opencode_models="$(cat "$models_output")"
  fi

  lmstudio_models="$(fetch_lmstudio_models_for_opencode)"
  if [[ -n "$opencode_models$lmstudio_models" ]]; then
    printf '%s\n%s\n' "$opencode_models" "$lmstudio_models" | merge_model_lists
    return
  fi

  printf ''
}

choose_model_from_provider() {
  local provider="$1"
  local default_model="$2"
  shift 2
  local models=("$@")
  local filtered_models=()
  local options=()
  local option_text=""
  local model=""

  for model in "${models[@]}"; do
    if [[ "$model" == "$provider/"* ]]; then
      filtered_models+=("$model")
    fi
  done

  if [[ -n "$default_model" && "$default_model" == "$provider/"* ]]; then
    option_text="$(i18n_printf 'opt_use_detected_default' "$default_model")"
    options+=("$option_text")
  fi
  if [[ -n "$MODEL_VALUE" && "$MODEL_VALUE" == "$provider/"* ]]; then
    option_text="$(i18n_printf 'opt_keep_current_model' "$MODEL_VALUE")"
    options+=("$option_text")
  fi

  for model in "${filtered_models[@]}"; do
    options+=("$model")
  done

  options+=(
    "$(i18n_text 'opt_enter_model_manually')"
    "$(i18n_text 'opt_choose_another_provider')"
    "$(i18n_text 'opt_skip_for_now')"
  )

  local title=""
  title="$(i18n_printf 'title_model_for_provider' "$provider")"
  local choice=""
  choice="$(menu_prompt "$title" "${options[@]}")"
  local index=0

  if [[ -n "$default_model" && "$default_model" == "$provider/"* ]]; then
    if [[ "$choice" -eq $index ]]; then
      MODEL_VALUE="$default_model"
      return 0
    fi
    index=$((index + 1))
  fi

  if [[ -n "$MODEL_VALUE" && "$MODEL_VALUE" == "$provider/"* ]]; then
    if [[ "$choice" -eq $index ]]; then
      return 0
    fi
    index=$((index + 1))
  fi

  local start_index=$index
  local end_index=$((start_index + ${#filtered_models[@]} - 1))
  if [[ ${#filtered_models[@]} -gt 0 && "$choice" -ge $start_index && "$choice" -le $end_index ]]; then
    MODEL_VALUE="${filtered_models[$((choice - start_index))]}"
    return 0
  fi

  index=$((end_index + 1))
  if [[ "$choice" -eq $index ]]; then
    MODEL_VALUE="$(prompt_value "$(i18n_text 'prompt_enter_model_name')" "$MODEL_VALUE")"
    return 0
  fi

  index=$((index + 1))
  if [[ "$choice" -eq $index ]]; then
    return 10
  fi

  return 0
}

choose_model_from_list() {
  local default_model="$1"
  shift
  local models=("$@")
  local providers=()
  local model=""
  local provider=""

  for model in "${models[@]}"; do
    provider="${model%%/*}"
    [[ -n "$provider" ]] || continue
    if [[ ${#providers[@]} -eq 0 ]] || ! array_contains "$provider" "${providers[@]}"; then
      providers+=("$provider")
    fi
  done

  while true; do
    local options=()
    local option_text=""
    local choice=""
    local index=0
    local provider_start=0
    local provider_end=-1

    if [[ -n "$default_model" ]]; then
      option_text="$(i18n_printf 'opt_use_detected_default' "$default_model")"
      options+=("$option_text")
    fi
    if [[ -n "$MODEL_VALUE" ]]; then
      option_text="$(i18n_printf 'opt_keep_current_model' "$MODEL_VALUE")"
      options+=("$option_text")
    fi

    for provider in "${providers[@]}"; do
      options+=("$provider")
    done

    options+=(
      "$(i18n_text 'opt_connect_provider')"
      "$(i18n_text 'opt_enter_model_manually')"
      "$(i18n_text 'opt_skip_for_now')"
    )
    choice="$(menu_prompt "$(i18n_text 'title_provider')" "${options[@]}")"

    if [[ -n "$default_model" ]]; then
      if [[ "$choice" -eq $index ]]; then
        MODEL_VALUE="$default_model"
        return
      fi
      index=$((index + 1))
    fi

    if [[ -n "$MODEL_VALUE" ]]; then
      if [[ "$choice" -eq $index ]]; then
        return
      fi
      index=$((index + 1))
    fi

    provider_start=$index
    provider_end=$((provider_start + ${#providers[@]} - 1))
    if [[ ${#providers[@]} -gt 0 && "$choice" -ge $provider_start && "$choice" -le $provider_end ]]; then
      provider="${providers[$((choice - provider_start))]}"
      if choose_model_from_provider "$provider" "$default_model" "${models[@]}"; then
        return
      fi
      continue
    fi

    index=$((provider_end + 1))
    if [[ "$choice" -eq $index ]]; then
      launch_opencode_provider_setup
      return 10
    fi

    index=$((index + 1))
    if [[ "$choice" -eq $index ]]; then
      MODEL_VALUE="$(prompt_value "$(i18n_text 'prompt_enter_model_name')" "$MODEL_VALUE")"
      return
    fi

    return
  done
}

configure_opencode_model() {
  local default_model="$1"
  local models_text="$2"
  local models=()
  local line=""
  local choice=""
  local status=0

  while true; do
    models=()
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      models+=("$line")
    done <<< "$models_text"

    if [[ ${#models[@]} -gt 0 ]]; then
      if choose_model_from_list "$default_model" "${models[@]}"; then
        status=0
      else
        status=$?
      fi
      if [[ $status -eq 10 ]]; then
        models_text="$(refresh_available_models)"
        continue
      fi
      return 0
    fi

    choice="$(menu_prompt \
      "$(i18n_text 'title_opencode_not_ready')" \
      "$(i18n_text 'opt_retry_opencode_check')" \
      "$(i18n_text 'opt_open_opencode_auth_login')" \
      "$(i18n_text 'opt_enter_model_and_continue')" \
      "$(i18n_text 'opt_skip_model_setup')" \
      "$(i18n_text 'opt_abort_installation')")"
    case "$choice" in
      0)
        return 10
        ;;
      1)
        launch_opencode_provider_setup
        models_text="$(refresh_available_models)"
        continue
        ;;
      2)
        MODEL_VALUE="$(prompt_value "$(i18n_text 'prompt_enter_model_name')" "$MODEL_VALUE")"
        return 0
        ;;
      3)
        return 0
        ;;
      4)
        fail "$(i18n_text 'err_installation_cancelled')"
        ;;
    esac
  done
}

choose_start_behavior() {
  local choice
  choice="$(menu_prompt "$(i18n_text 'title_start_after_setup')" "$(i18n_text 'opt_start_openfox_now')" "$(i18n_text 'opt_finish_without_starting')")"
  case "$choice" in
    0) START_NOW_VALUE='yes' ;;
    1) START_NOW_VALUE='no' ;;
  esac
}

run_configuration_wizard() {
  local default_model="$1"
  local models_text="$2"

  if [[ "$INTERACTIVE" -ne 1 ]]; then
    if [[ -z "$BOT_TOKEN_VALUE" ]]; then
      fail "$(i18n_text 'err_non_interactive_bot_token_required')"
    fi
    MODEL_VALUE="$(prompt_value "$(i18n_text 'title_model')" "$MODEL_VALUE")"
    [[ -n "$MODEL_VALUE" ]] || fail "$(i18n_text 'err_model_required')"
    VARIANT_VALUE="$(prompt_value "$(i18n_text 'title_variant')" "$VARIANT_VALUE")"
    [[ -n "$VARIANT_VALUE" ]] || fail "$(i18n_text 'err_variant_required')"
    return
  fi

  tty_printf '\033[2J\033[H'
  tty_printf "$(i18n_text 'setup_intro')"
  read -r -u "$PROMPT_FD" -p "$(i18n_text 'prompt_press_enter_continue')"

  choose_bot_token

  while true; do
    if configure_opencode_model "$default_model" "$models_text"; then
      break
    fi
  done

  choose_variant
  choose_start_behavior

  if [[ -z "$BOT_TOKEN_VALUE" ]]; then
    START_NOW_VALUE='no'
    warn "$(i18n_text 'warn_bot_token_skipped_no_autostart')"
  fi
}

confirm() {
  local prompt="$1"
  local default_answer="$2"
  local reply=""

  if [[ "$INTERACTIVE" -ne 1 ]]; then
    [[ "$default_answer" == "yes" ]]
    return
  fi

  if [[ "$default_answer" == "yes" ]]; then
    read -r -u "$PROMPT_FD" -p "$prompt [Y/n] " reply
    reply="${reply:-Y}"
  else
    read -r -u "$PROMPT_FD" -p "$prompt [y/N] " reply
    reply="${reply:-N}"
  fi

  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

prompt_value() {
  local prompt="$1"
  local default_value="$2"
  local secret="${3:-no}"
  local value=""

  if [[ -n "$default_value" && "$INTERACTIVE" -ne 1 ]]; then
    printf '%s' "$default_value"
    return
  fi

  if [[ "$INTERACTIVE" -ne 1 ]]; then
    fail "$(i18n_printf 'err_field_required_non_interactive' "$prompt")"
  fi

  if [[ "$secret" == "yes" ]]; then
    if [[ -n "$default_value" ]]; then
      read -r -u "$PROMPT_FD" -s -p "$prompt [$(i18n_text 'suffix_keep_current_value')]: " value
      printf '\n' >&2
      value="${value:-$default_value}"
    else
      read -r -u "$PROMPT_FD" -s -p "$prompt: " value
      printf '\n' >&2
    fi
  else
    if [[ -n "$default_value" ]]; then
      read -r -u "$PROMPT_FD" -p "$prompt [$default_value]: " value
      value="${value:-$default_value}"
    else
      read -r -u "$PROMPT_FD" -p "$prompt: " value
    fi
  fi

  printf '%s' "$value"
}

load_brew_env() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
}

append_path_export_line() {
  local rc_file="$1"
  local dir="$2"
  local line="export PATH=\"$dir:\$PATH\""

  if [[ ! -f "$rc_file" ]]; then
    mkdir -p "$(dirname "$rc_file")"
    : >"$rc_file"
  fi

  if grep -Fqx "$line" "$rc_file"; then
    return
  fi

  printf '\n# Added by OpenFox installer\n%s\n' "$line" >>"$rc_file"
}

persist_shell_path_entries() {
  local shell_name="${SHELL##*/}"
  local rc_files=()

  case "$shell_name" in
    zsh)
      rc_files=("$HOME/.zprofile" "$HOME/.zshrc")
      ;;
    bash)
      rc_files=("$HOME/.bash_profile" "$HOME/.bashrc")
      ;;
    *)
      rc_files=("$HOME/.profile")
      ;;
  esac

  local rc_file
  for rc_file in "${rc_files[@]}"; do
    append_path_export_line "$rc_file" "$HOME/.opencode/bin"
    append_path_export_line "$rc_file" "$HOME/.local/bin"
  done
}

refresh_user_path() {
  load_brew_env

  local dirs=()
  local npm_prefix=""
  npm_prefix="$(npm config get prefix 2>/dev/null || true)"
  if [[ -n "$npm_prefix" && "$npm_prefix" != "undefined" ]]; then
    dirs+=("$npm_prefix/bin")
  fi
  dirs+=("$HOME/.opencode/bin" "$HOME/.local/bin" "$HOME/bin")

  local dir
  for dir in "${dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    case ":$PATH:" in
      *":$dir:"*) ;;
      *) PATH="$dir:$PATH" ;;
    esac
  done
  export PATH
}

shell_refresh_hint() {
  local shell_name="${SHELL##*/}"

  case "$shell_name" in
    zsh)
      printf 'source ~/.zshrc'
      ;;
    bash)
      printf 'source ~/.bashrc'
      ;;
    *)
      printf 'export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"'
      ;;
  esac
}

init_privileges() {
  if [[ $(id -u) -eq 0 ]]; then
    ROOT_PREFIX=()
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    ROOT_PREFIX=(sudo)
    return
  fi

  ROOT_PREFIX=()
}

run_as_root() {
  if [[ ${#ROOT_PREFIX[@]} -gt 0 ]]; then
    "${ROOT_PREFIX[@]}" "$@"
    return
  fi
  "$@"
}

detect_package_manager() {
  load_brew_env

  case "$OS_NAME" in
    Darwin)
      PACKAGE_MANAGER="brew"
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        PACKAGE_MANAGER="apt"
      elif command -v dnf >/dev/null 2>&1; then
        PACKAGE_MANAGER="dnf"
      elif command -v yum >/dev/null 2>&1; then
        PACKAGE_MANAGER="yum"
      elif command -v pacman >/dev/null 2>&1; then
        PACKAGE_MANAGER="pacman"
      elif command -v apk >/dev/null 2>&1; then
        PACKAGE_MANAGER="apk"
      elif command -v zypper >/dev/null 2>&1; then
        PACKAGE_MANAGER="zypper"
      elif command -v brew >/dev/null 2>&1; then
        PACKAGE_MANAGER="brew"
      else
        fail 'Unsupported Linux distribution. Please install git, node, npm, and opencode manually first.'
      fi
      ;;
    *)
      fail "Unsupported operating system: $OS_NAME"
      ;;
  esac
}

ensure_homebrew() {
  load_brew_env
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  log 'Homebrew not found. Installing Homebrew first...'
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  load_brew_env
  command -v brew >/dev/null 2>&1 || fail 'Homebrew installation failed.'
}

package_update_once() {
  if [[ $PACKAGE_UPDATE_DONE -eq 1 ]]; then
    return
  fi

  case "$PACKAGE_MANAGER" in
    apt)
      run_as_root apt-get update -y
      ;;
    pacman)
      run_as_root pacman -Sy --noconfirm
      ;;
  esac

  PACKAGE_UPDATE_DONE=1
}

install_packages() {
  package_update_once

  case "$PACKAGE_MANAGER" in
    brew)
      brew install "$@"
      ;;
    apt)
      run_as_root apt-get install -y "$@"
      ;;
    dnf)
      run_as_root dnf install -y "$@"
      ;;
    yum)
      run_as_root yum install -y "$@"
      ;;
    pacman)
      run_as_root pacman -S --noconfirm "$@"
      ;;
    apk)
      run_as_root apk add --no-cache "$@"
      ;;
    zypper)
      run_as_root zypper --non-interactive install "$@"
      ;;
    *)
      fail "Unsupported package manager: $PACKAGE_MANAGER"
      ;;
  esac
}

ensure_command_with_packages() {
  local command_name="$1"
  shift

  if command -v "$command_name" >/dev/null 2>&1; then
    return
  fi

  log "Installing packages for $command_name: $*"
  install_packages "$@"
  refresh_user_path
  command -v "$command_name" >/dev/null 2>&1 || fail "Failed to install required command: $command_name"
}

ensure_core_tools() {
  case "$PACKAGE_MANAGER" in
    brew)
      ensure_homebrew
      ensure_command_with_packages git git
      ensure_command_with_packages node node
      ensure_command_with_packages npm node
      ensure_command_with_packages curl curl
      ;;
    apt)
      ensure_command_with_packages curl ca-certificates curl
      ensure_command_with_packages git git
      ensure_command_with_packages node nodejs
      ensure_command_with_packages npm npm
      ;;
    dnf|yum)
      ensure_command_with_packages curl ca-certificates curl
      ensure_command_with_packages git git
      ensure_command_with_packages node nodejs
      ensure_command_with_packages npm npm
      ;;
    pacman)
      ensure_command_with_packages curl ca-certificates curl
      ensure_command_with_packages git git
      ensure_command_with_packages node nodejs
      ensure_command_with_packages npm npm
      ;;
    apk)
      ensure_command_with_packages bash bash
      ensure_command_with_packages curl ca-certificates curl
      ensure_command_with_packages git git
      ensure_command_with_packages node nodejs
      ensure_command_with_packages npm npm
      ;;
    zypper)
      ensure_command_with_packages curl ca-certificates curl
      ensure_command_with_packages git git
      ensure_command_with_packages node nodejs
      ensure_command_with_packages npm npm
      ;;
  esac

  command -v curl >/dev/null 2>&1 || fail 'curl is required but was not installed successfully.'
  command -v git >/dev/null 2>&1 || fail 'git is required but was not installed successfully.'
  command -v node >/dev/null 2>&1 || fail 'node is required but was not installed successfully.'
  command -v npm >/dev/null 2>&1 || fail 'npm is required but was not installed successfully.'
  refresh_user_path
}

install_opencode_with_script() {
  log 'Installing opencode with the official installer...'
  /bin/bash -c "$(curl -fsSL https://opencode.ai/install)"
  refresh_user_path
}

install_opencode_with_npm() {
  log 'Falling back to npm global installation for opencode...'
  if [[ ${#ROOT_PREFIX[@]} -gt 0 ]]; then
    run_as_root npm install -g opencode-ai
  else
    npm install -g opencode-ai
  fi
  refresh_user_path
}

ensure_opencode_binary() {
  refresh_user_path
  if command -v opencode >/dev/null 2>&1; then
    return
  fi

  case "$PACKAGE_MANAGER" in
    brew)
      log 'Installing opencode with Homebrew...'
      if ! brew install anomalyco/tap/opencode; then
        warn 'Homebrew installation for opencode failed. Trying the official installer instead.'
      fi
      ;;
    pacman)
      log 'Installing opencode with pacman...'
      if ! install_packages opencode; then
        warn 'pacman installation for opencode failed. Trying the official installer instead.'
      fi
      ;;
  esac

  refresh_user_path
  if command -v opencode >/dev/null 2>&1; then
    return
  fi

  install_opencode_with_script || true
  if command -v opencode >/dev/null 2>&1; then
    return
  fi

  install_opencode_with_npm
  command -v opencode >/dev/null 2>&1 || fail 'Failed to install opencode.'
}

ensure_repo() {
  if [[ -d "$TARGET_DIR/.git" ]]; then
    if is_truthy "$SKIP_REPO_UPDATE"; then
      log "Using existing OpenFox checkout in $TARGET_DIR"
      return
    fi
    log "Updating existing OpenFox checkout in $TARGET_DIR"
    git -C "$TARGET_DIR" pull --ff-only
    return
  fi

  if [[ -e "$TARGET_DIR" && ! -d "$TARGET_DIR" ]]; then
    fail "Target path exists and is not a directory: $TARGET_DIR"
  fi

  if [[ -d "$TARGET_DIR" ]] && [[ -n "$(ls -A "$TARGET_DIR")" ]]; then
    fail "Target directory is not empty: $TARGET_DIR"
  fi

  log "Cloning OpenFox into $TARGET_DIR"
  git clone "$REPO_URL" "$TARGET_DIR"
}

install_openfox_launcher() {
  local launcher_dir="$HOME/.local/bin"
  local launcher_path="$launcher_dir/openfox"
  mkdir -p "$launcher_dir"

  cat >"$launcher_path" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
bash "$TARGET_DIR/scripts/openfox.sh" "\$@"
EOF

  chmod +x "$launcher_path"
  refresh_user_path

  if command -v openfox >/dev/null 2>&1; then
    log "Installed OpenFox launcher: $(command -v openfox)"
  else
    warn "OpenFox launcher installed at $launcher_path"
    warn 'Add ~/.local/bin to PATH if `openfox` is not found in a new shell.'
  fi
}

extract_default_model() {
  local config_json=""
  sync_local_provider_configs
  config_json="$(run_opencode_in_target_dir debug config 2>/dev/null || true)"
  if [[ -z "$config_json" ]]; then
    printf ''
    return
  fi

  OPENCODE_DEBUG_CONFIG="$config_json" node -e "const config = JSON.parse(process.env.OPENCODE_DEBUG_CONFIG || '{}'); process.stdout.write(typeof config.model === 'string' ? config.model : '')"
}

ensure_opencode_ready() {
  if is_truthy "$SKIP_OPENCODE_READY_CHECK"; then
    log 'Skipping opencode ready check because OPENFOX_SKIP_OPENCODE_READY_CHECK is enabled.'
    OPENCODE_READY=0
    printf ''
    return
  fi

  local models_output
  local models_error
  models_output="$(mktemp)"
  models_error="$(mktemp)"
  trap 'rm -f "$models_output" "$models_error"' RETURN

  sync_local_provider_configs
  local attempt
  for attempt in 1 2 3; do
    if run_opencode_in_target_dir models >"$models_output" 2>"$models_error"; then
      OPENCODE_READY=1
      printf '%s\n%s\n' "$(cat "$models_output")" "$(fetch_lmstudio_models_for_opencode)" | merge_model_lists
      return
    fi

    warn "$(i18n_text 'warn_opencode_needs_setup')"

    if [[ $attempt -eq 1 ]]; then
      warn "$(i18n_text 'warn_hosted_provider_login')"
      if [[ "$INTERACTIVE" -eq 1 ]]; then
        launch_opencode_provider_setup || true
      fi
    else
      warn "$(i18n_text 'warn_local_provider_retry')"
      if [[ "$INTERACTIVE" -eq 1 ]]; then
        read -r -u "$PROMPT_FD" -p "$(i18n_text 'prompt_press_enter_retry_opencode')"
      fi
    fi
  done

  warn "$(i18n_text 'warn_models_failed')"
  if [[ -s "$models_error" ]]; then
    sed 's/^/[opencode] /' "$models_error" >&2
  fi

  OPENCODE_READY=0
  if [[ "$INTERACTIVE" -eq 1 ]]; then
    printf ''
    return
  fi

  fail "$(i18n_text 'err_finish_provider_setup_first')"
}

write_env_file() {
  local env_file="$TARGET_DIR/.env"
  local state_file="$TARGET_DIR/data/state.json"

  mkdir -p "$TARGET_DIR/data"

  if [[ -f "$env_file" ]]; then
    cp "$env_file" "$env_file.bak"
    log "Backed up existing .env to $env_file.bak"
  fi

  cat >"$env_file" <<EOF
BOT_TOKEN=$BOT_TOKEN_VALUE
OPENCODE_MODEL=$MODEL_VALUE
OPENCODE_VARIANT=$VARIANT_VALUE
OPENCODE_WORKDIR=$TARGET_DIR
STATE_FILE=$state_file
TELEGRAM_POLL_TIMEOUT_SECONDS=30
TELEGRAM_POLL_RETRY_DELAY_MS=1500
OPENCODE_TIMEOUT_MS=600000
DELETE_WEBHOOK_ON_START=true
TELEGRAM_SKIP_PENDING_UPDATES_ON_START=true
TELEGRAM_ALLOW_GROUPS=false
PORT=3000
TELEGRAM_WEBHOOK_PATH=/webhook
EOF
}

validate_openfox() {
  log 'Running OpenFox syntax checks...'
  npm --prefix "$TARGET_DIR" run check >/dev/null

  if is_truthy "$SKIP_VALIDATION"; then
    log 'Skipping runtime smoke tests because OPENFOX_SKIP_VALIDATION is enabled.'
    return
  fi

  if [[ "$OPENCODE_READY" -eq 1 ]]; then
    log 'Running opencode smoke test...'
    if ! node "$TARGET_DIR/test-mcp.mjs" "Reply with exactly: OK" >/dev/null; then
      fail 'OpenFox installed, but opencode smoke test failed. Check your provider/model setup and rerun the installer.'
    fi
  else
    warn 'Skipping opencode smoke test because provider setup is incomplete.'
  fi

  if [[ -n "$BOT_TOKEN_VALUE" ]]; then
    log "$(i18n_text 'log_checking_telegram_bot_token')"
    if node "$TARGET_DIR/test-reply.mjs" me >/dev/null; then
      :
    else
      case "$?" in
        2)
          fail "$(i18n_text 'err_telegram_bot_token_invalid')"
          ;;
        3)
          warn "$(i18n_text 'warn_telegram_network_check_failed')"
          ;;
        *)
          fail 'Telegram bot token check failed unexpectedly. Review the error output and rerun the installer.'
          ;;
      esac
    fi
  else
    warn "$(i18n_text 'warn_skip_telegram_token_check')"
  fi
}

start_openfox() {
  local log_file="$TARGET_DIR/openfox.log"
  local pid_file="$TARGET_DIR/openfox.pid"

  if [[ -f "$pid_file" ]]; then
    local current_pid=""
    current_pid="$(cat "$pid_file")"
    if [[ -n "$current_pid" ]] && kill -0 "$current_pid" 2>/dev/null; then
      warn "OpenFox is already running with PID $current_pid"
      return
    fi
  fi

  log 'Starting OpenFox in the background...'
  nohup npm --prefix "$TARGET_DIR" start >"$log_file" 2>&1 &
  local openfox_pid=$!
  printf '%s\n' "$openfox_pid" >"$pid_file"
  log "OpenFox started with PID $openfox_pid"
  log "Log file: $log_file"
}

main() {
  init_prompt_io
  trap close_prompt_io EXIT
  init_install_lang
  choose_install_language

  init_privileges
  detect_package_manager
  ensure_core_tools
  ensure_opencode_binary
  ensure_repo
  chmod +x "$TARGET_DIR/scripts/install-openfox.sh" "$TARGET_DIR/scripts/uninstall-openfox.sh" "$TARGET_DIR/scripts/openfox.sh" 2>/dev/null || true
  install_openfox_launcher
  persist_shell_path_entries
  load_existing_env_defaults

  log "$(i18n_text 'log_checking_models')"
  local models=""
  models="$(ensure_opencode_ready)"
  local default_model=""
  default_model="$(extract_default_model)"
  MODEL_VALUE="$(normalize_model_value_with_available_models "$MODEL_VALUE" "$models")"
  if [[ -z "$MODEL_VALUE" ]]; then
    MODEL_VALUE="$default_model"
  fi

  run_configuration_wizard "$default_model" "$models"
  [[ -n "$VARIANT_VALUE" ]] || VARIANT_VALUE='medium'

  sync_local_provider_configs
  write_env_file
  validate_openfox

  if is_truthy "$START_NOW_VALUE"; then
    start_openfox
  elif [[ -t 0 ]] && confirm "$(i18n_text 'confirm_start_openfox_now')" yes; then
    start_openfox
  fi

  log "$(i18n_text 'log_install_complete')"
  log "$(i18n_printf 'log_project_directory' "$TARGET_DIR")"
  log "$(i18n_printf 'log_change_settings' "$TARGET_DIR")"
  log "$(i18n_printf 'log_reload_shell' "$(shell_refresh_hint)")"
}

main "$@"

#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename -- "$0")"
REPO_URL="${OPENFOX_REPO_URL:-https://github.com/Grasseed/OpenFox.git}"
TARGET_DIR="${1:-${OPENFOX_INSTALL_DIR:-$HOME/OpenFox}}"
BOT_TOKEN_VALUE="${BOT_TOKEN:-}"
MODEL_VALUE="${OPENCODE_MODEL:-}"
VARIANT_VALUE="${OPENCODE_VARIANT:-medium}"
START_NOW_VALUE="${OPENFOX_START_NOW:-yes}"
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
    tty_printf "OpenFox Setup\n\n$title\n\n"

    local i
    for ((i = 0; i < ${#options[@]}; i += 1)); do
      if [[ $i -eq $selected ]]; then
        tty_printf "  \033[36m> ${options[$i]}\033[0m\n"
      else
        tty_printf "    ${options[$i]}\n"
      fi
    done

    tty_printf '\nUse ↑/↓ to move, Enter to confirm.\n'

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
  local default_label='Skip for now'
  if [[ -n "$BOT_TOKEN_VALUE" ]]; then
    default_label='Keep current BOT_TOKEN'
  fi

  local choice
  choice="$(menu_prompt 'Telegram bot token' 'Enter BOT_TOKEN now' "$default_label")"
  case "$choice" in
    0)
      BOT_TOKEN_VALUE="$(prompt_value 'Enter your Telegram BOT_TOKEN' "$BOT_TOKEN_VALUE" yes)"
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
  local options=('low' 'medium' 'high' 'custom' 'Skip for now')
  local choice
  choice="$(menu_prompt 'Choose the thinking variant' "${options[@]}")"
  case "$choice" in
    0) VARIANT_VALUE='low' ;;
    1) VARIANT_VALUE='medium' ;;
    2) VARIANT_VALUE='high' ;;
    3) VARIANT_VALUE="$(prompt_value 'Enter a custom variant' "$current_variant")" ;;
    4) : ;;
  esac
}

choose_model_from_list() {
  local default_model="$1"
  shift
  local models=("$@")
  local options=()

  if [[ -n "$default_model" ]]; then
    options+=("Use detected default ($default_model)")
  fi
  if [[ -n "$MODEL_VALUE" ]]; then
    options+=("Keep current model ($MODEL_VALUE)")
  fi

  local model
  for model in "${models[@]}"; do
    options+=("$model")
  done
  options+=('Enter model manually' 'Skip for now')

  local choice
  choice="$(menu_prompt 'Choose the model OpenFox should use' "${options[@]}")"
  local index=0

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

  local start_index=$index
  local end_index=$((start_index + ${#models[@]} - 1))
  if [[ ${#models[@]} -gt 0 && "$choice" -ge $start_index && "$choice" -le $end_index ]]; then
    MODEL_VALUE="${models[$((choice - start_index))]}"
    return
  fi

  index=$((end_index + 1))
  if [[ "$choice" -eq $index ]]; then
    MODEL_VALUE="$(prompt_value 'Enter the model name' "$MODEL_VALUE")"
    return
  fi
}

configure_opencode_model() {
  local default_model="$1"
  local models_text="$2"
  local models=()

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    models+=("$line")
  done <<< "$models_text"

  if [[ ${#models[@]} -gt 0 ]]; then
    choose_model_from_list "$default_model" "${models[@]}"
    return
  fi

  local choice
  choice="$(menu_prompt 'opencode is not ready yet. What do you want to do?' 'Retry opencode check' 'Open opencode auth login' 'Enter model manually and continue' 'Skip model setup for now' 'Abort installation')"
  case "$choice" in
    0)
      return 10
      ;;
    1)
      opencode auth login </dev/tty >/dev/tty 2>/dev/tty || true
      return 10
      ;;
    2)
      MODEL_VALUE="$(prompt_value 'Enter the model name' "$MODEL_VALUE")"
      return 0
      ;;
    3)
      return 0
      ;;
    4)
      fail 'Installation cancelled by user.'
      ;;
  esac
}

choose_start_behavior() {
  local choice
  choice="$(menu_prompt 'Start OpenFox after setup?' 'Start OpenFox now' 'Finish without starting')"
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
      fail 'Enter your Telegram BOT_TOKEN is required for non-interactive installation.'
    fi
    MODEL_VALUE="$(prompt_value 'Choose the model OpenFox should use' "$MODEL_VALUE")"
    [[ -n "$MODEL_VALUE" ]] || fail 'A model is required.'
    VARIANT_VALUE="$(prompt_value 'Choose the thinking variant' "$VARIANT_VALUE")"
    [[ -n "$VARIANT_VALUE" ]] || fail 'A variant is required.'
    return
  fi

  tty_printf '\033[2J\033[H'
  tty_printf 'OpenFox guided setup\n\nYou can skip Telegram or model configuration for now and finish setup first.\n\n'
  read -r -u "$PROMPT_FD" -p 'Press Enter to continue. '

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
    warn 'BOT_TOKEN was skipped, so OpenFox will not start automatically.'
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
    fail "$prompt is required for non-interactive installation."
  fi

  if [[ "$secret" == "yes" ]]; then
    if [[ -n "$default_value" ]]; then
      read -r -u "$PROMPT_FD" -s -p "$prompt [press Enter to keep current value]: " value
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

refresh_user_path() {
  load_brew_env

  local dirs=()
  local npm_prefix=""
  npm_prefix="$(npm config get prefix 2>/dev/null || true)"
  if [[ -n "$npm_prefix" && "$npm_prefix" != "undefined" ]]; then
    dirs+=("$npm_prefix/bin")
  fi
  dirs+=("$HOME/.local/bin" "$HOME/bin")

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
  config_json="$(opencode debug config 2>/dev/null || true)"
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

  local attempt
  for attempt in 1 2 3; do
    if opencode models >"$models_output" 2>"$models_error"; then
      OPENCODE_READY=1
      cat "$models_output"
      return
    fi

    warn 'OpenFox needs a working opencode setup before installation can finish.'

    if [[ $attempt -eq 1 ]]; then
      warn 'If you use a hosted provider, the installer will open opencode auth login now.'
      if [[ "$INTERACTIVE" -eq 1 ]]; then
        opencode auth login </dev/tty >/dev/tty 2>/dev/tty || true
      fi
    else
      warn 'If you use LM Studio or another local provider, start it now and then press Enter to retry.'
      if [[ "$INTERACTIVE" -eq 1 ]]; then
        read -r -u "$PROMPT_FD" -p 'Press Enter to retry opencode, or Ctrl+C to stop. '
      fi
    fi
  done

  warn 'opencode models still failed.'
  if [[ -s "$models_error" ]]; then
    sed 's/^/[opencode] /' "$models_error" >&2
  fi

  OPENCODE_READY=0
  if [[ "$INTERACTIVE" -eq 1 ]]; then
    printf ''
    return
  fi

  fail 'Finish your opencode provider setup first, then rerun this installer.'
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
    log 'Checking Telegram bot token...'
    node "$TARGET_DIR/test-reply.mjs" me >/dev/null
  else
    warn 'Skipping Telegram bot token check because BOT_TOKEN was not configured yet.'
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

  init_privileges
  detect_package_manager
  ensure_core_tools
  ensure_opencode_binary
  ensure_repo
  chmod +x "$TARGET_DIR/scripts/install-openfox.sh" "$TARGET_DIR/scripts/uninstall-openfox.sh" "$TARGET_DIR/scripts/openfox.sh" 2>/dev/null || true
  install_openfox_launcher
  load_existing_env_defaults

  log 'Checking opencode models before configuring OpenFox...'
  local models=""
  models="$(ensure_opencode_ready)"
  local default_model=""
  default_model="$(extract_default_model)"
  if [[ -z "$MODEL_VALUE" ]]; then
    MODEL_VALUE="$default_model"
  fi

  run_configuration_wizard "$default_model" "$models"
  [[ -n "$VARIANT_VALUE" ]] || VARIANT_VALUE='medium'

  write_env_file
  validate_openfox

  if is_truthy "$START_NOW_VALUE"; then
    start_openfox
  elif [[ -t 0 ]] && confirm 'Start OpenFox now in the background?' yes; then
    start_openfox
  fi

  log 'OpenFox installation is complete.'
  log "Project directory: $TARGET_DIR"
  log "To change settings later, edit: $TARGET_DIR/.env"
}

main "$@"

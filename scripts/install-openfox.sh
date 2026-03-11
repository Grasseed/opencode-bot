#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename -- "$0")"
REPO_URL="${OPENFOX_REPO_URL:-https://github.com/Grasseed/OpenFox.git}"
TARGET_DIR="${1:-${OPENFOX_INSTALL_DIR:-$HOME/OpenFox}}"
BOT_TOKEN_VALUE="${BOT_TOKEN:-}"
MODEL_VALUE="${OPENCODE_MODEL:-}"
VARIANT_VALUE="${OPENCODE_VARIANT:-medium}"
START_NOW_VALUE="${OPENFOX_START_NOW:-yes}"

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

confirm() {
  local prompt="$1"
  local default_answer="$2"
  local reply=""

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

prompt_value() {
  local prompt="$1"
  local default_value="$2"
  local secret="${3:-no}"
  local value=""

  if [[ -n "$default_value" && ! -t 0 ]]; then
    printf '%s' "$default_value"
    return
  fi

  if [[ ! -t 0 ]]; then
    fail "$prompt is required for non-interactive installation."
  fi

  if [[ "$secret" == "yes" ]]; then
    if [[ -n "$default_value" ]]; then
      read -r -s -p "$prompt [press Enter to keep current value]: " value
      printf '\n' >&2
      value="${value:-$default_value}"
    else
      read -r -s -p "$prompt: " value
      printf '\n' >&2
    fi
  else
    if [[ -n "$default_value" ]]; then
      read -r -p "$prompt [$default_value]: " value
      value="${value:-$default_value}"
    else
      read -r -p "$prompt: " value
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

ensure_formula() {
  local command_name="$1"
  local formula_name="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    return
  fi

  log "Installing $formula_name..."
  brew install "$formula_name"
  command -v "$command_name" >/dev/null 2>&1 || fail "Failed to install $formula_name."
}

ensure_repo() {
  if [[ -d "$TARGET_DIR/.git" ]]; then
    log "Updating existing OpenFox checkout in $TARGET_DIR"
    git -C "$TARGET_DIR" pull --ff-only
    return
  fi

  if [[ -e "$TARGET_DIR" && ! -d "$TARGET_DIR" ]]; then
    fail "Target path exists and is not a directory: $TARGET_DIR"
  fi

  if [[ -d "$TARGET_DIR" ]]; then
    if [[ -n "$(ls -A "$TARGET_DIR")" ]]; then
      fail "Target directory is not empty: $TARGET_DIR"
    fi
  fi

  log "Cloning OpenFox into $TARGET_DIR"
  git clone "$REPO_URL" "$TARGET_DIR"
}

extract_default_model() {
  local config_json
  config_json="$(opencode debug config 2>/dev/null || true)"
  if [[ -z "$config_json" ]]; then
    printf ''
    return
  fi

  OPENCODE_DEBUG_CONFIG="$config_json" node -e "const config = JSON.parse(process.env.OPENCODE_DEBUG_CONFIG || '{}'); process.stdout.write(typeof config.model === 'string' ? config.model : '')"
}

ensure_opencode_ready() {
  local models_output
  local models_error
  models_output="$(mktemp)"
  models_error="$(mktemp)"
  trap 'rm -f "$models_output" "$models_error"' RETURN

  local attempt
  for attempt in 1 2 3; do
    if opencode models >"$models_output" 2>"$models_error"; then
      cat "$models_output"
      return
    fi

    warn 'OpenFox needs a working opencode setup before installation can finish.'

    if [[ $attempt -eq 1 ]]; then
      warn 'If you use a hosted provider, the installer will open opencode auth login now.'
      if [[ -t 0 ]]; then
        opencode auth login || true
      fi
    else
      warn 'If you use LM Studio or another local provider, start it now and then press Enter to retry.'
      if [[ -t 0 ]]; then
        read -r -p 'Press Enter to retry opencode, or Ctrl+C to stop. '
      fi
    fi
  done

  warn 'opencode models still failed.'
  if [[ -s "$models_error" ]]; then
    sed 's/^/[opencode] /' "$models_error" >&2
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

  log 'Running opencode smoke test...'
  if ! node "$TARGET_DIR/test-mcp.mjs" "Reply with exactly: OK" >/dev/null; then
    fail 'OpenFox installed, but opencode smoke test failed. Check your provider/model setup and rerun the installer.'
  fi

  log 'Checking Telegram bot token...'
  node "$TARGET_DIR/test-reply.mjs" me >/dev/null
}

start_openfox() {
  local log_file="$TARGET_DIR/openfox.log"
  local pid_file="$TARGET_DIR/openfox.pid"

  if [[ -f "$pid_file" ]]; then
    local current_pid
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
  command -v curl >/dev/null 2>&1 || fail 'curl is required.'
  ensure_homebrew
  ensure_formula git git
  ensure_formula node node
  ensure_formula npm node
  ensure_formula opencode opencode

  ensure_repo

  log 'Checking opencode models before configuring OpenFox...'
  local models
  models="$(ensure_opencode_ready)"
  local default_model
  default_model="$(extract_default_model)"
  if [[ -z "$MODEL_VALUE" ]]; then
    MODEL_VALUE="$default_model"
  fi

  if [[ -z "$BOT_TOKEN_VALUE" ]]; then
    BOT_TOKEN_VALUE="$(prompt_value 'Enter your Telegram BOT_TOKEN' "$BOT_TOKEN_VALUE" yes)"
  fi
  [[ -n "$BOT_TOKEN_VALUE" ]] || fail 'BOT_TOKEN is required.'

  if [[ -t 0 ]]; then
    log 'Available models detected by opencode:'
    printf '%s\n' "$models"
  fi

  MODEL_VALUE="$(prompt_value 'Choose the model OpenFox should use' "$MODEL_VALUE")"
  [[ -n "$MODEL_VALUE" ]] || fail 'A model is required.'
  VARIANT_VALUE="$(prompt_value 'Choose the thinking variant' "$VARIANT_VALUE")"
  [[ -n "$VARIANT_VALUE" ]] || fail 'A variant is required.'

  write_env_file
  validate_openfox

  if [[ "$START_NOW_VALUE" == "yes" ]]; then
    start_openfox
  elif [[ -t 0 ]] && confirm 'Start OpenFox now in the background?' yes; then
    start_openfox
  fi

  log 'OpenFox installation is complete.'
  log "Project directory: $TARGET_DIR"
  log "To change settings later, edit: $TARGET_DIR/.env"
}

main "$@"

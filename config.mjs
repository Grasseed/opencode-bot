import fs from 'node:fs'
import path from 'node:path'
import process from 'node:process'
import { fileURLToPath } from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const projectRoot = path.resolve(__dirname, '..')

function loadDotEnv(dotenvPath = path.join(projectRoot, '.env')) {
  if (!fs.existsSync(dotenvPath)) return

  const raw = fs.readFileSync(dotenvPath, 'utf8')
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith('#')) continue

    const eq = trimmed.indexOf('=')
    if (eq === -1) continue

    const key = trimmed.slice(0, eq).trim()
    let value = trimmed.slice(eq + 1).trim()
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1)
    }

    if (!(key in process.env)) {
      process.env[key] = value
    }
  }
}

function toBool(value, fallback = false) {
  if (value == null || value === '') return fallback
  return ['1', 'true', 'yes', 'on'].includes(String(value).toLowerCase())
}

function toInt(value, fallback) {
  if (value == null || value === '') return fallback
  const parsed = Number.parseInt(String(value), 10)
  return Number.isFinite(parsed) ? parsed : fallback
}

export function loadConfig(options = {}) {
  loadDotEnv()

  const requireBotToken = options.requireBotToken ?? true

  const config = {
    projectRoot,
    botToken: process.env.BOT_TOKEN || '',
    pollTimeoutSeconds: toInt(process.env.TELEGRAM_POLL_TIMEOUT_SECONDS, 30),
    pollRetryDelayMs: toInt(process.env.TELEGRAM_POLL_RETRY_DELAY_MS, 1500),
    runOnce: toBool(process.env.RUN_ONCE, false),
    deleteWebhookOnStart: toBool(process.env.DELETE_WEBHOOK_ON_START, true),
    skipPendingUpdatesOnStart: toBool(process.env.TELEGRAM_SKIP_PENDING_UPDATES_ON_START, true),
    webhookPort: toInt(process.env.PORT, 3000),
    webhookPath: process.env.TELEGRAM_WEBHOOK_PATH || '/webhook',
    opencodeBin: process.env.OPENCODE_BIN || 'opencode',
    opencodeModel: process.env.OPENCODE_MODEL || '',
    opencodeVariant: process.env.OPENCODE_VARIANT || 'medium',
    opencodeAgent: process.env.OPENCODE_AGENT || '',
    opencodeWorkdir: process.env.OPENCODE_WORKDIR || projectRoot,
    opencodeTimeoutMs: toInt(process.env.OPENCODE_TIMEOUT_MS, 10 * 60 * 1000),
    stateFile: process.env.STATE_FILE || path.join(projectRoot, 'data', 'state.json'),
    allowGroups: toBool(process.env.TELEGRAM_ALLOW_GROUPS, false)
  }

  if (requireBotToken && !config.botToken) {
    throw new Error('BOT_TOKEN is required. Set it in the environment or in .env.')
  }

  return config
}

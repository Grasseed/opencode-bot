import { execFile } from 'node:child_process'
import { promisify } from 'node:util'

const MAX_MESSAGE_LENGTH = 4000
const execFileAsync = promisify(execFile)

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

function collectNetworkErrorCodes(error) {
  const codes = new Set()

  const visit = (value) => {
    if (!value || typeof value !== 'object') return
    if (typeof value.code === 'string') codes.add(value.code)
    if (Array.isArray(value.errors)) {
      for (const item of value.errors) visit(item)
    }
    if (value.cause) visit(value.cause)
  }

  visit(error)
  return codes
}

function shouldFallbackToCurl(error) {
  const codes = collectNetworkErrorCodes(error)
  if (codes.has('ETIMEDOUT')) return true
  if (codes.has('EHOSTUNREACH')) return true
  if (codes.has('ENETUNREACH')) return true
  if (codes.has('ECONNRESET')) return true
  return false
}

function isCurlNetworkError(error) {
  if (!error || typeof error !== 'object') return false
  if (error.code === 28 || error.code === 'CURLE_OPERATION_TIMEDOUT') return true
  if (error.code === 7 || error.code === 'CURLE_COULDNT_CONNECT') return true
  if (typeof error.stderr === 'string') {
    if (error.stderr.includes('SSL connection timeout')) return true
    if (error.stderr.includes('Connection timed out')) return true
    if (error.stderr.includes('Failed to connect')) return true
  }
  return false
}

export class TelegramApi {
  constructor(botToken) {
    this.botToken = botToken
    this.baseUrl = `https://api.telegram.org/bot${botToken}`
  }

  async request(method, payload = {}) {
    try {
      return await this.requestWithFetch(method, payload)
    } catch (error) {
      if (!shouldFallbackToCurl(error)) throw error
      return this.requestWithCurl(method, payload)
    }
  }

  async requestWithFetch(method, payload = {}) {
    const response = await fetch(`${this.baseUrl}/${method}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    })

    const data = await response.json()
    if (!response.ok || !data.ok) {
      throw new Error(`Telegram API ${method} failed: ${data.description || response.statusText}`)
    }

    return data.result
  }

  async requestWithCurl(method, payload = {}) {
    const url = `${this.baseUrl}/${method}`
    const timeoutSeconds =
      Number.isFinite(payload?.timeout) && payload.timeout > 0
        ? Math.max(15, Math.trunc(payload.timeout) + 10)
        : 20

    let stdout = ''
    try {
      ;({ stdout } = await execFileAsync('curl', [
        '-4',
        '-sS',
        '--retry',
        '2',
        '--retry-delay',
        '1',
        '--retry-all-errors',
        '--connect-timeout',
        '10',
        '--max-time',
        String(timeoutSeconds),
        '-X',
        'POST',
        url,
        '-H',
        'Content-Type: application/json',
        '--data-binary',
        JSON.stringify(payload)
      ]))
    } catch (error) {
      if (isCurlNetworkError(error)) {
        const wrapped = new TypeError('fetch failed')
        wrapped.cause = {
          code: 'ETIMEDOUT',
          originalCode: error.code,
          stderr: error.stderr || ''
        }
        throw wrapped
      }
      throw error
    }

    const data = JSON.parse(stdout)
    if (!data?.ok) {
      throw new Error(`Telegram API ${method} failed: ${data?.description || 'Unknown curl response error'}`)
    }

    return data.result
  }

  async getMe() {
    return this.request('getMe')
  }

  async deleteWebhook(dropPendingUpdates = false) {
    return this.request('deleteWebhook', { drop_pending_updates: dropPendingUpdates })
  }

  async getUpdates(offset, timeoutSeconds) {
    const payload = {
      timeout: timeoutSeconds,
      allowed_updates: ['message']
    }
    if (Number.isFinite(offset)) payload.offset = offset
    return this.request('getUpdates', payload)
  }

  async sendChatAction(chatId, action = 'typing') {
    return this.request('sendChatAction', { chat_id: chatId, action })
  }

  async sendText(chatId, text) {
    const parts = splitMessage(text)
    for (const part of parts) {
      await this.request('sendMessage', {
        chat_id: chatId,
        text: part,
        link_preview_options: { is_disabled: true }
      })
      if (parts.length > 1) await sleep(200)
    }
  }
}

function splitMessage(text) {
  if (text.length <= MAX_MESSAGE_LENGTH) return [text]

  const parts = []
  let remaining = text
  while (remaining.length > MAX_MESSAGE_LENGTH) {
    let splitAt = remaining.lastIndexOf('\n', MAX_MESSAGE_LENGTH)
    if (splitAt < MAX_MESSAGE_LENGTH / 2) {
      splitAt = remaining.lastIndexOf(' ', MAX_MESSAGE_LENGTH)
    }
    if (splitAt < MAX_MESSAGE_LENGTH / 2) {
      splitAt = MAX_MESSAGE_LENGTH
    }

    parts.push(remaining.slice(0, splitAt).trim())
    remaining = remaining.slice(splitAt).trim()
  }

  if (remaining) parts.push(remaining)
  return parts.filter(Boolean)
}

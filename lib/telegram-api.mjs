const MAX_MESSAGE_LENGTH = 4000

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

export class TelegramApi {
  constructor(botToken) {
    this.botToken = botToken
    this.baseUrl = `https://api.telegram.org/bot${botToken}`
  }

  async request(method, payload = {}) {
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

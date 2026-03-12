import { StateStore } from './state-store.mjs'
import { TelegramApi } from './telegram-api.mjs'
import { OpencodeRunner } from './opencode-runner.mjs'

function nowIso() {
  return new Date().toISOString()
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

function summarizeError(error) {
  const message = error instanceof Error ? error.message : String(error)
  return `Request failed.\n\n${message}`
}

function toNumber(value) {
  return Number.isFinite(value) ? value : 0
}

function extractUsage(tokens) {
  const source = tokens && typeof tokens === 'object' ? tokens : {}
  return {
    total: toNumber(source.total),
    input: toNumber(source.input),
    output: toNumber(source.output),
    reasoning: toNumber(source.reasoning)
  }
}

function addUsage(target, delta) {
  target.total += delta.total
  target.input += delta.input
  target.output += delta.output
  target.reasoning += delta.reasoning
}

function formatInt(value) {
  return new Intl.NumberFormat('en-US').format(toNumber(value))
}

function splitCommand(text, botUsername = '') {
  const trimmed = (text || '').trim()
  if (!trimmed) return { command: '', argsText: '' }
  const spaceIndex = trimmed.indexOf(' ')
  const normalizeCommand = (value) => {
    if (!value.startsWith('/')) return value
    const [base, mention] = value.split('@')
    if (!mention || !botUsername) return base
    return mention.toLowerCase() === botUsername.toLowerCase() ? base : value
  }
  if (spaceIndex === -1) {
    return { command: normalizeCommand(trimmed), argsText: '' }
  }
  return {
    command: normalizeCommand(trimmed.slice(0, spaceIndex)),
    argsText: trimmed.slice(spaceIndex + 1).trim()
  }
}

export class TelegramOpencodeBot {
  constructor(config) {
    this.config = config
    this.stateStore = new StateStore(config.stateFile)
    this.telegram = new TelegramApi(config.botToken)
    this.opencode = new OpencodeRunner(config)
    this.state = null
    this.chatQueues = new Map()
    this.botInfo = null
  }

  async init() {
    this.state = await this.stateStore.load()
    this.config.opencodeModel = this.state.settings?.model || this.config.opencodeModel
    this.botInfo = await this.telegram.getMe()

    if (this.config.deleteWebhookOnStart) {
      await this.telegram.deleteWebhook(false)
    }

    if (this.config.skipPendingUpdatesOnStart && !Number.isFinite(this.state.offset)) {
      const pendingUpdates = await this.telegram.getUpdates(undefined, 0)
      const lastUpdate = pendingUpdates[pendingUpdates.length - 1]
      if (lastUpdate && Number.isFinite(lastUpdate.update_id)) {
        this.state.offset = lastUpdate.update_id + 1
        await this.stateStore.save(this.state)
      }
    }

    return this.botInfo
  }

  async startPolling() {
    for (;;) {
      try {
        const updates = await this.telegram.getUpdates(this.state.offset, this.config.pollTimeoutSeconds)
        if (updates.length > 0) {
          for (const update of updates) {
            await this.handleUpdate(update)
          }
        }

        if (this.config.runOnce) {
          return updates.length
        }
      } catch (error) {
        console.error('[polling] error:', error)
        if (this.config.runOnce) throw error
        await sleep(this.config.pollRetryDelayMs)
      }
    }
  }

  async handleUpdate(update) {
    if (Number.isFinite(update.update_id)) {
      this.state.offset = update.update_id + 1
      await this.stateStore.save(this.state)
    }

    const message = update.message
    if (!message) return
    if (message.from?.is_bot) return

    const chat = message.chat || {}
    if (chat.type !== 'private' && !this.config.allowGroups) {
      return
    }

    const text = (message.text || message.caption || '').trim()
    if (!text) {
      await this.telegram.sendText(chat.id, 'Only text messages are supported right now.')
      return
    }

    return this.enqueueChat(chat.id, async () => {
      await this.processMessage(message, text)
    })
  }

  async processMessage(message, text) {
    const chatId = message.chat.id
    const chatState = this.state.chats[String(chatId)] || {}
    const { command, argsText } = splitCommand(text, this.botInfo?.username || '')

    if (command === '/start' || command === '/help') {
      await this.telegram.sendText(chatId, this.helpText())
      return
    }

    if (command === '/status') {
      await this.telegram.sendText(chatId, this.statusText(chatId))
      return
    }

    if (command === '/usage') {
      await this.telegram.sendText(chatId, this.usageText(chatId))
      return
    }

    if (command === '/skill' || command === '/skills') {
      await this.telegram.sendChatAction(chatId, 'typing')
      const skills = await this.opencode.listSkills()
      await this.telegram.sendText(chatId, this.skillsText(skills))
      return
    }

    if (command === '/model') {
      await this.telegram.sendChatAction(chatId, 'typing')
      await this.handleModelCommand(chatId, argsText)
      return
    }

    if (command === '/reset' || command === '/new') {
      const oldSessionId = chatState.sessionId || null
      this.state.chats[String(chatId)] = {
        sessionId: null,
        updatedAt: nowIso(),
        usage: chatState.usage || { total: 0, input: 0, output: 0, reasoning: 0 }
      }
      await this.stateStore.save(this.state)
      if (oldSessionId) {
        try {
          await this.opencode.deleteSession(oldSessionId)
        } catch (error) {
          console.warn('[reset] failed to delete opencode session:', error)
        }
      }
      await this.telegram.sendText(chatId, 'Session reset. The next message starts a fresh opencode context.')
      return
    }

    const typingTimer = setInterval(() => {
      this.telegram.sendChatAction(chatId, 'typing').catch(() => {})
    }, 4000)

    try {
      await this.telegram.sendChatAction(chatId, 'typing')
      const result = await this.opencode.run({
        message: text,
        sessionId: chatState.sessionId || null,
        chatId
      })

      const usageDelta = extractUsage(result.tokens)
      const nextChatUsage = {
        ...(chatState.usage || { total: 0, input: 0, output: 0, reasoning: 0 })
      }
      addUsage(nextChatUsage, usageDelta)
      addUsage(this.state.usage, usageDelta)

      this.state.chats[String(chatId)] = {
        sessionId: result.sessionId,
        updatedAt: nowIso(),
        usage: nextChatUsage
      }
      await this.stateStore.save(this.state)

      await this.telegram.sendText(chatId, result.reply)
    } catch (error) {
      console.error('[processMessage] error:', error)
      await this.telegram.sendText(chatId, summarizeError(error))
    } finally {
      clearInterval(typingTimer)
    }
  }

  helpText() {
    return [
      'This bot forwards your message to opencode and returns the model reply.',
      '',
      'Commands:',
      '/status - show current bot/session status',
      '/usage - show token usage totals',
      '/model - show or switch the active model',
      '/skill - list installed opencode skills',
      '/reset - clear the current opencode session',
      '/help - show this message'
    ].join('\n')
  }

  async handleModelCommand(chatId, argsText) {
    const requested = (argsText || '').trim()
    const models = await this.opencode.listModels()
    const defaultModel = this.defaultModel()

    if (!requested) {
      await this.telegram.sendText(chatId, this.modelText(models, defaultModel))
      return
    }

    if (requested === 'default' || requested === 'reset') {
      this.state.settings.model = null
      this.config.opencodeModel = defaultModel
      await this.stateStore.save(this.state)
      await this.telegram.sendText(chatId, [
        'Model switched back to the configured default.',
        '',
        `active model: ${this.activeModel()}`
      ].join('\n'))
      return
    }

    const nextModel = models.find((model) => model === requested)
    if (!nextModel) {
      await this.telegram.sendText(chatId, [
        `Model not found: ${requested}`,
        '',
        'Use `/model` to view the available models on this machine.'
      ].join('\n'))
      return
    }

    this.state.settings.model = nextModel
    this.config.opencodeModel = nextModel
    await this.stateStore.save(this.state)

    await this.telegram.sendText(chatId, [
      'Model switched successfully.',
      '',
      `active model: ${this.activeModel()}`,
      'The bot keeps running. New messages will use this model immediately.'
    ].join('\n'))
  }

  modelText(models, defaultModel) {
    const activeModel = this.activeModel()
    return [
      `active model: ${activeModel}`,
      `default model: ${defaultModel || '(opencode default)'}`,
      '',
      'Available models:',
      ...models.map((model) => `- ${model}`),
      '',
      'Usage:',
      '/model <provider/model-name>',
      '/model default'
    ].join('\n')
  }

  activeModel() {
    return this.config.opencodeModel || '(opencode default)'
  }

  defaultModel() {
    return process.env.OPENCODE_MODEL || ''
  }

  skillsText(skills) {
    if (!Array.isArray(skills) || skills.length === 0) {
      return 'No skills found from opencode debug skill.'
    }

    return [
      `Installed skills (${skills.length}):`,
      '',
      ...skills.map((skill) => `- ${skill.name}`)
    ].join('\n')
  }

  statusText(chatId) {
    const chatState = this.state.chats[String(chatId)] || {}
    return [
      `bot: @${this.botInfo?.username || 'unknown'}`,
      `workdir: ${this.config.opencodeWorkdir}`,
      `model: ${this.activeModel()}`,
      `variant: ${this.config.opencodeVariant || '(provider default)'}`,
      `session: ${chatState.sessionId || '(new chat)'}`,
      `state file: ${this.config.stateFile}`
    ].join('\n')
  }

  usageText(chatId) {
    const chatUsage = this.state.chats[String(chatId)]?.usage || { total: 0, input: 0, output: 0, reasoning: 0 }
    const globalUsage = this.state.usage || { total: 0, input: 0, output: 0, reasoning: 0 }

    return [
      'Token usage (tracked by this bot process):',
      '',
      `chat total: ${formatInt(chatUsage.total)} (input ${formatInt(chatUsage.input)}, output ${formatInt(chatUsage.output)}, reasoning ${formatInt(chatUsage.reasoning)})`,
      `global total: ${formatInt(globalUsage.total)} (input ${formatInt(globalUsage.input)}, output ${formatInt(globalUsage.output)}, reasoning ${formatInt(globalUsage.reasoning)})`,
      '',
      'Remaining quota is not available here. Check your provider billing/quota dashboard for limits.'
    ].join('\n')
  }

  enqueueChat(chatId, task) {
    const key = String(chatId)
    const previous = this.chatQueues.get(key) || Promise.resolve()
    const next = previous
      .catch(() => {})
      .then(task)
      .finally(() => {
        if (this.chatQueues.get(key) === next) {
          this.chatQueues.delete(key)
        }
      })

    this.chatQueues.set(key, next)
    return next
  }
}

import fs from 'node:fs/promises'
import path from 'node:path'

const EMPTY_STATE = {
  offset: null,
  chats: {},
  usage: {
    total: 0,
    input: 0,
    output: 0,
    reasoning: 0
  }
}

function normalizeUsage(usage) {
  const source = usage && typeof usage === 'object' ? usage : {}
  return {
    total: Number.isFinite(source.total) ? source.total : 0,
    input: Number.isFinite(source.input) ? source.input : 0,
    output: Number.isFinite(source.output) ? source.output : 0,
    reasoning: Number.isFinite(source.reasoning) ? source.reasoning : 0
  }
}

function normalizeChats(chats) {
  if (!chats || typeof chats !== 'object') return {}

  const normalized = {}
  for (const [chatId, chatState] of Object.entries(chats)) {
    const source = chatState && typeof chatState === 'object' ? chatState : {}
    normalized[chatId] = {
      sessionId: typeof source.sessionId === 'string' ? source.sessionId : null,
      updatedAt: typeof source.updatedAt === 'string' ? source.updatedAt : null,
      usage: normalizeUsage(source.usage)
    }
  }

  return normalized
}

export class StateStore {
  constructor(stateFile) {
    this.stateFile = stateFile
  }

  async load() {
    try {
      const raw = await fs.readFile(this.stateFile, 'utf8')
      const parsed = JSON.parse(raw)
      return {
        offset: Number.isFinite(parsed.offset) ? parsed.offset : null,
        chats: normalizeChats(parsed.chats),
        usage: normalizeUsage(parsed.usage)
      }
    } catch (error) {
      if (error.code === 'ENOENT') {
        return structuredClone(EMPTY_STATE)
      }
      throw error
    }
  }

  async save(state) {
    await fs.mkdir(path.dirname(this.stateFile), { recursive: true })
    const tempFile = `${this.stateFile}.tmp`
    await fs.writeFile(tempFile, `${JSON.stringify(state, null, 2)}\n`, 'utf8')
    await fs.rename(tempFile, this.stateFile)
  }
}

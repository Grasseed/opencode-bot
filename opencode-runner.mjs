import { spawn } from 'node:child_process'
import path from 'node:path'
import readline from 'node:readline'

function stripThinkBlocks(text) {
  return text.replace(/<think>[\s\S]*?<\/think>\s*/g, '').trim()
}

function tail(text, maxChars = 1200) {
  return text.length > maxChars ? text.slice(-maxChars) : text
}

function summarizeToolErrors(toolErrors) {
  if (toolErrors.length === 0) return ''
  return toolErrors
    .map(({ tool, input, error }) => {
      const path = input?.filePath ? ` (${input.filePath})` : ''
      return `${tool}${path}: ${error}`
    })
    .join('\n')
}

function extractToolError(event) {
  if (!event || typeof event !== 'object') return null
  if (event.type !== 'tool' && event.type !== 'tool_use') return null
  if (event.part?.state?.status !== 'error') return null

  return {
    tool: event.part.tool || 'tool',
    input: event.part.state.input || {},
    error: event.part.state.error || 'Unknown tool error'
  }
}

export class OpencodeRunner {
  constructor(config) {
    this.config = config
  }

  async run({ message, sessionId, chatId }) {
    const args = ['run', '--format', 'json']

    if (sessionId) {
      args.push('--session', sessionId)
    } else {
      args.push('--title', `telegram-${chatId}`)
    }

    if (this.config.opencodeModel) {
      args.push('--model', this.config.opencodeModel)
    }

    if (this.config.opencodeVariant) {
      args.push('--variant', this.config.opencodeVariant)
    }

    if (this.config.opencodeAgent) {
      args.push('--agent', this.config.opencodeAgent)
    }

    args.push(message)

    const child = spawn(this.config.opencodeBin, args, {
      cwd: path.resolve(this.config.opencodeWorkdir),
      env: process.env,
      stdio: ['ignore', 'pipe', 'pipe']
    })

    const stdoutLines = []
    const visibleChunks = []
    let resolvedSessionId = sessionId || null
    let stepTokens = null
    let finishReason = null
    let stderr = ''
    let timedOut = false
    const toolErrors = []

    const stdoutRl = readline.createInterface({ input: child.stdout })
    stdoutRl.on('line', (line) => {
      if (!line.trim()) return
      stdoutLines.push(line)
      try {
        const event = JSON.parse(line)
        if (event.sessionID) {
          resolvedSessionId = event.sessionID
        }
        if (event.type === 'text' && event.part?.text) {
          const cleaned = stripThinkBlocks(event.part.text)
          if (cleaned) visibleChunks.push(cleaned)
        }
        const toolError = extractToolError(event)
        if (toolError) {
          toolErrors.push(toolError)
        }
        if (event.type === 'step_finish' && event.part?.tokens) {
          stepTokens = event.part.tokens
          finishReason = event.part.reason || null
        }
      } catch {
        // Keep raw output for diagnostics.
      }
    })

    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString()
    })

    const timeout = setTimeout(() => {
      timedOut = true
      child.kill('SIGTERM')
    }, this.config.opencodeTimeoutMs)

    const exitCode = await new Promise((resolve, reject) => {
      child.on('error', reject)
      child.on('close', resolve)
    })

    clearTimeout(timeout)
    stdoutRl.close()

    if (timedOut) {
      throw new Error(`opencode timed out after ${this.config.opencodeTimeoutMs}ms`)
    }

    if (exitCode !== 0) {
      throw new Error(`opencode exited with code ${exitCode}: ${tail(stderr || stdoutLines.join('\n'))}`)
    }

    const reply = visibleChunks.join('\n\n').trim()
    if (!reply) {
      const toolErrorSummary = summarizeToolErrors(toolErrors)
      if (toolErrorSummary) {
        throw new Error(`opencode tool call failed.\n${toolErrorSummary}`)
      }
      if (finishReason) {
        throw new Error(`opencode finished without visible text (reason: ${finishReason}). Raw output tail: ${tail(stdoutLines.join('\n'))}`)
      }
      throw new Error(`opencode returned no visible text. Raw output tail: ${tail(stdoutLines.join('\n'))}`)
    }

    return {
      sessionId: resolvedSessionId,
      reply,
      tokens: stepTokens
    }
  }

  async deleteSession(sessionId) {
    if (!sessionId) return

    await new Promise((resolve, reject) => {
      const child = spawn(this.config.opencodeBin, ['session', 'delete', sessionId], {
        cwd: path.resolve(this.config.opencodeWorkdir),
        env: process.env,
        stdio: ['ignore', 'ignore', 'pipe']
      })

      let stderr = ''
      child.stderr.on('data', (chunk) => {
        stderr += chunk.toString()
      })

      child.on('error', reject)
      child.on('close', (code) => {
        if (code === 0) {
          resolve()
          return
        }
        reject(new Error(stderr || `session delete failed with code ${code}`))
      })
    })
  }
}

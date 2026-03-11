import { loadConfig } from './lib/config.mjs'
import { TelegramApi } from './lib/telegram-api.mjs'

async function main() {
  const config = loadConfig()
  const telegram = new TelegramApi(config.botToken)
  const command = process.argv[2] || 'me'

  if (command === 'me') {
    const me = await telegram.getMe()
    console.log(JSON.stringify(me, null, 2))
    return
  }

  if (command === 'send') {
    const chatId = process.env.TEST_CHAT_ID
    const text = process.argv.slice(3).join(' ').trim() || 'OpenFox test message'
    if (!chatId) {
      throw new Error('TEST_CHAT_ID is required for send mode.')
    }
    await telegram.sendText(chatId, text)
    console.log(`sent to ${chatId}`)
    return
  }

  throw new Error(`Unknown command: ${command}`)
}

function classifyError(error) {
  if (error instanceof Error && error.message.startsWith('Telegram API ')) {
    return 2
  }

  if (error instanceof TypeError && error.message === 'fetch failed') {
    return 3
  }

  if (error && typeof error === 'object' && (error.code === 28 || error.code === 7)) {
    return 3
  }

  if (error && typeof error === 'object' && typeof error.stderr === 'string') {
    if (error.stderr.includes('SSL connection timeout')) return 3
    if (error.stderr.includes('Connection timed out')) return 3
    if (error.stderr.includes('Failed to connect')) return 3
  }

  if (error && typeof error === 'object' && error.cause && error.cause.code) {
    return 3
  }

  return 1
}

main().catch((error) => {
  console.error(error)
  process.exitCode = classifyError(error)
})

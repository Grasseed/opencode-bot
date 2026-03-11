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
    const text = process.argv.slice(3).join(' ').trim() || 'opencode-bot test message'
    if (!chatId) {
      throw new Error('TEST_CHAT_ID is required for send mode.')
    }
    await telegram.sendText(chatId, text)
    console.log(`sent to ${chatId}`)
    return
  }

  throw new Error(`Unknown command: ${command}`)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

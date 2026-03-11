import { loadConfig } from './lib/config.mjs'
import { TelegramOpencodeBot } from './lib/bot-service.mjs'

async function main() {
  const config = loadConfig()
  const bot = new TelegramOpencodeBot(config)
  const info = await bot.init()

  console.log(`[startup] bot @${info.username} (${info.first_name})`)
  console.log(`[startup] state file: ${config.stateFile}`)
  console.log(`[startup] opencode workdir: ${config.opencodeWorkdir}`)
  console.log('[startup] polling Telegram for updates')

  await bot.startPolling()
}

main().catch((error) => {
  console.error('[fatal]', error)
  process.exitCode = 1
})

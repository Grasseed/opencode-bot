import { loadConfig } from './lib/config.mjs'
import { OpencodeRunner } from './lib/opencode-runner.mjs'

async function main() {
  const message = process.argv.slice(2).join(' ').trim() || 'Reply with exactly: OK'
  const config = loadConfig({ requireBotToken: false })
  const runner = new OpencodeRunner(config)
  const result = await runner.run({ message, chatId: 'selftest' })

  console.log(JSON.stringify(result, null, 2))
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

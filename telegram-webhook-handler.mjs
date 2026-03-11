import http from 'node:http'

import { loadConfig } from './lib/config.mjs'
import { TelegramOpencodeBot } from './lib/bot-service.mjs'

function readJson(req) {
  return new Promise((resolve, reject) => {
    let body = ''
    req.on('data', (chunk) => {
      body += chunk.toString()
    })
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {})
      } catch (error) {
        reject(error)
      }
    })
    req.on('error', reject)
  })
}

function writeJson(res, statusCode, payload) {
  res.writeHead(statusCode, { 'Content-Type': 'application/json; charset=utf-8' })
  res.end(`${JSON.stringify(payload)}\n`)
}

async function main() {
  const config = loadConfig()
  const bot = new TelegramOpencodeBot(config)
  const info = await bot.init()

  const server = http.createServer(async (req, res) => {
    try {
      const pathname = new URL(req.url, `http://${req.headers.host || 'localhost'}`).pathname

      if (req.method === 'GET' && pathname === '/health') {
        writeJson(res, 200, {
          ok: true,
          bot: info.username,
          mode: 'webhook',
          workdir: config.opencodeWorkdir
        })
        return
      }

      if (req.method === 'POST' && pathname === config.webhookPath) {
        const update = await readJson(req)
        await bot.handleUpdate(update)
        writeJson(res, 200, { ok: true })
        return
      }

      writeJson(res, 404, { ok: false, error: 'Not found' })
    } catch (error) {
      console.error('[webhook] error:', error)
      writeJson(res, 500, { ok: false, error: error instanceof Error ? error.message : String(error) })
    }
  })

  server.listen(config.webhookPort, () => {
    console.log(`[startup] webhook server on :${config.webhookPort}${config.webhookPath}`)
    console.log('[startup] health endpoint: /health')
  })
}

main().catch((error) => {
  console.error('[fatal]', error)
  process.exitCode = 1
})

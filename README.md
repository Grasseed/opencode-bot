# opencode-bot

Local Telegram bot that forwards each chat to `opencode`, keeps one opencode session per Telegram chat, and returns the model response back to Telegram.

## What is implemented

- Long polling runner for local use: `telegram-bot.mjs`
- Webhook runner for deployment: `telegram-webhook-handler.mjs`
- One opencode session per Telegram chat, stored in `data/state.json`
- `/status`, `/usage`, `/reset`, `/help` commands
- Configurable thinking variant via `OPENCODE_VARIANT` (default: `medium`)
- Automatic stripping of `<think>...</think>` blocks from opencode output
- Telegram message chunking for replies longer than 4000 chars
- Fresh start protection: skips old pending Telegram updates unless you disable it

## Setup

1. Copy the environment template:

```bash
cp .env.example .env
```

2. Fill in `BOT_TOKEN`.

3. Adjust `OPENCODE_MODEL`, `OPENCODE_VARIANT`, and `OPENCODE_WORKDIR` if needed.

4. Make sure `opencode` and your LM Studio endpoint already work from the shell.

## Run locally with polling

```bash
npm start
```

Or without npm:

```bash
node telegram-bot.mjs
```

## Run as a webhook server

```bash
npm run start:webhook
```

Health endpoint:

```bash
curl http://127.0.0.1:3000/health
```

## Commands in Telegram

- `/help`
- `/status`
- `/usage`
- `/reset`

Any other text message is forwarded to `opencode run`.

`/usage` reports tracked token totals for the current chat and globally in this bot's `state.json`. It does not include provider-side remaining quota.

## Notes

- Polling and webhook should not run against the same bot token at the same time.
- By default only private chats are processed. Set `TELEGRAM_ALLOW_GROUPS=true` to allow groups.
- By default a first-time start skips old pending updates to avoid replaying backlog. Set `TELEGRAM_SKIP_PENDING_UPDATES_ON_START=false` if you intentionally want to process backlog.
- Recovered tmp files such as `webhook-server.mjs` and `CLIOURE_WEBHOOK_SETUP.txt` are kept only for reference.

## Smoke tests

Check syntax:

```bash
npm run check
```

Check bot token:

```bash
node test-reply.mjs me
```

Check opencode integration:

```bash
node test-mcp.mjs "Reply with exactly: OK"
```

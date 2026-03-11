# opencode-bot

[English](#english) | [繁體中文](#繁體中文) | [简体中文](#简体中文)

## English

Local Telegram bot that forwards each chat to `opencode`, keeps one opencode session per Telegram chat, and returns the model response back to Telegram.

### What is implemented

- Long polling runner for local use: `telegram-bot.mjs`
- Webhook runner for deployment: `telegram-webhook-handler.mjs`
- One opencode session per Telegram chat, stored in `data/state.json`
- `/status`, `/usage`, `/reset`, `/help` commands
- Configurable thinking variant via `OPENCODE_VARIANT` (default: `medium`)
- Automatic stripping of `<think>...</think>` blocks from opencode output
- Telegram message chunking for replies longer than 4000 chars
- Fresh start protection: skips old pending Telegram updates unless you disable it

### Setup

1. Copy the environment template:

```bash
cp .env.example .env
```

2. Fill in `BOT_TOKEN`.

3. Adjust `OPENCODE_MODEL`, `OPENCODE_VARIANT`, and `OPENCODE_WORKDIR` if needed.

4. Make sure `opencode` and your LM Studio endpoint already work from the shell.

### Run locally with polling

```bash
npm start
```

Or without npm:

```bash
node telegram-bot.mjs
```

### Run as a webhook server

```bash
npm run start:webhook
```

Health endpoint:

```bash
curl http://127.0.0.1:3000/health
```

### Commands in Telegram

- `/help`
- `/status`
- `/usage`
- `/skill`
- `/reset`

Any other text message is forwarded to `opencode run`.

`/usage` reports tracked token totals for the current chat and globally in this bot's `state.json`. It does not include provider-side remaining quota.

### Notes

- Polling and webhook should not run against the same bot token at the same time.
- By default only private chats are processed. Set `TELEGRAM_ALLOW_GROUPS=true` to allow groups.
- By default a first-time start skips old pending updates to avoid replaying backlog. Set `TELEGRAM_SKIP_PENDING_UPDATES_ON_START=false` if you intentionally want to process backlog.
- Recovered tmp files such as `webhook-server.mjs` and `CLIOURE_WEBHOOK_SETUP.txt` are kept only for reference.

### Smoke tests

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

## 繁體中文

本專案是一個本地 Telegram 機器人，會把每個聊天訊息轉送到 `opencode`，為每個 Telegram 聊天維持獨立的 opencode session，並將模型回覆傳回 Telegram。

### 已實作內容

- 本地 long polling 啟動器：`telegram-bot.mjs`
- 佈署用 webhook 啟動器：`telegram-webhook-handler.mjs`
- 每個 Telegram 聊天一個 opencode session，儲存在 `data/state.json`
- `/status`、`/usage`、`/reset`、`/help` 指令
- 可透過 `OPENCODE_VARIANT` 設定思考變體（預設：`medium`）
- 自動移除 opencode 輸出中的 `<think>...</think>` 區塊
- 超過 4000 字元的 Telegram 回覆會自動分段
- 啟動保護機制：預設跳過舊的待處理 Telegram updates（可關閉）

### 設定

1. 複製環境變數範本：

```bash
cp .env.example .env
```

2. 填入 `BOT_TOKEN`。

3. 視需求調整 `OPENCODE_MODEL`、`OPENCODE_VARIANT`、`OPENCODE_WORKDIR`。

4. 確認 `opencode` 與你的 LM Studio endpoint 已可在 shell 中正常運作。

### 本地以 polling 執行

```bash
npm start
```

或不使用 npm：

```bash
node telegram-bot.mjs
```

### 以 webhook 伺服器執行

```bash
npm run start:webhook
```

健康檢查端點：

```bash
curl http://127.0.0.1:3000/health
```

### Telegram 指令

- `/help`
- `/status`
- `/usage`
- `/skill`
- `/reset`

其他文字訊息都會轉送給 `opencode run`。

`/usage` 會回報本機器人在 `state.json` 追蹤的 token 用量（目前聊天與全域）。不包含供應商端剩餘額度資訊。

### 注意事項

- 不要在同一個 bot token 上同時啟用 polling 與 webhook。
- 預設只處理私聊。若要允許群組，設定 `TELEGRAM_ALLOW_GROUPS=true`。
- 預設首次啟動會跳過舊的待處理 updates 以避免重放積壓訊息。若你要處理積壓，設定 `TELEGRAM_SKIP_PENDING_UPDATES_ON_START=false`。
- 復原的暫存檔（例如 `webhook-server.mjs`、`CLIOURE_WEBHOOK_SETUP.txt`）僅保留作為參考。

### 冒煙測試

檢查語法：

```bash
npm run check
```

檢查 bot token：

```bash
node test-reply.mjs me
```

檢查 opencode 整合：

```bash
node test-mcp.mjs "Reply with exactly: OK"
```

## 简体中文

本项目是一个本地 Telegram 机器人，会把每个聊天消息转发到 `opencode`，为每个 Telegram 聊天维护独立的 opencode session，并将模型回复返回到 Telegram。

### 已实现内容

- 本地 long polling 启动入口：`telegram-bot.mjs`
- 部署用 webhook 启动入口：`telegram-webhook-handler.mjs`
- 每个 Telegram 聊天一个 opencode session，存储在 `data/state.json`
- `/status`、`/usage`、`/reset`、`/help` 命令
- 可通过 `OPENCODE_VARIANT` 配置思考变体（默认：`medium`）
- 自动去除 opencode 输出中的 `<think>...</think>` 区块
- Telegram 回复超过 4000 字符时自动分段
- 启动保护：默认跳过旧的待处理 Telegram updates（可关闭）

### 设置

1. 复制环境变量模板：

```bash
cp .env.example .env
```

2. 填写 `BOT_TOKEN`。

3. 按需调整 `OPENCODE_MODEL`、`OPENCODE_VARIANT`、`OPENCODE_WORKDIR`。

4. 确保 `opencode` 和你的 LM Studio endpoint 已可在 shell 中正常工作。

### 本地通过 polling 运行

```bash
npm start
```

或不使用 npm：

```bash
node telegram-bot.mjs
```

### 以 webhook 服务器运行

```bash
npm run start:webhook
```

健康检查端点：

```bash
curl http://127.0.0.1:3000/health
```

### Telegram 命令

- `/help`
- `/status`
- `/usage`
- `/skill`
- `/reset`

其他文本消息都会转发给 `opencode run`。

`/usage` 会报告此机器人在 `state.json` 中跟踪的 token 用量（当前聊天与全局）。不包含服务商侧剩余额度信息。

### 注意事项

- 不要在同一个 bot token 上同时运行 polling 和 webhook。
- 默认只处理私聊。若要允许群组，设置 `TELEGRAM_ALLOW_GROUPS=true`。
- 默认首次启动会跳过旧的待处理 updates，以避免重放积压消息。若你希望处理积压，设置 `TELEGRAM_SKIP_PENDING_UPDATES_ON_START=false`。
- 恢复出的临时文件（例如 `webhook-server.mjs`、`CLIOURE_WEBHOOK_SETUP.txt`）仅保留作参考。

### 冒烟测试

检查语法：

```bash
npm run check
```

检查 bot token：

```bash
node test-reply.mjs me
```

检查 opencode 集成：

```bash
node test-mcp.mjs "Reply with exactly: OK"
```

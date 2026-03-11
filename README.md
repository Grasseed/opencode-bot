# OpenFox

[English](#english) | [繁體中文](#繁體中文) | [简体中文](#简体中文)

## English

OpenFox is a local Telegram bot that forwards each chat to `opencode`, keeps one opencode session per Telegram chat, and returns the model response back to Telegram.

### Quick install

One command with guided setup:

```bash
curl -fsSL https://raw.githubusercontent.com/Grasseed/OpenFox/main/scripts/install-openfox.sh | bash
```

You can force installer language with `OPENFOX_LANG=en`, `OPENFOX_LANG=zh-TW`, or `OPENFOX_LANG=zh-CN`.

The installer keeps interactive prompts even with `curl | bash` by reading from your terminal (`/dev/tty`).

The guided setup lets you:

- move through options with the arrow keys
- press Enter to confirm a selection
- choose provider first, then pick a model
- launch `opencode` provider setup directly from the installer when you need more providers
- auto-detect live LM Studio models and sync them into the project's `opencode.json`
- skip Telegram or model setup for now and configure later with `openfox configure`

The installer will:

- install `opencode` first plus required tools for the detected platform
- reuse existing `brew`, `git`, `node`, `npm`, `curl`, and `opencode` when they are already available
- verify `opencode` can list models before finishing OpenFox setup
- clone or update OpenFox, create `.env`, run smoke checks, and optionally start the bot

Supported installer environments:

- macOS with Homebrew
- Linux with `apt`, `dnf`, `yum`, `pacman`, `apk`, or `zypper`

### Uninstall

Simple command:

```bash
openfox uninstall
```

You can force uninstall language with `OPENFOX_UNINSTALL_LANG=en`, `OPENFOX_UNINSTALL_LANG=zh-TW`, or `OPENFOX_UNINSTALL_LANG=zh-CN`.

Remove OpenFox only (direct script):

```bash
bash ./scripts/uninstall-openfox.sh
```

Remove OpenFox and opencode (explicit opt-in):

```bash
OPENFOX_UNINSTALL_REMOVE_OPENCODE=yes bash ./scripts/uninstall-openfox.sh
```

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
- `/model`
- `/skill`
- `/reset`

Any other text message is forwarded to `opencode run`.

`/usage` reports tracked token totals for the current chat and globally in this bot's `state.json`. It does not include provider-side remaining quota.

`/model` shows the active model and available models. You can switch models at runtime with `/model <provider/model-name>` or revert with `/model default` without restarting the bot.

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

OpenFox 是一個本地 Telegram 機器人，會把每個聊天訊息轉送到 `opencode`，為每個 Telegram 聊天維持獨立的 opencode session，並將模型回覆傳回 Telegram。

### 快速安裝

使用一條指令完成安裝與引導設定：

```bash
curl -fsSL https://raw.githubusercontent.com/Grasseed/OpenFox/main/scripts/install-openfox.sh | bash
```

你也可以用 `OPENFOX_LANG=en`、`OPENFOX_LANG=zh-TW` 或 `OPENFOX_LANG=zh-CN` 強制指定安裝語言。

即使使用 `curl | bash`，安裝器也會透過終端（`/dev/tty`）保留互動式引導。

這個引導流程支援：

- 使用方向鍵上下選擇選項
- 按 Enter 確認
- 先選擇 provider，再選擇模型
- 如果需要更多 provider，可直接在安裝器裡開啟 `opencode` 的 provider 設定
- 自動偵測 LM Studio 目前對外提供的模型，並同步到專案的 `opencode.json`
- 先跳過 Telegram 或模型設定，之後再用 `openfox configure` 補設定

安裝器會：

- 依照偵測到的平台優先安裝 `opencode` 與必要工具
- 若系統已經有 `brew`、`git`、`node`、`npm`、`curl`、`opencode`，會直接沿用，不會重複安裝
- 在完成 OpenFox 設定前，先確認 `opencode` 可以列出可用模型
- 自動 clone 或更新 OpenFox、建立 `.env`、執行冒煙檢查，並可選擇直接啟動 bot

目前安裝器支援：

- macOS（Homebrew）
- Linux（`apt`、`dnf`、`yum`、`pacman`、`apk`、`zypper`）

### 解除安裝

簡單指令：

```bash
openfox uninstall
```

你也可以用 `OPENFOX_UNINSTALL_LANG=en`、`OPENFOX_UNINSTALL_LANG=zh-TW` 或 `OPENFOX_UNINSTALL_LANG=zh-CN` 強制指定解除安裝語言。

只移除 OpenFox（直接執行腳本）：

```bash
bash ./scripts/uninstall-openfox.sh
```

同時移除 OpenFox 與 opencode（需明確指定）：

```bash
OPENFOX_UNINSTALL_REMOVE_OPENCODE=yes bash ./scripts/uninstall-openfox.sh
```

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
- `/model`
- `/skill`
- `/reset`

其他文字訊息都會轉送給 `opencode run`。

`/usage` 會回報本機器人在 `state.json` 追蹤的 token 用量（目前聊天與全域）。不包含供應商端剩餘額度資訊。

`/model` 會顯示目前模型與可用模型清單。你可以用 `/model <provider/model-name>` 在不中斷 bot 的情況下即時切換，或用 `/model default` 切回預設模型。

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

OpenFox 是一个本地 Telegram 机器人，会把每个聊天消息转发到 `opencode`，为每个 Telegram 聊天维护独立的 opencode session，并将模型回复返回到 Telegram。

### 快速安装

使用一条命令完成安装和引导设置：

```bash
curl -fsSL https://raw.githubusercontent.com/Grasseed/OpenFox/main/scripts/install-openfox.sh | bash
```

你也可以用 `OPENFOX_LANG=en`、`OPENFOX_LANG=zh-TW` 或 `OPENFOX_LANG=zh-CN` 强制指定安装语言。

即使使用 `curl | bash`，安装器也会通过终端（`/dev/tty`）保持交互式引导。

引导流程支持：

- 使用方向键上下选择选项
- 按 Enter 确认
- 先选择 provider，再选择模型
- 如果需要更多 provider，可直接在安装器里打开 `opencode` 的 provider 配置
- 自动检测 LM Studio 当前对外提供的模型，并同步到项目的 `opencode.json`
- 先跳过 Telegram 或模型配置，之后再用 `openfox configure` 补设定

安装器会：

- 按检测到的平台优先安装 `opencode` 和必要工具
- 如果系统已经有 `brew`、`git`、`node`、`npm`、`curl`、`opencode`，就会直接复用，不会重复安装
- 在完成 OpenFox 配置前，先确认 `opencode` 可以列出可用模型
- 自动 clone 或更新 OpenFox、创建 `.env`、执行冒烟检查，并可选择直接启动 bot

当前安装器支持：

- macOS（Homebrew）
- Linux（`apt`、`dnf`、`yum`、`pacman`、`apk`、`zypper`）

### 卸载

简易命令：

```bash
openfox uninstall
```

你也可以用 `OPENFOX_UNINSTALL_LANG=en`、`OPENFOX_UNINSTALL_LANG=zh-TW` 或 `OPENFOX_UNINSTALL_LANG=zh-CN` 强制指定卸载语言。

只移除 OpenFox（直接执行脚本）：

```bash
bash ./scripts/uninstall-openfox.sh
```

同时移除 OpenFox 和 opencode（需要明确指定）：

```bash
OPENFOX_UNINSTALL_REMOVE_OPENCODE=yes bash ./scripts/uninstall-openfox.sh
```

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
- `/model`
- `/skill`
- `/reset`

其他文本消息都会转发给 `opencode run`。

`/usage` 会报告此机器人在 `state.json` 中跟踪的 token 用量（当前聊天与全局）。不包含服务商侧剩余额度信息。

`/model` 会显示当前模型与可用模型列表。你可以用 `/model <provider/model-name>` 在不中断 bot 的情况下即时切换，也可以用 `/model default` 切回默认模型。

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

# Banking Playground

A Flutter banking dashboard whose UI can be modified in plain English through an AI chat interface, powered by the [Cursor SDK](https://docs.cursor.com/sdk).

## What it does

You open the app, tap the **AI Assistant** button, type something like *"make the banner green"* or *"remove the investments section"*, and the agent edits the source files directly. Flutter hot-restarts automatically and the UI reflects your change — no code editor needed.

## Architecture

Three layers:

1. **Flutter (web/mobile)** — Renders the banking dashboard and the AI Assistant chat modal (tool activity, thinking blocks, persisted history). Talks to the server over HTTP and SSE.

2. **Node.js agent server** (Express + Cursor SDK) — Endpoints:
   - `POST /prompt` — run the Cursor agent
   - `GET /turns` — chat history
   - `DELETE /turns` — clear history
   - `GET /events` — SSE stream
   - `POST /reset` — restore UI defaults

3. **Cursor local agent** — Edits files under `banking_app/lib/` from each natural-language prompt.

### Editable surface

The agent can freely modify:

| Path | Purpose |
|---|---|
| `banking_app/lib/app_shell.dart` | Main scaffold — layout, widgets, imports |
| `banking_app/lib/components/current/` | Individual dashboard section widgets |
| `banking_app/lib/layout/current/*.json` | Order, visibility, color/style props |

Protected files (agent is instructed never to touch these):
`main.dart`, `prompt_modal.dart`, `layout_model.dart`, `app_shell_defaults.dart`, `layout/defaults/`, `components/defaults/`

### Chat history persistence

Completed turns (user text + full stream event log) are saved to `agent_server/data/turns.json` and reloaded on server startup, so chat history survives restarts.

## Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install) — tested on stable channel
- [Node.js](https://nodejs.org/) 18+
- A Cursor API key with local agent access

## Setup

```bash
# 1. Clone
git clone https://github.com/xandykati98/banking-playground.git
cd banking-playground

# 2. Install Node dependencies
npm install

# 3. Configure environment
cp agent_server/.env.example agent_server/.env
# Edit agent_server/.env and set:  CURSOR_API_KEY=your_key_here

# 4. Install Flutter dependencies
cd banking_app && flutter pub get && cd ..
```

## Running

**Preferred** — build once, then run the compiled server (faster than dev mode; no TypeScript watch overhead):

```bash
npm run build
npm run start
```

`build` compiles the agent server and runs `flutter build web`. `start` runs the compiled server (`node dist/server.js`), which still launches Flutter in Chrome and handles hot restarts after each prompt.

**Development** — auto-reloads the server when you edit TypeScript:

```bash
npm run dev
```

The server starts Flutter automatically. Open the app URL printed in the terminal (not the API port — the agent API listens on `http://localhost:3000`).

To run Flutter and the server separately:

```bash
npm run dev:server   # agent server only (port 3000)
npm run dev:flutter  # flutter run -d chrome
```

## Usage

1. Tap the **✨ AI Assistant** button in the bottom-right corner of the app
2. Type a request describing a UI change
3. Watch the agent's tool activity stream in real time
4. Flutter hot-restarts automatically when the agent finishes
5. Tap **↺** to reset the UI back to the default design
6. Tap **🗑** to clear the chat history

## Project structure

**agent_server/**

- `src/server.ts` — Express HTTP + SSE server
- `src/agent.ts` — Cursor SDK agent, streams events via callback
- `src/messages.ts` — Chat history, turn records, SSE broadcast
- `src/layout.ts` — JSON layout assembly + reset
- `src/instructions.ts` — System prompt for the agent
- `src/flutter_process.ts` — Manages the Flutter child process
- `src/mcp_server.ts` — MCP server exposing `reset_ui` tool
- `data/` — `turns.json` at runtime (gitignored)
- `.env` — `CURSOR_API_KEY` (gitignored)

**banking_app/lib/**

- `main.dart`, `app_shell.dart`, `app_shell_defaults.dart`, `prompt_modal.dart`, `layout_model.dart`, `component_props.dart`
- `components/current/` — agent-editable widgets; `components/defaults/` — reset snapshots
- `layout/current/` — agent-editable JSON props; `layout/defaults/` — reset snapshots

## Contact

- Email: [xandykati98@gmail.com](mailto:xandykati98@gmail.com)
- Website: [xandykati98.com](https://xandykati98.com)
- GitHub: [xandykati98](https://github.com/xandykati98)

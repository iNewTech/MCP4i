# MCP CLI starter in TypeScript

This project is the TypeScript counterpart to [`cli_project`](../cli_project/README.md). It uses the same six sample documents and exposes the same two MCP tools: `read_doc_contents` and `edit_document`. A command-line MCP client launches the server over stdio and lets a local Ollama model call those tools. No API key or paid account is needed.

This is a generic **in-memory document exercise**, separate from the planned read-only IBM i server. Edits made with `edit_document` disappear when the server stops.

## Requirements

- Node.js 22.19.0 or newer (required by the current MCP Inspector)
- npm
- [Ollama](https://ollama.com/download) running locally
- A tool-capable local model; the default is [`qwen3.5:4b`](https://ollama.com/library/qwen3.5%3A4b)

If you use `nvm`, run `nvm use 22.23.2` in the terminal where you will launch the project. Check with `node -v`.

## Install and chat

From this directory:

```bash
npm ci
ollama pull qwen3.5:4b
npm run dev
```

Try:

```text
> /tools
> /read deposition.md
> hi
> 1+4
> Use read_doc_contents to read deposition.md. Who is named in it?
> /exit
```

`/tools` and `/read` call the MCP server directly. Other text goes to Ollama, which can call the registered MCP tools. The client starts its own server process; do not launch `npm run server` separately for chat. The CLI skips tool definitions for simple greetings and arithmetic to keep those replies focused.

The model and endpoint can be changed before starting:

```bash
export OLLAMA_MODEL=qwen3.5:4b
export OLLAMA_HOST=http://127.0.0.1:11434
npm run dev
```

The first answer after the model loads can take longer. Document questions may require one model call to select a tool and another to answer from its result.

## Inspect the MCP server

```bash
npm run inspect
```

This starts the current MCP Inspector and launches `src/mcp_server.ts` over stdio. Open the **full URL printed in the terminal**, connect, and choose **List Tools**. You should see `read_doc_contents` and `edit_document`. Stop the Inspector with Ctrl+C. The script pins `@latest` to avoid npm reusing a cached v1 Inspector.

For a direct server run without an MCP client, use `npm run server`; it waits for JSON-RPC on stdin and produces no chat prompt. Keep stdout free of logging in a stdio server.

## Build

```bash
npm run build
npm start
```

The built CLI starts the built server from `dist/`. The same tools work in development and built modes.

## Learning map

| Python | TypeScript | Purpose |
| --- | --- | --- |
| `mcp_server.py` | `src/mcp_server.ts` | Register the document tools and serve stdio |
| `mcp_client.py` | `src/mcp_client.ts` | Launch and connect to the server |
| `core/chat.py` | `src/chat.ts` | Send MCP tool schemas to Ollama and return tool results |
| `main.py` | `src/main.ts` | Interactive command-line host |

Resources and prompts remain lesson TODOs in this starter. The Python [`cli_project_COMPLETE`](../cli_project_COMPLETE/README.md) folder shows one completed version of those features. A useful next TypeScript exercise is to register a `docs://documents` resource, then read it from the client.

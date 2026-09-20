# MCP CLI starter with local Ollama

This is the **starter exercise** from the MCP course. It now uses a local Ollama model instead of the Anthropic API; you do not need an API key or paid account. Unlike [`cli_project_COMPLETE`](../cli_project_COMPLETE/README.md), the MCP server and client in this folder deliberately contain TODOs for you to implement as you study.

## Prerequisites

- Python 3.10+ (the commands below use Python 3.12)
- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- [Ollama](https://ollama.com/download) running locally
- A locally installed model with tool support; see the completed project's README for the current recommendation

## Run

```bash
ollama list
uv sync --python 3.12
ollama pull qwen3.5:4b
uv run --python 3.12 main.py
```

The default model is configured in `main.py`. To choose another installed model or a different Ollama server, use **plain shell values** (without Markdown link brackets):

```bash
export OLLAMA_HOST=http://127.0.0.1:11434
export OLLAMA_MODEL=qwen3.5:4b
uv run --python 3.12 main.py
```

You may put the optional settings in `.env`. Any old `ANTHROPIC_API_KEY` and `CLAUDE_MODEL` settings there are no longer used. Avoid committing `.env` because it may contain secrets. The CLI prints its selected model at startup.

## Complete the exercise

Chat and arithmetic work before completing the MCP exercises. The server now registers `read_doc_contents` and `edit_document`. To inspect them with the current Inspector, stop any older Inspector process and run:

```bash
npx -y @modelcontextprotocol/inspector@latest .venv/bin/python mcp_server.py
```

Open the full URL printed in the terminal, connect, and click **List Tools**. Inspector v2 requires Node.js 22.19.0 or newer. Restart the Inspector after changing server code. The functions in `mcp_client.py` still return empty lists, and the server's resources and prompts remain TODOs. Thus the chat CLI cannot yet use those MCP features until you implement the remaining course exercises. Use the completed project as an example while learning.

This is a generic in-memory document demo, separate from the IBM i read-only MCP project.

# MCP Chat with local Ollama

This is the Anthropic Academy CLI exercise adapted to run against an Ollama model on your own computer. It connects to the local document MCP server, supports `@document` mentions and `/` prompts, and lets a tool-capable model call its tools. No paid API key is needed.

The sample MCP server holds documents in memory. Its `edit_document` tool changes those in-memory examples; it does not connect to IBM i. Keep it separate from the MCP4i read-only project tools.

## Prerequisites

- Python 3.10 or newer (Python 3.12 is a good choice).
- [uv](https://docs.astral.sh/uv/getting-started/installation/).
- [Ollama](https://ollama.com/download) running locally with a model that supports tool calling. The default is `qwen3.5:4b`.

Check your installed models with `ollama list`. Install the default model once with `ollama pull qwen3.5:4b` (about 3.4 GB). It supports tools and is smaller than the previous `llama3.1:latest` default. A model without tool-calling support cannot complete the MCP tool exercises. Ollama documents the [tool-calling flow](https://docs.ollama.com/capabilities/tool-calling).

## Run

From this directory:

```bash
uv sync --python 3.12
ollama pull qwen3.5:4b
uv run --python 3.12 main.py
```

The application connects to `http://127.0.0.1:11434` and uses `qwen3.5:4b` by default. Set these optional variables before starting it if your setup differs. Use plain URL text without Markdown brackets:

```bash
export OLLAMA_HOST=http://127.0.0.1:11434
export OLLAMA_MODEL=qwen3.5:4b
```

You can also put those values in a local `.env` file; it is ignored by Git. Do not set `ANTHROPIC_API_KEY` or `CLAUDE_MODEL`. No account or billing setup is needed for the local default endpoint.

The CLI prints the active model on startup. The app disables optional model thinking to keep simple replies quick, and skips sending MCP tool definitions for simple greetings and arithmetic. The first reply after loading a model can take longer; document questions may require another model call to read the document. To try the older model, set `OLLAMA_MODEL=llama3.1:latest`.

## Try the CLI

```text
> What documents are available? Use a tool to check.
> Tell me about @deposition.md
> /format deposition.md
```

Typing `@` selects a document resource, and `/` selects an MCP prompt. The model may call `read_doc_contents` or `edit_document` when the selected prompt asks it to. Press Ctrl+C to quit. Model output varies, so check the returned document contents rather than assuming a proposed tool call ran.

To connect additional local Python MCP server scripts, pass their paths after `main.py`; the application runs them with the same Python environment as the CLI. Tool names across servers should be unique.

## Troubleshooting

- Connection refused: start the Ollama app or `ollama serve`, then check `ollama list`.
- Model not found: pull the value of `OLLAMA_MODEL` or select another installed tool-capable model.
- Tool not called: verify that the selected model supports tools; a plain chat response does not execute an MCP operation.
- Python mismatch: use the `uv run --python 3.12` command above so the CLI and its MCP subprocess use the same environment.

## Learning boundary

This exercise is a generic MCP document demo. IBM i credentials, queries, and read-only interfaces are designed separately in the repository's learning roadmap.

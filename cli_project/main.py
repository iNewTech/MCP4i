import asyncio
import sys
import os
from dotenv import load_dotenv
from contextlib import AsyncExitStack

from mcp_client import MCPClient
from core.ollama_service import OllamaService

from core.cli_chat import CliChat
from core.cli import CliApp

load_dotenv()

async def main():
    ollama_service = OllamaService(
        model=os.getenv("OLLAMA_MODEL", "qwen3.5:4b"),
        host=os.getenv("OLLAMA_HOST", "http://127.0.0.1:11434"),
    )

    server_scripts = sys.argv[1:]
    clients = {}

    async with AsyncExitStack() as stack:
        doc_client = await stack.enter_async_context(
            MCPClient(command=sys.executable, args=["mcp_server.py"])
        )
        clients["doc_client"] = doc_client

        for i, server_script in enumerate(server_scripts):
            client_id = f"client_{i}_{server_script}"
            client = await stack.enter_async_context(
                MCPClient(command=sys.executable, args=[server_script])
            )
            clients[client_id] = client

        chat = CliChat(
            doc_client=doc_client,
            clients=clients,
            ollama_service=ollama_service,
        )

        cli = CliApp(chat)
        await cli.initialize()
        print(f"Ollama model: {ollama_service.model}")
        await cli.run()


if __name__ == "__main__":
    if sys.platform == "win32":
        asyncio.set_event_loop_policy(asyncio.WindowsProactorEventLoopPolicy())
    asyncio.run(main())

import re

from core.ollama_service import OllamaService
from mcp_client import MCPClient
from core.tools import ToolManager


class Chat:
    def __init__(self, ollama_service: OllamaService, clients: dict[str, MCPClient]):
        self.ollama_service = ollama_service
        self.clients: dict[str, MCPClient] = clients
        self.messages: list = [{
            "role": "system",
            "content": (
                f"You are a CLI assistant running locally with Ollama model {ollama_service.model}. "
                "Answer the user's current question directly and concisely. "
                "Use tools when needed for document facts, and never invent document contents. "
                "For ordinary conversation or arithmetic, answer without discussing documents or tools."
            ),
        }]

    async def _process_query(self, query: str):
        self.messages.append({"role": "user", "content": query})

    async def run(
        self,
        query: str,
    ) -> str:
        final_text_response = ""

        await self._process_query(query)
        plain_chat = query.strip().lower().rstrip("!? .") in {
            "hi", "hello", "hey", "ok", "okay", "thanks", "thank you",
            "what is your name", "what is ur name", "which model",
        }
        arithmetic = bool(re.fullmatch(r"\s*\d+(?:\s*[+*/-]\s*\d+)+\s*\??\s*", query))
        tools = [] if plain_chat or arithmetic else await ToolManager.get_all_tools(self.clients)

        while True:
            response = await self.ollama_service.chat(
                messages=self.messages,
                tools=tools,
            )

            # Keep Ollama's assistant message, including tool calls, in the history.
            self.messages.append(response.message)

            if response.message.tool_calls:
                if response.message.content:
                    print(response.message.content)
                tool_results = await ToolManager.execute_tool_requests(self.clients, response.message)
                self.messages.extend(tool_results)
            else:
                final_text_response = response.message.content or ""
                break

        return final_text_response

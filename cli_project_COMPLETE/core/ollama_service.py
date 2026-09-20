from ollama import AsyncClient


class OllamaService:
    def __init__(self, model: str, host: str):
        self.client = AsyncClient(host=host, timeout=120.0)
        self.model = model

    async def chat(self, messages: list, tools: list[dict]):
        return await self.client.chat(
            model=self.model,
            messages=messages,
            tools=tools,
            stream=False,
            think=False,
        )

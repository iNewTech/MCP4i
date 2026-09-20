import json

from mcp.types import TextContent
from mcp_client import MCPClient


class ToolManager:
    @classmethod
    async def get_all_tools(cls, clients: dict[str, MCPClient]) -> list[dict]:
        tools = []
        for client in clients.values():
            for tool in await client.list_tools():
                tools.append(
                    {
                        "type": "function",
                        "function": {
                            "name": tool.name,
                            "description": tool.description or "",
                            "parameters": tool.inputSchema,
                        },
                    }
                )
        return tools

    @classmethod
    async def _find_client_with_tool(
        cls, clients: dict[str, MCPClient], tool_name: str
    ) -> MCPClient | None:
        for client in clients.values():
            if any(tool.name == tool_name for tool in await client.list_tools()):
                return client
        return None

    @classmethod
    async def execute_tool_requests(cls, clients: dict[str, MCPClient], message) -> list[dict]:
        results = []
        for tool_call in message.tool_calls or []:
            name = tool_call.function.name
            client = await cls._find_client_with_tool(clients, name)

            if client is None:
                content = json.dumps({"error": "Could not find that tool"})
            else:
                try:
                    output = await client.call_tool(name, tool_call.function.arguments)
                    parts = [item.text for item in output.content if isinstance(item, TextContent)]
                    content = json.dumps({"error" if output.isError else "result": parts})
                except Exception as exc:
                    content = json.dumps({"error": f"Error executing tool '{name}': {exc}"})

            results.append({"role": "tool", "tool_name": name, "content": content})
        return results

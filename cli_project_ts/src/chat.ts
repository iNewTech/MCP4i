import type { Client } from "@modelcontextprotocol/client";
import { Ollama, type Message, type Tool } from "ollama";

function isSimpleQuestion(query: string): boolean {
  const normalized = query.trim().toLowerCase().replace(/[!? .]+$/u, "");
  const smallTalk = new Set([
    "hi",
    "hello",
    "hey",
    "ok",
    "okay",
    "thanks",
    "thank you",
    "what is your name",
    "what is ur name",
    "which model",
  ]);
  return (
    smallTalk.has(normalized) ||
    /^\s*\d+(?:\s*[+*/-]\s*\d+)+\s*\??\s*$/u.test(query)
  );
}

export class DocumentChat {
  private readonly ollama: Ollama;
  private readonly messages: Message[];
  private tools: Tool[] | undefined;

  constructor(
    private readonly mcpClient: Client,
    readonly model: string,
    host: string,
  ) {
    this.ollama = new Ollama({ host });
    this.messages = [
      {
        role: "system",
        content:
          `You are a CLI assistant running locally with Ollama model ${model}. ` +
          "Answer directly and concisely. Use document tools for document facts; " +
          "never invent document contents. Edit a document only when the user asks. " +
          "For greetings and arithmetic, do not discuss tools.",
      },
    ];
  }

  private async availableTools(): Promise<Tool[]> {
    if (!this.tools) {
      const { tools } = await this.mcpClient.listTools();
      this.tools = tools.map((tool) => ({
        type: "function",
        function: {
          name: tool.name,
          description: tool.description ?? "",
          parameters: tool.inputSchema as Tool["function"]["parameters"],
        },
      }));
    }
    return this.tools;
  }

  async ask(query: string): Promise<string> {
    const tools = isSimpleQuestion(query) ? [] : await this.availableTools();
    this.messages.push({ role: "user", content: query });

    for (let turn = 0; turn < 6; turn += 1) {
      const response = await this.ollama.chat({
        model: this.model,
        messages: this.messages,
        tools,
        think: false,
      });
      this.messages.push(response.message);

      const calls = response.message.tool_calls ?? [];
      if (calls.length === 0) {
        return response.message.content ?? "";
      }

      for (const call of calls) {
        const name = call.function.name;
        if (!tools.some((tool) => tool.function.name === name)) {
          this.messages.push({
            role: "tool",
            tool_name: name,
            content: JSON.stringify({ error: `Unknown tool: ${name}` }),
          });
          continue;
        }

        try {
          const result = await this.mcpClient.callTool({
            name,
            arguments: call.function.arguments,
          });
          const text = result.content
            .map((part) => (part.type === "text" ? part.text : JSON.stringify(part)))
            .join("\n");
          this.messages.push({
            role: "tool",
            tool_name: name,
            content: JSON.stringify(result.isError ? { error: text } : { result: text }),
          });
        } catch (error) {
          this.messages.push({
            role: "tool",
            tool_name: name,
            content: JSON.stringify({ error: String(error) }),
          });
        }
      }
    }

    throw new Error("The model made too many consecutive tool requests.");
  }
}

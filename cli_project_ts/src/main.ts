import { createInterface } from "node:readline";
import { DocumentChat } from "./chat.js";
import { connectDocumentServer } from "./mcp_client.js";

async function main(): Promise<void> {
  const model = process.env.OLLAMA_MODEL || "qwen3.5:4b";
  const host = process.env.OLLAMA_HOST || "http://127.0.0.1:11434";
  const client = await connectDocumentServer();
  const chat = new DocumentChat(client, model, host);
  const input = createInterface({ input: process.stdin, output: process.stdout });
  input.on("SIGINT", () => input.close());

  console.log(`Ollama model: ${model}`);
  console.log("Type /tools, /read <document-id>, or /exit. Ask questions to chat.");
  process.stdout.write("> ");

  try {
    for await (const line of input) {
      const query = line.trim();
      if (query === "/exit" || query === "/quit") break;
      if (!query) {
        process.stdout.write("> ");
        continue;
      }

      try {
        if (query === "/tools") {
          const { tools } = await client.listTools();
          console.log(tools.map((tool) => tool.name).join("\n") || "No tools registered.");
        } else if (query.startsWith("/read ")) {
          const docId = query.slice("/read ".length).trim();
          const result = await client.callTool({
            name: "read_doc_contents",
            arguments: { doc_id: docId },
          });
          for (const part of result.content) {
            if (part.type === "text") console.log(part.text);
          }
        } else {
          console.log(`\nResponse:\n${await chat.ask(query)}`);
        }
      } catch (error) {
        console.error(`Error: ${String(error)}`);
      }
      process.stdout.write("> ");
    }
  } finally {
    input.close();
    await client.close();
  }
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});

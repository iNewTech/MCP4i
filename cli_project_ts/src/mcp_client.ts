import { dirname, extname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/client";
import { StdioClientTransport } from "@modelcontextprotocol/client/stdio";

export async function connectDocumentServer(): Promise<Client> {
  const currentFile = fileURLToPath(import.meta.url);
  const isTypeScript = extname(currentFile) === ".ts";
  const serverFile = join(
    dirname(currentFile),
    isTypeScript ? "mcp_server.ts" : "mcp_server.js",
  );

  // The client launches the stdio server; do not run it separately for chat.
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: isTypeScript ? ["--import", "tsx", serverFile] : [serverFile],
  });
  const client = new Client({ name: "DocumentCLI", version: "0.1.0" });
  await client.connect(transport);
  return client;
}

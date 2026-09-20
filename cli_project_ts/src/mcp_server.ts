import { McpServer } from "@modelcontextprotocol/server";
import { serveStdio } from "@modelcontextprotocol/server/stdio";
import { z } from "zod/v4";

const initialDocuments: Record<string, string> = {
  "deposition.md": "This deposition covers the testimony of Angela Smith, P.E.",
  "report.pdf": "The report details the state of a 20m condenser tower.",
  "financials.docx": "These financials outline the project's budget and expenditures.",
  "outlook.pdf": "This document presents the projected future performance of the system.",
  "plan.md": "The plan outlines the steps for the project's implementation.",
  "spec.txt": "These specifications define the technical requirements for the equipment.",
};

function createServer(): McpServer {
  const server = new McpServer({ name: "DocumentMCP", version: "0.1.0" });
  const documents = { ...initialDocuments };

  server.registerTool(
    "read_doc_contents",
    {
      description: "Read the contents of a document and return it as a string.",
      inputSchema: z.object({
        doc_id: z.string().describe("Id of the document to read"),
      }),
    },
    async ({ doc_id }) => {
      const content = documents[doc_id];
      if (content === undefined) {
        return {
          content: [{ type: "text", text: `Doc with id ${doc_id} not found` }],
          isError: true,
        };
      }
      return { content: [{ type: "text", text: content }] };
    },
  );

  server.registerTool(
    "edit_document",
    {
      description: "Edit a document by replacing a string in its contents.",
      inputSchema: z.object({
        doc_id: z.string().describe("Id of the document to edit"),
        old_string: z.string().describe("String to replace in the document"),
        new_string: z.string().describe("Replacement string"),
      }),
    },
    async ({ doc_id, old_string, new_string }) => {
      const content = documents[doc_id];
      if (content === undefined) {
        return {
          content: [{ type: "text", text: `Document with id '${doc_id}' not found.` }],
          isError: true,
        };
      }
      const updated = content.replaceAll(old_string, new_string);
      documents[doc_id] = updated;
      return { content: [{ type: "text", text: updated }] };
    },
  );

  // TODO: Register a resource that lists all document IDs.
  // TODO: Register a resource that returns a document by ID.
  // TODO: Register prompts to reformat and summarize a document.
  return server;
}

// stdout belongs to the MCP protocol; use stderr for diagnostics.
void serveStdio(createServer);

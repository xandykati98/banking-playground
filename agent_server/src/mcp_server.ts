import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { resetLayout } from "./layout";

const server = new Server(
  { name: "ui-tools", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "reset_ui",
      description:
        "Resets the entire Flutter banking dashboard back to its default layout, " +
        "components, and app shell. Call this when the user asks to reset, undo all " +
        "changes, or restore the original UI.",
      inputSchema: {
        type: "object" as const,
        properties: {},
        required: [],
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  if (request.params.name !== "reset_ui") {
    throw new Error(`Unknown tool: ${request.params.name}`);
  }

  resetLayout();

  return {
    content: [{ type: "text" as const, text: "UI has been reset to defaults." }],
  };
});

const transport = new StdioServerTransport();
server.connect(transport);

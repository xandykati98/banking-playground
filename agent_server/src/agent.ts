import { Agent, CursorAgentError } from "@cursor/sdk";
import path from "path";
import { SYSTEM_INSTRUCTIONS } from "./instructions";
import { ActivityEvent } from "./messages";

const FLUTTER_PROJECT_PATH = path.resolve(__dirname, "../../banking_app");

export async function runAgentPrompt(
  userPrompt: string,
  onEvent: (event: ActivityEvent) => void
): Promise<string> {
  const apiKey = process.env.CURSOR_API_KEY;
  if (!apiKey) {
    throw new Error("CURSOR_API_KEY is not set in environment");
  }

  const agent = await Agent.create({
    apiKey,
    model: { id: "composer-2" },
    local: { cwd: FLUTTER_PROJECT_PATH },
    mcpServers: {
      "ui-tools": {
        type: "stdio",
        command: "npx",
        args: [
          "ts-node",
          "--transpile-only",
          path.resolve(__dirname, "../src/mcp_server.ts"),
        ],
        cwd: path.resolve(__dirname, ".."),
      },
    },
  });

  try {
    const run = await agent.send(
      `${SYSTEM_INSTRUCTIONS}\n\nUser request: ${userPrompt}`
    );

    let finalText = "";

    for await (const event of run.stream()) {
      switch (event.type) {
        case "tool_call":
          onEvent({
            kind: "tool",
            callId: event.call_id,
            toolName: event.name,
            toolStatus: event.status as "running" | "completed" | "error",
          });
          break;

        case "thinking":
          onEvent({ kind: "thinking", delta: event.text });
          break;

        case "assistant":
          for (const block of event.message.content) {
            if (block.type === "text") {
              finalText += block.text;
              onEvent({ kind: "text_delta", delta: block.text });
            }
          }
          break;
      }
    }

    const result = await run.wait();

    if (result.status === "error") {
      throw new Error(`Agent run failed (id: ${result.id})`);
    }

    return result.result ?? (finalText || "Done.");
  } catch (err) {
    if (err instanceof CursorAgentError) {
      throw new Error(
        `Agent failed to start: ${err.message} (retryable: ${err.isRetryable})`
      );
    }
    throw err;
  } finally {
    await agent[Symbol.asyncDispose]();
  }
}

import { Agent, CursorAgentError } from "@cursor/sdk";
import path from "path";
import { SYSTEM_INSTRUCTIONS } from "./instructions";
import { ActivityEvent } from "./messages";

const FLUTTER_PROJECT_PATH = path.resolve(__dirname, "../../banking_app");

// Defensively extracts a file path from tool args. The SDK schema is unstable
// so we try common field names and bail out gracefully if none match.
function extractFilePath(args: unknown): string | undefined {
  if (args === null || typeof args !== "object") return undefined;
  const a = args as Record<string, unknown>;
  const value = a["target_file"] ?? a["path"] ?? a["file_path"] ?? a["filepath"] ?? a["filename"];
  return typeof value === "string" ? value : undefined;
}

export async function runAgentPrompt(
  userPrompt: string,
  onEvent: (event: ActivityEvent) => void
): Promise<string> {
  const apiKey = process.env.CURSOR_API_KEY;
  if (!apiKey) {
    throw new Error("CURSOR_API_KEY is not set in environment");
  }

  console.log("[agent] Creating agent...");
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
  console.log("[agent] Agent created. Sending prompt...");

  try {
    const run = await agent.send(
      `${SYSTEM_INSTRUCTIONS}\n\nUser request: ${userPrompt}`
    );
    console.log(`[agent] Run started (id: ${run.id}). Streaming events...`);

    let finalText = "";
    let eventCount = 0;

    for await (const event of run.stream()) {
      eventCount++;
      switch (event.type) {
        case "tool_call":
          console.log(`[agent] Tool call: ${event.name} (${event.status})`);
          onEvent({
            kind: "tool",
            callId: event.call_id,
            toolName: event.name,
            toolStatus: event.status as "running" | "completed" | "error",
            toolInput: extractFilePath(event.args),
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

    console.log(`[agent] Stream ended (${eventCount} events). Waiting for run result...`);
    const result = await run.wait();
    console.log(`[agent] Run complete — status: ${result.status}`);

    if (result.status === "error") {
      throw new Error(`Agent run failed (id: ${result.id})`);
    }

    return result.result ?? (finalText || "Done.");
  } catch (err) {
    console.error("[agent] Error during run:", err);
    if (err instanceof CursorAgentError) {
      throw new Error(
        `Agent failed to start: ${err.message} (retryable: ${err.isRetryable})`
      );
    }
    throw err;
  } finally {
    console.log("[agent] Disposing agent.");
    await agent[Symbol.asyncDispose]();
  }
}

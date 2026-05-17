import { Agent, CursorAgentError } from "@cursor/sdk";
import path from "path";
import { SYSTEM_INSTRUCTIONS } from "./instructions";

const FLUTTER_PROJECT_PATH = path.resolve(__dirname, "../../banking_app");

export async function runAgentPrompt(userPrompt: string): Promise<string> {
  const apiKey = process.env.CURSOR_API_KEY;
  if (!apiKey) {
    throw new Error("CURSOR_API_KEY is not set in environment");
  }

  const agent = await Agent.create({
    apiKey,
    model: { id: "composer-2" },
    local: { cwd: FLUTTER_PROJECT_PATH },
  });

  try {
    const run = await agent.send(
      `${SYSTEM_INSTRUCTIONS}\n\nUser request: ${userPrompt}`
    );

    const result = await run.wait();

    if (result.status === "error") {
      throw new Error(`Agent run failed (id: ${result.id})`);
    }

    return result.result ?? "Done.";
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

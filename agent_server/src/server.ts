import express, { Request, Response } from "express";
import cors from "cors";
import dotenv from "dotenv";
import { runAgentPrompt } from "./agent";
import { assembleLayout, resetLayout, LAYOUT_CURRENT } from "./layout";
import { startFlutter, FlutterProcess } from "./flutter_process";

dotenv.config();

const app = express();
const PORT = process.env.PORT ?? 3000;

app.use(cors());
app.use(express.json());

// Start the Flutter app as a managed child process.
const flutter: FlutterProcess = startFlutter();

process.on("exit", () => flutter.kill());
process.on("SIGINT", () => { flutter.kill(); process.exit(); });
process.on("SIGTERM", () => { flutter.kill(); process.exit(); });

interface PromptRequestBody {
  prompt: string;
}

interface PromptResponseBody {
  status: "ok" | "error";
  message: string;
}

app.get("/health", (_req: Request, res: Response) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

app.get("/layout", (_req: Request, res: Response) => {
  try {
    const layout = assembleLayout(LAYOUT_CURRENT);
    res.json(layout);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    res.status(500).json({ error: message });
  }
});

app.post("/reset", async (_req: Request, res: Response) => {
  try {
    resetLayout();
    // Await the restart so files are fully flushed before Flutter recompiles.
    await flutter.restart();
    res.json({ status: "ok", message: "Layout reset to defaults." });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    res.status(500).json({ status: "error", message });
  }
});

app.post(
  "/prompt",
  async (
    req: Request<{}, PromptResponseBody, PromptRequestBody>,
    res: Response<PromptResponseBody>
  ) => {
    const { prompt } = req.body;

    if (!prompt || typeof prompt !== "string" || prompt.trim() === "") {
      res.status(400).json({ status: "error", message: "prompt is required" });
      return;
    }

    try {
      const message = await runAgentPrompt(prompt.trim());
      // Await the restart so Flutter recompiles before the response reaches the client.
      // The client's onPromptComplete (layout reload) then runs against the new code.
      try {
        await flutter.restart();
      } catch {
        // Restart failure is non-fatal — still return the agent's message.
      }
      res.json({ status: "ok", message });
    } catch (err) {
      const message = err instanceof Error ? err.message : "Unknown error";
      console.error("[prompt error]", message);
      res.status(500).json({ status: "error", message });
    }
  }
);

app.listen(PORT, () => {
  console.log(`Agent server running on http://localhost:${PORT}`);
});

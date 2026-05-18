import express, { Request, Response } from "express";
import cors from "cors";
import dotenv from "dotenv";
import { runAgentPrompt } from "./agent";
import { assembleLayout, resetLayout, LAYOUT_CURRENT } from "./layout";
import { startFlutter, FlutterProcess } from "./flutter_process";
import {
  addMessage,
  getHistory,
  broadcast,
  addSseClient,
  removeSseClient,
  startRun,
  endRun,
  ChatMessage,
} from "./messages";

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

// Returns the full persisted chat history.
app.get("/messages", (_req: Request, res: Response<ChatMessage[]>) => {
  res.json(getHistory());
});

// SSE endpoint — Flutter subscribes here to receive live agent activity events.
app.get("/events", (req: Request, res: Response) => {
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.setHeader("X-Accel-Buffering", "no");
  res.flushHeaders();

  addSseClient(res);
  req.on("close", () => removeSseClient(res));
});

app.post("/reset", async (_req: Request, res: Response) => {
  try {
    resetLayout();
    await flutter.restart();
    const msg = addMessage("assistant", "UI reset to defaults.");
    broadcast({ kind: "done" });
    res.json({ status: "ok", message: msg.text });
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

    addMessage("user", prompt.trim());
    startRun();

    try {
      const message = await runAgentPrompt(prompt.trim(), broadcast);

      try {
        await flutter.restart();
      } catch {
        // Restart failure is non-fatal.
      }

      addMessage("assistant", message);
      endRun();
      broadcast({ kind: "done" });
      res.json({ status: "ok", message });
    } catch (err) {
      const message = err instanceof Error ? err.message : "Unknown error";
      console.error("[prompt error]", message);
      addMessage("assistant", message, true);
      endRun();
      broadcast({ kind: "done", isError: true });
      res.status(500).json({ status: "error", message });
    }
  }
);

app.listen(PORT, () => {
  console.log(`Agent server running on http://localhost:${PORT}`);
});

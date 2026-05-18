import express, { Request, Response } from "express";
import cors from "cors";
import dotenv from "dotenv";
import WebSocket from "ws";
import { runAgentPrompt } from "./agent";
import {
  assembleLayout,
  resetLayout,
  LAYOUT_CURRENT,
} from "./layout";

dotenv.config();

const app = express();
const PORT = process.env.PORT ?? 3000;

app.use(cors());
app.use(express.json());

interface PromptRequestBody {
  prompt: string;
}

interface PromptResponseBody {
  status: "ok" | "error";
  message: string;
}

// Connects to the Flutter VM Service and triggers a hot reload.
// Silently no-ops if Flutter isn't running or the VM service is unreachable.
function triggerHotReload(): Promise<void> {
  return new Promise((resolve) => {
    let ws: WebSocket;
    try {
      ws = new WebSocket("ws://localhost:8181/ws");
    } catch {
      resolve();
      return;
    }

    const timeout = setTimeout(() => {
      ws.terminate();
      resolve();
    }, 5000);

    let msgId = 0;

    ws.on("open", () => {
      ws.send(
        JSON.stringify({ jsonrpc: "2.0", id: ++msgId, method: "getVM", params: {} })
      );
    });

    ws.on("message", (raw) => {
      try {
        const msg = JSON.parse(raw.toString()) as {
          id: number;
          result?: { isolates?: Array<{ id: string; runnable: boolean }> };
          error?: { message: string };
        };

        if (msg.id === 1) {
          const isolate = msg.result?.isolates?.find((i) => i.runnable);
          if (!isolate) {
            clearTimeout(timeout);
            ws.close();
            resolve();
            return;
          }
          ws.send(
            JSON.stringify({
              jsonrpc: "2.0",
              id: ++msgId,
              method: "reloadSources",
              params: { isolateId: isolate.id },
            })
          );
        } else if (msg.id === 2) {
          clearTimeout(timeout);
          ws.close();
          if (msg.error) {
            console.warn("[hot-reload] VM error:", msg.error.message);
          } else {
            console.log("[hot-reload] Hot reload triggered.");
          }
          resolve();
        }
      } catch {
        clearTimeout(timeout);
        ws.close();
        resolve();
      }
    });

    ws.on("error", () => {
      clearTimeout(timeout);
      resolve();
    });
  });
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

app.post("/reset", (_req: Request, res: Response) => {
  try {
    resetLayout();
    triggerHotReload().catch(() => undefined);
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
      // Fire hot reload in the background — don't block the response.
      triggerHotReload().catch(() => undefined);
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

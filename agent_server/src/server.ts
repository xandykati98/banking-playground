import express, { Request, Response } from "express";
import cors from "cors";
import dotenv from "dotenv";
import fs from "fs";
import path from "path";
import { runAgentPrompt } from "./agent";

dotenv.config();

const app = express();
const PORT = process.env.PORT ?? 3000;

const LAYOUT_CURRENT = path.resolve(
  __dirname,
  "../../banking_app/lib/layout/current"
);
const LAYOUT_DEFAULTS = path.resolve(
  __dirname,
  "../../banking_app/lib/layout/defaults"
);
const COMPONENTS_CURRENT = path.resolve(
  __dirname,
  "../../banking_app/lib/components"
);
const COMPONENTS_DEFAULTS = path.resolve(
  __dirname,
  "../../banking_app/lib/components_defaults"
);
const APP_SHELL_CURRENT = path.resolve(
  __dirname,
  "../../banking_app/lib/app_shell.dart"
);
const APP_SHELL_DEFAULTS = path.resolve(
  __dirname,
  "../../banking_app/lib/app_shell_defaults.dart"
);

app.use(cors());
app.use(express.json());

interface PromptRequestBody {
  prompt: string;
}

interface PromptResponseBody {
  status: "ok" | "error";
  message: string;
}

// Reads dashboard.json (root props) + all other *.json component files from a
// layout directory and assembles them into the shape Flutter expects:
//   { id, props, children: [...sorted by order] }
function assembleLayout(dir: string): object {
  const rootPath = path.join(dir, "dashboard.json");
  const root = JSON.parse(fs.readFileSync(rootPath, "utf-8")) as {
    id: string;
    props: Record<string, string>;
  };

  const componentFiles = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith(".json") && f !== "dashboard.json");

  const children = componentFiles
    .map((f) => JSON.parse(fs.readFileSync(path.join(dir, f), "utf-8")))
    .sort(
      (a: { order?: number }, b: { order?: number }) =>
        (a.order ?? 0) - (b.order ?? 0)
    );

  return { ...root, children };
}

function resetDir(
  defaultsDir: string,
  currentDir: string,
  ext: string
): void {
  const defaultFiles = fs
    .readdirSync(defaultsDir)
    .filter((f) => f.endsWith(ext));

  for (const file of defaultFiles) {
    fs.copyFileSync(
      path.join(defaultsDir, file),
      path.join(currentDir, file)
    );
  }

  // Remove any extra files in current that the agent may have created.
  const currentFiles = fs
    .readdirSync(currentDir)
    .filter((f) => f.endsWith(ext));

  for (const file of currentFiles) {
    if (!defaultFiles.includes(file)) {
      fs.unlinkSync(path.join(currentDir, file));
    }
  }
}

function resetLayout(): void {
  resetDir(LAYOUT_DEFAULTS, LAYOUT_CURRENT, ".json");
  resetDir(COMPONENTS_DEFAULTS, COMPONENTS_CURRENT, ".dart");
  fs.copyFileSync(APP_SHELL_DEFAULTS, APP_SHELL_CURRENT);
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

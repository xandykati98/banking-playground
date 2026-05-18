import { spawn } from "child_process";
import readline from "readline";
import path from "path";

interface PendingCallback {
  resolve: () => void;
  reject: (err: Error) => void;
}

export interface FlutterProcess {
  restart(): Promise<void>;
  kill(): void;
}

const BANKING_APP_PATH = path.resolve(__dirname, "../../banking_app");

export function startFlutter(): FlutterProcess {
  let appId: string | null = null;
  let msgId = 0;
  const pending = new Map<number, PendingCallback>();

  const proc = spawn("flutter", ["run", "-d", "chrome", "--machine"], {
    cwd: BANKING_APP_PATH,
    shell: true,
    stdio: ["pipe", "pipe", "inherit"],
  });

  const rl = readline.createInterface({ input: proc.stdout! });

  rl.on("line", (line) => {
    let parsed: unknown;
    try {
      parsed = JSON.parse(line);
    } catch {
      if (line.trim()) process.stdout.write(`[flutter] ${line}\n`);
      return;
    }

    const messages = Array.isArray(parsed)
      ? (parsed as Array<Record<string, unknown>>)
      : ([parsed] as Array<Record<string, unknown>>);

    for (const msg of messages) {
      // Resolve pending command responses.
      if (typeof msg.id === "number" && pending.has(msg.id)) {
        const cb = pending.get(msg.id)!;
        pending.delete(msg.id);
        const result = msg.result as { code?: number } | undefined;
        if (result?.code === 0) {
          console.log("[flutter] Hot restart complete.");
          cb.resolve();
        } else {
          cb.reject(new Error(String(msg.error ?? "restart failed")));
        }
        continue;
      }

      // Capture app ID from start events.
      if (msg.event === "app.start" || msg.event === "app.started") {
        const params = msg.params as { appId?: string } | undefined;
        if (params?.appId) {
          appId = params.appId;
          console.log(`[flutter] App ready — appId: ${appId}`);
        }
      }
    }
  });

  proc.on("exit", (code) => {
    console.log(`[flutter] Process exited with code ${code}`);
    for (const cb of pending.values()) {
      cb.reject(new Error("Flutter process exited"));
    }
    pending.clear();
  });

  return {
    restart(): Promise<void> {
      if (!appId) {
        console.warn("[flutter] App not ready yet — skipping hot restart.");
        return Promise.resolve();
      }
      return new Promise<void>((resolve, reject) => {
        const id = ++msgId;
        pending.set(id, { resolve, reject });

        const command =
          JSON.stringify([
            {
              id,
              method: "app.restart",
              params: { appId, fullRestart: true, pause: false },
            },
          ]) + "\n";

        proc.stdin!.write(command, (err) => {
          if (err) {
            pending.delete(id);
            reject(err);
          }
        });
      });
    },

    kill() {
      proc.kill();
    },
  };
}

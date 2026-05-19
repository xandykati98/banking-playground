import fs from "fs";
import path from "path";
import { Response } from "express";

// ─── Types ─────────────────────────────────────────────────────────────────

export type ChatRole = "user" | "assistant";

export interface ChatMessage {
  id: string;
  role: ChatRole;
  text: string;
  isError: boolean;
  timestamp: number;
}

export type ActivityEventKind = "tool" | "thinking" | "text_delta" | "done" | "restarting" | "start";

export interface ActivityEvent {
  kind: ActivityEventKind;
  // Unique per tool invocation — used to update status in place on the client.
  callId?: string;
  toolName?: string;
  toolStatus?: "running" | "completed" | "error";
  // Best-effort file path extracted from tool args (unstable schema — parsed defensively).
  toolInput?: string;
  delta?: string;
  isError?: boolean;
}

export interface TurnRecord {
  userText: string;
  events: ActivityEvent[];
}

// ─── Persistence ────────────────────────────────────────────────────────────

const DATA_DIR = path.resolve(__dirname, "../data");
const TURNS_FILE = path.join(DATA_DIR, "turns.json");

function loadTurnsFromDisk(): TurnRecord[] {
  try {
    if (!fs.existsSync(TURNS_FILE)) return [];
    const raw = fs.readFileSync(TURNS_FILE, "utf-8");
    return JSON.parse(raw) as TurnRecord[];
  } catch {
    return [];
  }
}

function saveTurnsToDisk(records: TurnRecord[]): void {
  try {
    fs.mkdirSync(DATA_DIR, { recursive: true });
    fs.writeFileSync(TURNS_FILE, JSON.stringify(records, null, 2), "utf-8");
  } catch (err) {
    console.error("[messages] Failed to persist turns:", err);
  }
}

// ─── In-memory store ────────────────────────────────────────────────────────

const chatHistory: ChatMessage[] = [];

// Completed turns — loaded from disk on startup and written back after each run.
const turns: TurnRecord[] = loadTurnsFromDisk();
let currentTurnUserText = "";

// Buffer of events from the currently-running agent turn.
// Replayed to any SSE client that connects mid-run (e.g. after a Flutter restart).
let runBuffer: ActivityEvent[] = [];
let runActive = false;

function makeId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

export function addMessage(role: ChatRole, text: string, isError = false): ChatMessage {
  const msg: ChatMessage = { id: makeId(), role, text, isError, timestamp: Date.now() };
  chatHistory.push(msg);
  return msg;
}

export function getHistory(): ChatMessage[] {
  return chatHistory;
}

export function getTurns(): TurnRecord[] {
  return turns;
}

export function clearTurns(): void {
  turns.length = 0;
  saveTurnsToDisk(turns);
}

export function startRun(userText: string): void {
  currentTurnUserText = userText;
  // Seed the buffer with a start event so reconnecting clients (e.g. after a
  // Flutter hot restart) can recover the live turn's user text and existing events.
  runBuffer = [{ kind: "start", delta: userText }];
  runActive = true;
}

export function endRun(): void {
  runActive = false;
  // Snapshot completed turn (exclude the sentinel start/done events).
  const events = runBuffer.filter((e) => e.kind !== "start" && e.kind !== "done");
  if (currentTurnUserText) {
    turns.push({ userText: currentTurnUserText, events });
    saveTurnsToDisk(turns);
  }
  // Intentionally keep runBuffer — reconnecting clients after a completed
  // run still need to replay the full sequence (including the done event).
}

// ─── SSE broadcast ─────────────────────────────────────────────────────────

const sseClients = new Set<Response>();

export function addSseClient(res: Response): void {
  // Only replay when a run is still in progress — Flutter needs to recover
  // mid-run state after a hot restart. When the run is already done, Flutter
  // loads history via GET /turns in initState instead; replaying a stale
  // start→events→done sequence would race with that request and wipe the
  // already-loaded turn list.
  if (runActive) {
    for (const event of runBuffer) {
      res.write(`data: ${JSON.stringify(event)}\n\n`);
    }
  }
  sseClients.add(res);
}

export function removeSseClient(res: Response): void {
  sseClients.delete(res);
}

export function broadcast(event: ActivityEvent): void {
  // Buffer every event (including "done") so replays are complete.
  runBuffer.push(event);

  const payload = `data: ${JSON.stringify(event)}\n\n`;
  for (const client of sseClients) {
    client.write(payload);
  }
}

// Sends an event to connected clients without buffering — reconnecting clients
// after a Flutter restart will not replay it.
export function broadcastTransient(event: ActivityEvent): void {
  const payload = `data: ${JSON.stringify(event)}\n\n`;
  for (const client of sseClients) {
    client.write(payload);
  }
}

// Sends an SSE comment to all connected clients to keep connections alive and
// flush sockets that have silently died (write errors trigger 'close' on the
// request, which removes the client from the set).
export function pingClients(): void {
  for (const client of sseClients) {
    client.write(": keepalive\n\n");
  }
}

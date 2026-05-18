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

export type ActivityEventKind = "tool" | "thinking" | "text_delta" | "done" | "restarting";

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

// ─── In-memory store ────────────────────────────────────────────────────────

const chatHistory: ChatMessage[] = [];

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

export function startRun(): void {
  // Keep the previous run's events in the buffer — a client reconnecting
  // between runs can still replay them. The buffer only resets here so new
  // events don't pile on top of stale ones from the previous session.
  runBuffer = [];
  runActive = true;
}

export function endRun(): void {
  runActive = false;
  // Intentionally keep runBuffer — reconnecting clients after a completed
  // run still need to replay the full sequence (including the done event).
}

// ─── SSE broadcast ─────────────────────────────────────────────────────────

const sseClients = new Set<Response>();

export function addSseClient(res: Response): void {
  // Replay the full buffer to any connecting client — whether the run is
  // still active or already finished. The client handles both cases via
  // the presence/absence of a "done" event at the end.
  for (const event of runBuffer) {
    res.write(`data: ${JSON.stringify(event)}\n\n`);
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

import { validateDraft, type GridDraft } from "../src/draft.js";

type ToolResult = { isError?: boolean; structuredContent?: unknown; _meta?: Record<string, unknown> };
type CallTool = (params: { name: string; arguments: Record<string, unknown> }) => Promise<ToolResult>;
export type SaveOutcome = { state: "saved"; url: string } | { state: "error" | "auth"; message: string };

export function privateGridUrl(value: unknown): string | undefined {
  if (typeof value !== "string") return;
  try {
    const url = new URL(value);
    if (["https:", "http:"].includes(url.protocol) && !url.username && !url.password && /^\/g\/[^/]+$/.test(url.pathname)) return url.href;
  } catch { return; }
}

export class GridSave {
  readonly draft: GridDraft;
  private pending?: Promise<SaveOutcome>;
  private saved?: SaveOutcome;

  constructor(draft: unknown, private callTool: CallTool) {
    this.draft = validateDraft(draft);
  }

  save(): Promise<SaveOutcome> {
    if (this.saved) return Promise.resolve(this.saved);
    if (this.pending) return this.pending;
    this.pending = this.performSave().finally(() => { this.pending = undefined; });
    return this.pending;
  }

  private async performSave(): Promise<SaveOutcome> {
    try {
      const result = await this.callTool({ name: "create_grid", arguments: structuredClone(this.draft) });
      if (result.isError) {
        if (result._meta?.["mcp/www_authenticate"]) {
          return { state: "auth", message: "Account linking is needed. Continue in chat to connect and save this same draft, or retry after connecting." };
        }
        return { state: "error", message: "The save was not confirmed. You can retry safely with this same draft." };
      }
      const data = result.structuredContent as { grid?: Record<string, unknown> } | undefined;
      const grid = data?.grid;
      const url = privateGridUrl(grid?.url);
      if (!url || grid?.visibility !== "private") {
        return { state: "error", message: "The server returned an unexpected result. The save was not confirmed; retry with this same draft." };
      }
      this.saved = { state: "saved", url };
      return this.saved;
    } catch {
      return { state: "error", message: "The connection was interrupted. The save may have completed; retry safely with this same draft." };
    }
  }
}

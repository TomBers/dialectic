import { z } from "zod";

export const draftSchema = z.object({
  request_id: z.uuid().describe("A fresh UUID per intended save. Reuse it with the identical payload after an uncertain outcome."),
  title: z.string().trim().min(1).max(140),
  nodes: z.array(z.object({
    id: z.string().min(1).max(64),
    content: z.string().trim().min(1).max(4000),
    kind: z.enum(["origin", "question", "answer", "thesis", "antithesis", "synthesis", "premise", "conclusion", "ideas", "clarify", "assumptions", "counterexample", "implications", "blind_spots", "says_who", "who_disagrees", "steel_man", "what_if"]),
  })).min(1).max(50),
  edges: z.array(z.object({ from: z.string().min(1).max(64), to: z.string().min(1).max(64) })).max(150),
  tags: z.array(z.string().trim().min(1).max(40)).max(10).default([]),
});

export type GridDraft = z.infer<typeof draftSchema>;

export function validateDraft(value: unknown): GridDraft {
  const draft = draftSchema.parse(value);
  if (new TextEncoder().encode(JSON.stringify(draft)).length > 64_000) throw new Error("Keep the grid under 64KB.");
  const nodes = new Map(draft.nodes.map(node => [node.id, node]));
  const roots = draft.nodes.filter(node => node.kind === "origin");
  if (nodes.size !== draft.nodes.length || roots.length !== 1) throw new Error("Use unique node IDs and exactly one origin.");
  const outgoing = new Map(draft.nodes.map(node => [node.id, [] as string[]]));
  const edgeKeys = new Set<string>();
  for (const edge of draft.edges) {
    const key = JSON.stringify([edge.from, edge.to]);
    if (!nodes.has(edge.from) || !nodes.has(edge.to) || edge.to === roots[0].id || edge.from === edge.to || edgeKeys.has(key)) {
      throw new Error("Use unique connections between existing nodes, with no edges into the origin.");
    }
    edgeKeys.add(key);
    outgoing.get(edge.from)!.push(edge.to);
  }
  const visiting = new Set<string>();
  const visited = new Set<string>();
  function visit(id: string) {
    if (visiting.has(id)) throw new Error("Connections must not contain cycles.");
    if (visited.has(id)) return;
    visiting.add(id);
    for (const child of outgoing.get(id)!) visit(child);
    visiting.delete(id);
    visited.add(id);
  }
  visit(roots[0].id);
  if (visited.size !== nodes.size) throw new Error("Connect every idea to the origin.");
  return draft;
}

export const previewSchema = z.object({ status: z.literal("draft"), draft: draftSchema });

export function previewResult(value: unknown) {
  const draft = validateDraft(value);
  return {
    structuredContent: { status: "draft" as const, draft },
    content: [{ type: "text" as const, text: `Draft only — nothing saved. Review these selected ideas before saving privately.\n${JSON.stringify(draft, null, 2)}` }],
  };
}

import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { validateDraft } from "../src/draft.js";
import { GridSave, privateGridUrl } from "../ui/save.js";

const draft = {
  request_id: randomUUID(), title: "Reviewed ideas", tags: [],
  nodes: [{ id: "root", kind: "origin", content: "What should we do?" }], edges: [],
};
const success = { structuredContent: { grid: { visibility: "private", url: "https://rationalgrid.ai/g/reviewed-ideas" } } };

test("save calls the existing tool only on demand, coalesces clicks, and remembers success", async () => {
  const calls: unknown[] = [];
  const saver = new GridSave(draft, async params => { calls.push(params); return success; });
  assert.equal(calls.length, 0);
  const first = saver.save();
  const second = saver.save();
  assert.equal(first, second);
  assert.deepEqual(await first, { state: "saved", url: success.structuredContent.grid.url });
  await saver.save();
  assert.deepEqual(calls, [{ name: "create_grid", arguments: draft }]);
});

test("network failures and auth challenges preserve the exact request id and payload", async () => {
  const calls: unknown[] = [];
  const saver = new GridSave(draft, async params => {
    calls.push(params);
    if (calls.length === 1) throw new Error("timeout");
    if (calls.length === 2) return { isError: true, _meta: { "mcp/www_authenticate": ["Bearer"] } };
    return success;
  });
  assert.equal((await saver.save()).state, "error");
  assert.equal((await saver.save()).state, "auth");
  assert.equal((await saver.save()).state, "saved");
  assert.equal(calls.length, 3);
  assert.deepEqual(calls[0], calls[1]);
  assert.deepEqual(calls[1], calls[2]);
});

test("save snapshots inputs rather than trusting later changes to the caller's object", async () => {
  const input = structuredClone(draft);
  const saver = new GridSave(input, async params => {
    assert.deepEqual(params.arguments, draft);
    return success;
  });
  input.title = "Changed after preview";
  input.nodes[0].content = "Changed too";
  assert.equal((await saver.save()).state, "saved");
});

test("malformed responses and unsafe links cannot claim a successful private save", async () => {
  for (const result of [
    {}, { isError: true }, { structuredContent: null },
    { structuredContent: { grid: { visibility: "public", url: success.structuredContent.grid.url } } },
    { structuredContent: { grid: { visibility: "private", url: "javascript:alert(1)" } } },
    { structuredContent: { grid: { visibility: "private", url: "https://user:password@example.com/g/grid" } } },
  ]) {
    const saver = new GridSave(draft, async () => result);
    assert.equal((await saver.save()).state, "error");
  }
  assert.equal(privateGridUrl("data:text/html,hello"), undefined);
  assert.equal(privateGridUrl("/g/relative"), undefined);
});

test("validation handles connected DAGs, cycles away from the origin, and payload limits", () => {
  const branch = {
    ...draft,
    nodes: [...draft.nodes, { id: "second", kind: "thesis", content: "Second" }, { id: "third", kind: "question", content: "Third" }],
    edges: [{ from: "root", to: "second" }, { from: "second", to: "third" }],
  };
  assert.deepEqual(validateDraft(branch), branch);
  assert.throws(() => validateDraft({ ...branch, edges: [...branch.edges, { from: "third", to: "second" }] }), /cycles/);
  assert.throws(() => validateDraft({ ...branch, edges: [...branch.edges, branch.edges[0]] }), /unique/);
  assert.throws(() => validateDraft({ ...draft, nodes: Array.from({ length: 20 }, (_, index) => ({ id: String(index), kind: index ? "answer" : "origin", content: "x".repeat(4000) })) }), /64KB/);
});

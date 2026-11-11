import { afterEach, describe, expect, it, vi } from "vitest";
import { retainHighlights } from "../highlight_cache.js";
import SelectionActionsHook from "../selection_actions_hook.js";
import TextSelectionHook from "../text_selection_hook.js";

const graphId = "highlight-lifecycle";
let hooks = [];
let release;

function mountAnswer(id, html = "Alpha <strong>bravo</strong>") {
  const el = document.createElement("div");
  el.id = `answer-${id}`;
  Object.assign(el.dataset, {nodeId: id, mudgId: graphId, highlightsOnly: "true"});
  el.innerHTML = `<div phx-hook="Markdown" data-body-only="true">${html}</div>`;
  document.body.append(el);
  const hook = Object.assign(Object.create(TextSelectionHook), {el, handleEvent: vi.fn()});
  hook.mounted();
  hooks.push(hook);
  return hook;
}

function send(highlights) {
  window.dispatchEvent(new CustomEvent("phx:highlights_loaded", {detail: {graph_id: graphId, highlights}}));
}

afterEach(() => {
  hooks.forEach(hook => hook.destroyed());
  hooks = [];
  release?.();
  release = null;
  document.body.replaceChildren();
});

describe("saved highlights across answer navigation", () => {
  it("restores marks, links and duplicate detection after visiting an origin without answer hooks", () => {
    release = retainHighlights(graphId);
    const first = mountAnswer("2");
    const saved = {id: 1, node_id: "2", selection_start: 0, selection_end: 5, links: [{node_id: "3", link_type: "explain"}]};
    send([saved]);
    expect(first.el.querySelector("mark").textContent).toBe("Alpha");
    first.destroyed();
    first.el.remove();
    hooks = [];
    const returned = mountAnswer("2");
    expect(returned.el.querySelector("mark").textContent).toBe("Alpha");
    expect(returned.el.querySelector(".highlight-link-icon").getAttribute("phx-value-node_id")).toBe("3");
    expect(SelectionActionsHook.exactHighlightForSelection.call({
      answerContext: () => false,
      selectionData: {nodeId: "2", offsets: {start: 0, end: 5}},
      componentEl: {dataset: {graphId}},
    })).toEqual(saved);
  });

  it("renders other subscribers when sanitized Markdown contains an unsigned highlight class", () => {
    release = retainHighlights(graphId);
    const authored = mountAnswer("1", '<mark class="highlight-span"><strong>Alpha</strong></mark> bravo');
    const other = mountAnswer("2");
    expect(authored.el.querySelector(".highlight-span")).toBeNull();
    expect(authored.el.querySelector("strong").textContent).toBe("Alpha");
    send(["1", "2"].map(id => ({id, node_id: id, selection_start: 0, selection_end: 5, links: []})));
    expect(authored.el.querySelector("mark").textContent).toBe("Alpha");
    expect(other.el.querySelector("mark").textContent).toBe("Alpha");
  });
});

import { afterEach, describe, expect, it } from "vitest";
import HighlightUtils from "../highlight_utils.js";

afterEach(() => { document.body.replaceChildren(); });
const highlight = (id, start, end, links = []) => ({id, selection_start: start, selection_end: end, links});
function passage() {
  const root = document.createElement("div");
  root.innerHTML = "Alpha <strong>bravo</strong> charlie delta";
  document.body.append(root);
  return root;
}
const mark = (root, id) => root.querySelector(`[data-highlight-id="${id}"]`);

describe("incremental saved highlights", () => {
  it.each([undefined, "invalid JSON", "null", "[]", '{}', '{"start":0,"end":5}'])(
    "removes stale marks with signature %s without losing text or formatting", (signature) => {
      const root = passage();
      const stale = document.createElement("mark");
      stale.className = "highlight-span";
      if (signature !== undefined) {
        stale.dataset.highlightId = "1";
        stale.dataset.highlightSignature = signature;
      }
      const strong = root.querySelector("strong");
      strong.replaceWith(stale);
      stale.append(strong);
      const original = root.textContent;
      expect(() => HighlightUtils.renderHighlights(root, [])).not.toThrow();
      expect(root.querySelector(".highlight-span")).toBeNull();
      expect(root.textContent).toBe(original);
      expect(root.querySelector("strong")).toBe(strong);
    },
  );

  it.each([undefined, "invalid JSON", "null", "[]", '{}', '{"start":0,"end":5}'])(
    "rebuilds saved highlights with signature %s and keeps their links", (signature) => {
      const root = passage();
      const saved = highlight(1, 0, 5, [{node_id: "42", link_type: "explain"}]);
      HighlightUtils.renderHighlights(root, [saved]);
      const stale = mark(root, 1);
      if (signature === undefined) delete stale.dataset.highlightSignature;
      else stale.dataset.highlightSignature = signature;
      expect(() => HighlightUtils.renderHighlights(root, [saved])).not.toThrow();
      expect(mark(root, 1)).not.toBe(stale);
      expect(mark(root, 1).textContent).toBe("Alpha");
      expect(root.querySelectorAll(".highlight-link-icon")).toHaveLength(1);
      expect(root.querySelector(".highlight-link-icon").getAttribute("phx-value-node_id")).toBe("42");
    },
  );

  it("preserves other marks and formatting when adding, moving and removing a highlight", () => {
    const root = passage();
    const original = root.textContent;
    const one = highlight(1, 0, 5);
    const two = highlight(2, 12, 19);
    HighlightUtils.renderHighlights(root, [one]);
    const retained = mark(root, 1);
    HighlightUtils.renderHighlights(root, [one, two]);
    expect(mark(root, 1)).toBe(retained);
    expect(mark(root, 2).textContent).toBe("charlie");
    HighlightUtils.renderHighlights(root, [one, highlight(2, 20, 25)]);
    expect(mark(root, 1)).toBe(retained);
    expect(mark(root, 2).textContent).toBe("delta");
    HighlightUtils.renderHighlights(root, [one]);
    expect(mark(root, 2)).toBeNull();
    expect(mark(root, 1)).toBe(retained);
    expect(root.textContent).toBe(original);
    expect(root.querySelector("strong").textContent).toBe("bravo");
  });

  it("updates linked actions without replacing highlighted text", () => {
    const root = passage();
    HighlightUtils.renderHighlights(root, [highlight(1, 0, 5)]);
    const retained = mark(root, 1);
    HighlightUtils.renderHighlights(root, [highlight(1, 0, 5, [{node_id: "42", link_type: "explain"}])]);
    expect(mark(root, 1)).toBe(retained);
    expect(retained.dataset.linkedNodeId).toBe("42");
    expect(root.querySelector('.highlight-link-icon').getAttribute("phx-value-node_id")).toBe("42");
    HighlightUtils.renderHighlights(root, [highlight(1, 0, 5)]);
    expect(mark(root, 1)).toBe(retained);
    expect(retained.hasAttribute("data-linked-node-id")).toBe(false);
    expect(root.querySelector('.highlight-links-container')).toBeNull();
  });

  it("keeps offsets across formatting, emoji, multiple new highlights and overlaps", () => {
    const root = passage();
    root.prepend("😀 ");
    const text = root.textContent;
    HighlightUtils.renderHighlights(root, [highlight(1, 3, 8), highlight(2, 9, 22)]);
    expect(mark(root, 1).textContent).toBe("Alpha");
    expect([...root.querySelectorAll('mark[data-highlight-id="2"]')].map(n => n.textContent).join("")).toBe("bravo charlie");
    HighlightUtils.renderHighlights(root, [highlight(1, 3, 8), highlight(2, 9, 22), highlight(3, 5, 13)]);
    expect([...root.querySelectorAll('mark[data-highlight-id="3"]')].map(n => n.textContent).join("")).toBe(text.slice(5, 13));
    HighlightUtils.removeHighlights(root);
    expect(root.textContent).toBe(text);
    expect(root.querySelector("mark")).toBeNull();
  });
});

it("walks the text once for many new nonoverlapping highlights", () => {
  const root = document.createElement("div");
  root.textContent = "word ".repeat(50);
  document.body.append(root);
  const highlights = Array.from({length: 50}, (_, id) => highlight(id, id * 5, id * 5 + 4));
  const original = document.createTreeWalker.bind(document);
  let walks = 0;
  document.createTreeWalker = (...args) => { if (args[0] === root) walks++; return original(...args); };
  try {
    HighlightUtils.renderHighlights(root, highlights);
    expect(walks).toBe(1);
    expect(root.querySelectorAll("mark")).toHaveLength(50);
    expect([...root.querySelectorAll("mark")].every(node => node.textContent === "word")).toBe(true);
    const retained = mark(root, 49);
    const before = walks;
    HighlightUtils.renderHighlights(root, highlights);
    expect(walks).toBe(before);
    expect(mark(root, 49)).toBe(retained);
  } finally { document.createTreeWalker = original; }
});

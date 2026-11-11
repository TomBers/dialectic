import {afterEach, describe, expect, it, vi} from "vitest";
import SearchHighlights, {searchMatchRanges} from "../search_highlights.js";

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
  document.body.innerHTML = "";
});

describe("temporary search matches", () => {
  it("matches case and accents without changing saved highlight markup", () => {
    document.body.innerHTML = '<p id="passage">Désir <mark data-highlight-id="31">DESIR</mark> and desire.</p>';
    const root = document.getElementById("passage");
    const before = root.innerHTML;
    const ranges = searchMatchRanges(root, ["desir"]);
    expect(ranges.map(range => range.toString())).toEqual(["Désir", "DESIR", "desir"]);
    expect(root.innerHTML).toBe(before);
  });

  it("skips controls and hidden text and matches short words on boundaries", () => {
    document.body.innerHTML = '<div id="passage">AI railway ai <button>AI</button><span aria-hidden="true">AI</span></div>';
    expect(searchMatchRanges(document.getElementById("passage"), ["ai"]).map(range => range.toString())).toEqual(["AI", "ai"]);
  });

  it("keeps correct offsets for emoji and decomposed accents", () => {
    document.body.innerHTML = '<p id="passage">😀 de\u0301sir</p>';
    const [range] = searchMatchRanges(document.getElementById("passage"), ["desir"]);
    expect(range.toString()).toBe("de\u0301sir");
  });

  it("paints only the selected response and removes marks when cleared or destroyed", () => {
    vi.stubGlobal("CSS", {highlights: new Map()});
    vi.stubGlobal("Highlight", Set);
    vi.stubGlobal("requestAnimationFrame", callback => {callback(); return 1;});
    vi.stubGlobal("cancelAnimationFrame", () => {});
    document.body.innerHTML = `<section id="flow" data-search-node-id="2" data-search-terms='["desire"]'>
      <article id="reading-node-1"><h2 class="reader-heading">Desire</h2></article>
      <article id="reading-node-2"><h2 class="reader-heading">Desire</h2><div phx-hook="Markdown" data-body-only="true"><p>Desire matters.</p></div></article>
    </section>`;
    const hook = {...SearchHighlights, el: document.getElementById("flow")};
    hook.mounted();
    const ranges = [...CSS.highlights.get("reader-search-matches")];
    expect(ranges).toHaveLength(2);
    expect(ranges.every(range => document.getElementById("reading-node-2").contains(range.startContainer))).toBe(true);
    hook.el.dataset.searchNodeId = "";
    hook.updated();
    expect(CSS.highlights.has("reader-search-matches")).toBe(false);
    hook.el.dataset.searchNodeId = "2";
    hook.updated();
    hook.destroyed();
    expect(CSS.highlights.has("reader-search-matches")).toBe(false);
  });
  it("uses the graph content target without marking other panels", () => {
    vi.stubGlobal("CSS", {highlights: new Map()});
    vi.stubGlobal("Highlight", Set);
    document.body.innerHTML = `<div id="graph" data-search-node-id="2" data-search-target-id="node-content-2" data-search-terms='["desire"]'>
      <h2 class="reader-heading">Desire outside the response</h2>
      <div id="node-content-2"><h2 class="reader-heading">Desire</h2></div>
    </div>`;
    SearchHighlights.paint.call({el: document.getElementById("graph")});
    const ranges = [...CSS.highlights.get("reader-search-matches")];
    expect(ranges).toHaveLength(1);
    expect(document.getElementById("node-content-2").contains(ranges[0].startContainer)).toBe(true);
  });

  it("includes the opening paragraph of a multiline prompt in search matches", () => {
    vi.stubGlobal("CSS", {highlights: new Map()});
    vi.stubGlobal("Highlight", Set);
    document.body.innerHTML = `<section id="flow" data-search-node-id="1" data-search-terms='["genius"]'>
      <article id="reading-node-1">
        <h2>Starting question</h2>
        <p data-reader-prompt-opening>More like genius than garbage.</p>
        <div phx-hook="Markdown" data-body-only="true"><p>More like garbage than genius.</p></div>
      </article>
    </section>`;
    SearchHighlights.paint.call({el: document.getElementById("flow")});
    const ranges = [...CSS.highlights.get("reader-search-matches")];
    expect(ranges.map(range => range.toString())).toEqual(["genius", "genius"]);
    expect(document.querySelector("[data-reader-prompt-opening]").contains(ranges[0].startContainer)).toBe(true);
  });

});

describe("search index lifecycle", () => {
  it("reuses text across term changes, ignores other answers, and refreshes changed content", async () => {
    vi.stubGlobal("CSS", {highlights: new Map()});
    vi.stubGlobal("Highlight", Set);
    vi.stubGlobal("requestAnimationFrame", callback => {callback(); return 1;});
    vi.stubGlobal("cancelAnimationFrame", () => {});
    document.body.innerHTML = `<section id="flow" data-search-node-id="1" data-search-terms='["alpha"]'>
      <article id="reading-node-1"><h2 class="reader-heading">Alpha beta</h2></article>
      <article id="reading-node-2"><h2 class="reader-heading">Other answer</h2></article>
    </section>`;
    const hook = {...SearchHighlights, el: document.getElementById("flow")};
    const walker = vi.spyOn(document, "createTreeWalker");
    hook.mounted();
    try {
      expect([...CSS.highlights.get("reader-search-matches")][0].toString()).toBe("Alpha");
      const heading = document.querySelector("#reading-node-1 h2");
      const walks = () => walker.mock.calls.filter(([root]) => root === heading).length;
      const initialWalks = walks();
      hook.el.dataset.searchTerms = '["beta"]';
      hook.updated();
      expect([...CSS.highlights.get("reader-search-matches")][0].toString()).toBe("beta");
      expect(walks()).toBe(initialWalks);
      document.querySelector("#reading-node-2 h2").textContent = "Unrelated update";
      await Promise.resolve();
      expect(walks()).toBe(initialWalks);
      document.querySelector("#reading-node-1 h2").textContent = "A new beta";
      await Promise.resolve();
      expect([...CSS.highlights.get("reader-search-matches")][0].toString()).toBe("beta");
      expect(walks()).toBeGreaterThan(initialWalks);
      document.querySelector("#reading-node-1 h2").firstChild.data = "Beta edited again";
      hook.updated();
      expect([...CSS.highlights.get("reader-search-matches")][0].toString()).toBe("Beta");
    } finally { hook.destroyed(); }
  });
});

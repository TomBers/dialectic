const highlightName = "reader-search-matches";

function fold(text) {
  return text.toLowerCase().normalize("NFD").replace(/\p{Mn}/gu, "");
}

function textIndex(root) {
  const entries = [];
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  let node;
  while ((node = walker.nextNode())) {
    if (node.parentElement.closest('button, script, style, textarea, [aria-hidden="true"], .katex')) continue;
    let normalized = "";
    const offsets = [];
    let offset = 0;
    for (const character of node.data) {
      const folded = fold(character);
      const end = offset + character.length;
      for (let i = 0; i < folded.length; i++) offsets.push({start: offset, end});
      if (!folded && offsets.length) offsets[offsets.length - 1].end = end;
      normalized += folded;
      offset = end;
    }
    entries.push({node, normalized, offsets});
  }
  return entries;
}

export function searchMatchRanges(root, terms, index = textIndex(root)) {
  const ranges = [];
  const words = [...new Set(terms.map(fold).filter(Boolean))];
  for (const {node, normalized, offsets} of index) {
    for (const word of words) {
      let start = normalized.indexOf(word);
      while (start !== -1) {
        const end = start + word.length;
        const insideWord = word.length < 3 &&
          (/[\p{L}\p{N}_]/u.test(normalized[start - 1] || "") || /[\p{L}\p{N}_]/u.test(normalized[end] || ""));
        if (!insideWord) {
          const range = document.createRange();
          range.setStart(node, offsets[start].start);
          range.setEnd(node, offsets[end - 1].end);
          ranges.push(range);
        }
        start = normalized.indexOf(word, end);
      }
    }
  }
  return ranges;
}

const SearchHighlights = {
  mounted() {
    this.schedule = () => {
      cancelAnimationFrame(this.frame);
      this.frame = requestAnimationFrame(() => this.paint());
    };
    this.invalidate = () => {
      this.dirty = true;
      this.schedule();
    };
    this.observer = new MutationObserver(this.invalidate);
    this.onMarkdown = (event) => {
      if (this.target?.contains(event.target)) this.invalidate();
    };
    this.el.addEventListener("markdown:rendered", this.onMarkdown);
    this.schedule();
  },
  updated() {
    this.schedule();
  },
  paint() {
    if (!globalThis.CSS?.highlights || !globalThis.Highlight) return;
    const id = this.el.dataset.searchNodeId;
    const node = id && document.getElementById(this.el.dataset.searchTargetId || `reading-node-${id}`);
    if (!node || !this.el.contains(node)) {
      CSS.highlights.delete(highlightName);
      this.observer?.disconnect();
      this.target = null;
      this.indexes = null;
      return;
    }
    if (node !== this.target) {
      this.observer?.disconnect();
      this.target = node;
      this.dirty = true;
      this.observer?.observe(node, {
        childList: true, subtree: true, characterData: true,
        attributes: true, attributeFilter: ["aria-hidden", "class"],
      });
    }
    if (this.observer?.takeRecords().length) this.dirty = true;
    const source = this.el.dataset.searchTerms || "[]";
    if (!this.dirty && this.lastTerms === source) return;
    if (this.dirty) this.indexes = new Map();
    this.lastTerms = source;
    this.dirty = false;
    const terms = JSON.parse(source);
    CSS.highlights.delete(highlightName);
    const ranges = [];
    for (const root of node.querySelectorAll('.reader-heading, [data-reader-prompt-opening], [phx-hook="Markdown"][data-body-only="true"]')) {
      if (!this.indexes.has(root)) this.indexes.set(root, textIndex(root));
      ranges.push(...searchMatchRanges(root, terms, this.indexes.get(root)));
    }
    const highlight = new Highlight();
    for (const range of ranges) highlight.add(range);
    CSS.highlights.set(highlightName, highlight);
  },
  destroyed() {
    cancelAnimationFrame(this.frame);
    this.observer.disconnect();
    this.el.removeEventListener("markdown:rendered", this.onMarkdown);
    this.indexes = null;
    globalThis.CSS?.highlights?.delete(highlightName);
  },
};

export default SearchHighlights;

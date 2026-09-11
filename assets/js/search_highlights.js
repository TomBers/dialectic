const highlightName = "reader-search-matches";

function fold(text) {
  return text.toLowerCase().normalize("NFD").replace(/\p{Mn}/gu, "");
}

export function searchMatchRanges(root, terms) {
  const ranges = [];
  const words = [...new Set(terms.map(fold).filter(Boolean))];
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
    this.observer = new MutationObserver(this.schedule);
    this.observer.observe(this.el, {childList: true, subtree: true, characterData: true});
    this.el.addEventListener("markdown:rendered", this.schedule);
    this.schedule();
  },
  updated() {
    this.schedule();
  },
  paint() {
    if (!globalThis.CSS?.highlights || !globalThis.Highlight) return;
    CSS.highlights.delete(highlightName);
    const id = this.el.dataset.searchNodeId;
    if (!id) return;
    const node = document.getElementById(this.el.dataset.searchTargetId || `reading-node-${id}`);
    if (!node || !this.el.contains(node)) return;
    const terms = JSON.parse(this.el.dataset.searchTerms || "[]");
    const ranges = [];
    for (const root of node.querySelectorAll('.reader-heading, [phx-hook="Markdown"][data-body-only="true"]')) {
      ranges.push(...searchMatchRanges(root, terms));
    }
    const highlight = new Highlight();
    for (const range of ranges) highlight.add(range);
    CSS.highlights.set(highlightName, highlight);
  },
  destroyed() {
    cancelAnimationFrame(this.frame);
    this.observer.disconnect();
    this.el.removeEventListener("markdown:rendered", this.schedule);
    globalThis.CSS?.highlights?.delete(highlightName);
  },
};

export default SearchHighlights;

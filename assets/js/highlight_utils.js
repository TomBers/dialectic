const HighlightUtils = {
  /**
   * Returns Heroicon class name for link type
   */
  getHeroiconClass(linkType) {
    const icons = {
      explain: "hero-light-bulb",
      question: "hero-question-mark-circle",
      pro: "hero-hand-thumb-up",
      con: "hero-hand-thumb-down",
      related_idea: "hero-arrow-path",
      clarify: "hero-light-bulb",
      assumptions: "hero-cube-transparent",
      counterexample: "hero-x-mark",
      implications: "hero-arrow-trending-up",
      blind_spots: "hero-eye-slash",
      says_who: "hero-user",
      who_disagrees: "hero-users",
      steel_man: "hero-star",
      what_if: "hero-question-mark-circle",
    };
    return icons[linkType] || "hero-link";
  },

  /**
   * Returns Tailwind color class for link type
   */
  getIconColorClass(linkType) {
    const colors = {
      explain: "text-gray-500",
      question: "text-sky-500",
      pro: "text-emerald-500",
      con: "text-red-500",
      related_idea: "text-orange-500",
      clarify: "text-teal-500",
      assumptions: "text-amber-500",
      counterexample: "text-red-500",
      implications: "text-indigo-500",
      blind_spots: "text-purple-500",
      says_who: "text-sky-500",
      who_disagrees: "text-rose-500",
      steel_man: "text-yellow-500",
      what_if: "text-fuchsia-500",
    };
    return colors[linkType] || "text-gray-500";
  },

  /**
   * Returns label for link type
   */
  getLinkLabel(linkType) {
    const labels = {
      explain: "Explanation",
      question: "Question",
      pro: "Pro Argument",
      con: "Con Argument",
      related_idea: "Related Idea",
      clarify: "Clarify Terms",
      assumptions: "Assumptions",
      counterexample: "Counterexample",
      implications: "Implications",
      blind_spots: "Blind Spots",
      says_who: "Source Check",
      who_disagrees: "Who Disagrees",
      steel_man: "Steel Man",
      what_if: "What If",
    };
    return labels[linkType] || "Link";
  },

  /**
   * Creates a clickable icon element for a link using Heroicons CSS classes
   */
  createLinkIcon(link) {
    const button = document.createElement("button");
    button.type = "button";
    button.className =
      "highlight-link-icon hover:scale-125 transition-transform cursor-pointer bg-transparent border-0 p-0";
    button.dataset.nodeId = link.node_id;
    button.dataset.linkType = link.link_type;
    button.title = `Navigate to ${this.getLinkLabel(link.link_type)}: ${link.node_id}`;

    // Add Phoenix LiveView attributes for click handling
    button.setAttribute("phx-click", "navigate_to_node");
    button.setAttribute("phx-value-node_id", link.node_id);

    // Create the Heroicon span using the same pattern as Phoenix CoreComponents
    const iconSpan = document.createElement("span");
    iconSpan.className = `${this.getHeroiconClass(link.link_type)} h-4 w-4 ${this.getIconColorClass(link.link_type)}`;

    button.appendChild(iconSpan);

    return button;
  },

  /**
   * Applies highlights to a container element.
   * @param {HTMLElement} container - The element containing the text to highlight.
   * @param {Array} highlights - Array of highlight objects {id, selection_start, selection_end, links: [...]}
   */
  renderHighlights(container, highlights) {
    if (!container || !highlights) return;

    const existing = new Map();
    for (const span of container.querySelectorAll(".highlight-span")) {
      const id = span.dataset.highlightId;
      if (!existing.has(id)) existing.set(id, []);
      existing.get(id).push(span);
    }
    const next = new Map(highlights.map(h => [String(h.id), h]));
    for (const [id, spans] of existing) {
      const highlight = next.get(id);
      const sameRange = highlight && spans.every(span => {
        try {
          const previous = JSON.parse(span.dataset.highlightSignature);
          return previous?.start === highlight.selection_start &&
            previous?.end === highlight.selection_end && Array.isArray(previous?.links);
        } catch {
          return false;
        }
      });
      if (!sameRange) {
        this.removeHighlight(container, id, spans);
        existing.delete(id);
      } else if (spans[0].dataset.highlightSignature !== this.highlightSignature(highlight)) {
        this.updateHighlightLinks(container, highlight, spans);
      }
    }
    const additions = highlights.filter(h => !existing.has(String(h.id)))
      .sort((a, b) => b.selection_start - a.selection_start);
    if (additions.length === 0) return;
    let index = this.textIndex(container);
    for (let i = 0; i < additions.length; i++) {
      const highlight = additions[i];
      if (i > 0 && highlight.selection_end > additions[i - 1].selection_start) index = this.textIndex(container);
      this.applySingleHighlight(container, highlight, index);
    }
  },

  highlightSignature(highlight) {
    const links = (highlight.links || []).map((link) => [
      link.node_id,
      link.link_type,
    ]);

    return JSON.stringify({
      start: highlight.selection_start,
      end: highlight.selection_end,
      links,
    });
  },

  textIndex(container) {
    const index = [];
    const walker = document.createTreeWalker(container, NodeFilter.SHOW_TEXT);
    let offset = 0;
    let node;
    while ((node = walker.nextNode())) {
      if (node.parentElement.closest(".highlight-links-container")) continue;
      const end = offset + node.length;
      index.push({ node, start: offset, end });
      offset = end;
    }
    return index;
  },

  applySingleHighlight(container, highlight, index = this.textIndex(container)) {
    const start = highlight.selection_start;
    const end = highlight.selection_end;
    let low = 0;
    let high = index.length;
    while (low < high) {
      const middle = (low + high) >>> 1;
      if (index[middle].end <= start) low = middle + 1;
      else high = middle;
    }
    const segments = [];
    for (let i = low; i < index.length && index[i].start < end; i++) {
      const entry = index[i];
      const from = Math.max(0, start - entry.start);
      const to = Math.min(entry.node.length, end - entry.start);
      if (from < to) segments.push({ node: entry.node, from, to });
    }
    const spans = [];
    for (const { node, from, to } of segments.reverse()) {
      const range = document.createRange();
      range.setStart(node, from);
      range.setEnd(node, to);
      const span = document.createElement("mark");
      span.className = "highlight-span";
      span.dataset.highlightId = highlight.id;
      range.surroundContents(span);
      spans.unshift(span);
    }
    this.updateHighlightLinks(container, highlight, spans);
  },

  updateHighlightLinks(container, highlight, spans) {
    const links = highlight.links || [];
    const signature = this.highlightSignature(highlight);
    for (const span of spans) {
      span.dataset.highlightSignature = signature;
      span.classList.toggle("has-linked-node", links.length > 0);
      if (links.length > 0) {
        span.dataset.linkedNodeId = links[0].node_id;
        span.dataset.linkType = links[0].link_type;
        span.title = links.length === 1
          ? `Linked to ${this.getLinkLabel(links[0].link_type)}`
          : `${links.length} linked nodes`;
      } else {
        delete span.dataset.linkedNodeId;
        delete span.dataset.linkType;
        span.removeAttribute("title");
      }
    }
    for (const icons of container.querySelectorAll(".highlight-links-container")) {
      if (icons.dataset.highlightId === String(highlight.id)) icons.remove();
    }
    if (links.length === 0 || spans.length === 0) return;
    const icons = document.createElement("span");
    icons.className = "highlight-links-container";
    icons.dataset.highlightId = highlight.id;
    icons.style.cssText = "display: inline-flex; align-items: center; gap: 2px; margin-left: 2px;";
    for (const link of links) icons.appendChild(this.createLinkIcon(link));
    spans[spans.length - 1].after(icons);
  },

  removeHighlight(container, id, spans) {
    for (const icons of container.querySelectorAll(".highlight-links-container")) {
      if (icons.dataset.highlightId === id) icons.remove();
    }
    const parents = new Set();
    for (const span of spans) {
      parents.add(span.parentNode);
      span.replaceWith(...span.childNodes);
    }
    for (const parent of parents) parent.normalize();
  },

  removeHighlights(container) {
    this.renderHighlights(container, []);
  },
};

export default HighlightUtils;

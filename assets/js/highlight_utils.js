const HighlightUtils = {
  /**
   * Returns Heroicon class name for link type
   */
  getHeroiconClass(linkType) {
    const icons = {
      explain: "hero-information-circle",
      question: "hero-question-mark-circle",
      pro: "hero-arrow-up-circle",
      con: "hero-arrow-down-circle",
      related_idea: "hero-light-bulb",
      deep_dive: "hero-magnifying-glass-circle",
    };
    return icons[linkType] || icons.explain;
  },

  /**
   * Returns Tailwind color class for link type
   */
  getIconColorClass(linkType) {
    const colors = {
      explain: "text-blue-500",
      question: "text-sky-500",
      pro: "text-emerald-500",
      con: "text-red-500",
      related_idea: "text-orange-500",
      deep_dive: "text-cyan-500",
    };
    return colors[linkType] || colors.explain;
  },

  /**
   * Returns label for link type
   */
  getLinkLabel(linkType) {
    const labels = {
      explain: "Explanation",
      question: "Question",
      pro: "Pro",
      con: "Con",
      related_idea: "Related Idea",
      deep_dive: "Deep Dive",
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
    button.setAttribute("phx-click", "node_clicked");
    button.setAttribute("phx-value-id", link.node_id);

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

    // Get existing highlight IDs
    const existingSpans = container.querySelectorAll(".highlight-span");
    const existingIds = new Set(
      Array.from(existingSpans).map((span) => span.dataset.highlightId),
    );

    // Get new highlight IDs
    const newIds = new Set(highlights.map((h) => h.id.toString()));

    // Only proceed if there are actual changes
    const hasChanges =
      existingIds.size !== newIds.size ||
      Array.from(existingIds).some((id) => !newIds.has(id)) ||
      Array.from(newIds).some((id) => !existingIds.has(id));

    if (!hasChanges) {
      // No changes needed - highlights are already up to date
      return;
    }

    // 1. Remove existing highlights
    this.removeHighlights(container);

    // 2. Sort highlights by start position
    const sortedHighlights = [...highlights].sort(
      (a, b) => a.selection_start - b.selection_start,
    );

    // 3. Apply highlights
    sortedHighlights.forEach((highlight) => {
      this.applySingleHighlight(container, highlight);
    });
  },

  /**
   * Applies a single highlight by wrapping text nodes in spans.
   * Handles ranges that cross element boundaries by creating multiple spans.
   */
  applySingleHighlight(container, highlight) {
    const start = highlight.selection_start;
    const end = highlight.selection_end;

    let currentOffset = 0;
    const walker = document.createTreeWalker(
      container,
      NodeFilter.SHOW_TEXT,
      null,
      false,
    );

    let node;
    const nodesToWrap = [];

    // Traverse all text nodes to find intersections with the highlight range
    while ((node = walker.nextNode())) {
      const nodeContent = node.textContent;
      const nodeLength = nodeContent.length;
      const nodeStart = currentOffset;
      const nodeEnd = currentOffset + nodeLength;

      // Check intersection
      if (nodeEnd > start && nodeStart < end) {
        // Calculate relative start/end for this text node
        const wrapStart = Math.max(0, start - nodeStart);
        const wrapEnd = Math.min(nodeLength, end - nodeStart);

        nodesToWrap.push({ node, wrapStart, wrapEnd });
      }

      currentOffset += nodeLength;
      // Optimization: stop if we passed the end of the highlight
      if (currentOffset >= end) break;
    }

    // Wrap the identified segments
    // We reverse to avoid invalidating offsets of earlier nodes if DOM changes (though splitting shouldn't affect previous nodes in this logic)
    // Actually, splitting a node affects its own future processing, but we are done traversing.
    // Track the first item in reversed array (which is the last span chronologically)
    let lastSpanChronologically = null;
    const reversedNodes = nodesToWrap.reverse();
    reversedNodes.forEach(({ node, wrapStart, wrapEnd }, index) => {
      if (wrapStart === wrapEnd) return; // Empty range

      const range = document.createRange();
      range.setStart(node, wrapStart);
      range.setEnd(node, wrapEnd);

      const span = document.createElement("span");
      span.className = "highlight-span";
      span.dataset.highlightId = highlight.id;

      // Add styling for highlights with links
      if (highlight.links && highlight.links.length > 0) {
        span.classList.add("has-linked-nodes");
        span.style.backgroundColor = "#fef3c7";
        span.style.borderBottom = "2px solid #f59e0b";
        span.style.padding = "0 2px";
      }

      try {
        range.surroundContents(span);
        // The first span we create in the reversed loop is the last one chronologically
        if (index === 0) {
          lastSpanChronologically = span;
        }
      } catch (e) {
        console.warn("HighlightUtils: Failed to wrap node", e);
      }
    });

    // Add link icons only once, after the last span of the highlight
    if (
      lastSpanChronologically &&
      highlight.links &&
      highlight.links.length > 0
    ) {
      const iconContainer = document.createElement("span");
      iconContainer.className = "highlight-links-container";
      iconContainer.style.cssText =
        "display: inline-flex; align-items: center; gap: 2px; margin-left: 2px;";

      highlight.links.forEach((link) => {
        const icon = this.createLinkIcon(link);
        iconContainer.appendChild(icon);
      });

      // Insert icons right after the last highlight span
      if (lastSpanChronologically.nextSibling) {
        lastSpanChronologically.parentNode.insertBefore(
          iconContainer,
          lastSpanChronologically.nextSibling,
        );
      } else {
        lastSpanChronologically.parentNode.appendChild(iconContainer);
      }
    }
  },

  /**
   * Removes all highlight spans from the container, merging text nodes back together.
   */
  removeHighlights(container) {
    // Remove link icon containers
    const iconContainers = container.querySelectorAll(
      ".highlight-links-container",
    );
    iconContainers.forEach((container) => {
      container.remove();
    });

    // Remove highlight spans
    const spans = container.querySelectorAll(".highlight-span");
    spans.forEach((span) => {
      const parent = span.parentNode;
      while (span.firstChild) {
        parent.insertBefore(span.firstChild, span);
      }
      parent.removeChild(span);
    });
    // Merge adjacent text nodes to restore clean DOM
    container.normalize();
  },
};

export default HighlightUtils;

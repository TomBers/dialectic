const HighlightUtils = {
  /**
   * Returns SVG path data for link type icons
   */
  getIconPath(linkType) {
    const icons = {
      explain:
        "M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9 5.25h.008v.008H12v-.008z",
      question:
        "M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9 5.25h.008v.008H12v-.008z",
      pro: "M2.25 18 9 11.25l4.306 4.306a11.95 11.95 0 0 1 5.814-5.518l2.74-1.22m0 0-5.94-2.281m5.94 2.28-2.28 5.941",
      con: "M2.25 6 9 12.75l4.286-4.286a11.948 11.948 0 0 1 4.306 6.43l.776 2.898m0 0 3.182-5.511m-3.182 5.51-5.511-3.181",
      related_idea:
        "M12 18v-5.25m0 0a6.01 6.01 0 0 0 1.5-.189m-1.5.189a6.01 6.01 0 0 1-1.5-.189m3.75 7.478a12.06 12.06 0 0 1-4.5 0m3.75 2.383a14.406 14.406 0 0 1-3 0M14.25 18v-.192c0-.983.658-1.823 1.508-2.316a7.5 7.5 0 1 0-7.517 0c.85.493 1.509 1.333 1.509 2.316V18",
      deep_dive:
        "M21 21l-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607z",
    };
    return icons[linkType] || icons.explain;
  },

  /**
   * Returns color class for link type
   */
  getIconColor(linkType) {
    const colors = {
      explain: "#6b7280",
      question: "#0ea5e9",
      pro: "#10b981",
      con: "#ef4444",
      related_idea: "#f97316",
      deep_dive: "#06b6d4",
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
   * Creates a clickable icon element for a link
   */
  createLinkIcon(link) {
    const icon = document.createElement("span");
    icon.className = "highlight-link-icon";
    icon.dataset.nodeId = link.node_id;
    icon.dataset.linkType = link.link_type;
    icon.title = `Navigate to ${this.getLinkLabel(link.link_type)}: ${link.node_id}`;
    icon.style.cssText =
      "cursor: pointer; display: inline-flex; align-items: center; margin-left: 2px; vertical-align: middle; transition: transform 0.2s;";

    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("class", "h-3 w-3");
    svg.setAttribute("viewBox", "0 0 24 24");
    svg.setAttribute("fill", "none");
    svg.setAttribute("stroke", this.getIconColor(link.link_type));
    svg.setAttribute("stroke-width", "2.5");
    svg.setAttribute("stroke-linecap", "round");
    svg.setAttribute("stroke-linejoin", "round");

    const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
    path.setAttribute("d", this.getIconPath(link.link_type));

    svg.appendChild(path);
    icon.appendChild(svg);

    // Hover effect
    icon.addEventListener("mouseenter", () => {
      icon.style.transform = "scale(1.25)";
    });
    icon.addEventListener("mouseleave", () => {
      icon.style.transform = "scale(1)";
    });

    // Click handler - use Phoenix LiveView event
    icon.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();

      // Find the closest element with phx-click capability or dispatch custom event
      const event = new CustomEvent("highlight-link-clicked", {
        detail: { nodeId: link.node_id },
        bubbles: true,
      });
      icon.dispatchEvent(event);
    });

    return icon;
  },

  /**
   * Applies highlights to a container element.
   * @param {HTMLElement} container - The element containing the text to highlight.
   * @param {Array} highlights - Array of highlight objects {id, selection_start, selection_end, links: [...]}
   */
  renderHighlights(container, highlights) {
    console.log("[HighlightUtils] renderHighlights called with:", highlights);
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
    console.log(
      "[HighlightUtils] applySingleHighlight:",
      highlight.id,
      "links:",
      highlight.links,
    );
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
    nodesToWrap.reverse().forEach(({ node, wrapStart, wrapEnd }) => {
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

        // Add link icons after the highlight span if there are links
        console.log(
          "[HighlightUtils] Checking links for highlight",
          highlight.id,
          ":",
          highlight.links,
        );
        if (highlight.links && highlight.links.length > 0) {
          console.log(
            "[HighlightUtils] Adding icons for",
            highlight.links.length,
            "links",
          );
          const iconContainer = document.createElement("span");
          iconContainer.className = "highlight-links-container";
          iconContainer.style.cssText =
            "display: inline-flex; align-items: center; gap: 2px; margin-left: 2px;";

          highlight.links.forEach((link) => {
            const icon = this.createLinkIcon(link);
            iconContainer.appendChild(icon);
          });

          // Insert icons right after the highlight span
          if (span.nextSibling) {
            span.parentNode.insertBefore(iconContainer, span.nextSibling);
          } else {
            span.parentNode.appendChild(iconContainer);
          }
          console.log("[HighlightUtils] Icons inserted after highlight span");
        }
      } catch (e) {
        console.warn("HighlightUtils: Failed to wrap node", e);
      }
    });
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

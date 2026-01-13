const HighlightUtils = {
  /**
   * Applies highlights to a container element.
   * @param {HTMLElement} container - The element containing the text to highlight.
   * @param {Array} highlights - Array of highlight objects {id, selection_start, selection_end, ...}
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
    nodesToWrap.reverse().forEach(({ node, wrapStart, wrapEnd }) => {
      if (wrapStart === wrapEnd) return; // Empty range

      const range = document.createRange();
      range.setStart(node, wrapStart);
      range.setEnd(node, wrapEnd);

      const span = document.createElement("span");
      span.className = "highlight-span";
      span.dataset.highlightId = highlight.id;

      try {
        range.surroundContents(span);
      } catch (e) {
        console.warn("HighlightUtils: Failed to wrap node", e);
      }
    });
  },

  /**
   * Removes all highlight spans from the container, merging text nodes back together.
   */
  removeHighlights(container) {
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

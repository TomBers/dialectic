/**
 * ConversationScrollSync Hook
 *
 * Purpose:
 * - Keeps the graph selection in sync with the visible message in conversation mode.
 * - When the user scrolls the conversation, the top-most visible message becomes the selected node.
 * - If the user is near the bottom and new content arrives, auto-scroll to bottom (like ChatScroll).
 *
 * Assumptions:
 * - This hook is mounted on the conversation scroll container (conversation mode only).
 * - The scroll container has:
 *    - id="chat-messages"
 *    - child message wrappers with class "message-wrapper" and ids like "conv-com-<node_id>"
 * - The LiveView handles "node_clicked" events and will select the corresponding node in the graph.
 *
 * Usage:
 *  - Import and register this hook in your LiveSocket hooks, then attach it to the conversation container.
 *    hooks.ConversationScrollSync = conversationScrollSync;
 *    <div id="chat-messages" phx-hook="ConversationScrollSync"> ... </div>
 */

const SCROLL_DEBOUNCE_MS = 150;
const NEAR_BOTTOM_THRESHOLD_PX = 80;

const conversationScrollSync = {
  mounted() {
    // Cache references
    this.container = this.el;
    this.lastSelectedNodeId = null;
    this.scrollRaf = null;
    this.scrollTimer = null;
    this.wasNearBottom = true; // default to bottom on first mount

    // Sanity checks to avoid doing work in unexpected markup
    if (!this.container || this.container.id !== "chat-messages") {
      return;
    }

    // Detect if we should auto-scroll on updates (user near the bottom)
    this.wasNearBottom = this.isNearBottom();

    // Set up scroll listener with rAF + debounce to avoid spamming events
    this.onScroll = () => {
      // Debounce scroll work to avoid heavy computations
      if (this.scrollTimer) {
        clearTimeout(this.scrollTimer);
      }
      this.scrollTimer = setTimeout(() => {
        // Use rAF to ensure layout measurements are fresh post-scroll
        if (this.scrollRaf) cancelAnimationFrame(this.scrollRaf);
        this.scrollRaf = requestAnimationFrame(() => this.handleScroll());
      }, SCROLL_DEBOUNCE_MS);
    };

    this.container.addEventListener("scroll", this.onScroll, { passive: true });
  },

  updated() {
    // If user was near the bottom before the DOM update, snap to bottom (new content)
    if (this.wasNearBottom) {
      this.scrollToBottom();
    }

    // Recalculate near-bottom after update for future patches
    this.wasNearBottom = this.isNearBottom();
  },

  destroyed() {
    if (this.container && this.onScroll) {
      this.container.removeEventListener("scroll", this.onScroll);
    }
    if (this.scrollRaf) {
      cancelAnimationFrame(this.scrollRaf);
    }
    if (this.scrollTimer) {
      clearTimeout(this.scrollTimer);
    }
  },

  // --- Core Logic ---

  handleScroll() {
    // Update "near bottom" tracking during manual scrolling
    this.wasNearBottom = this.isNearBottom();

    const candidate = this.findTopVisibleMessage();
    if (!candidate) return;

    const nodeId = this.extractNodeId(candidate.id);
    if (!nodeId) return;

    if (nodeId !== this.lastSelectedNodeId) {
      this.lastSelectedNodeId = nodeId;

      // Push selection change to LiveView to update the graph selection
      // GraphLive has a "node_clicked" event handler that accepts %{"id" => id}
      this.pushEvent("node_clicked", { id: nodeId });
    }
  },

  findTopVisibleMessage() {
    const containerRect = this.container.getBoundingClientRect();
    const messages = this.container.querySelectorAll(".message-wrapper[id^='conv-com-']");
    if (!messages || messages.length === 0) return null;

    let bestEl = null;
    let bestScore = Infinity;

    messages.forEach((el) => {
      const rect = el.getBoundingClientRect();

      // Distance of the element's top to the container's top (positive when below the top edge)
      const distanceTop = rect.top - containerRect.top;

      // We want the element closest to the top edge, preferring those within or above the top edge slightly,
      // but still visible (bottom below container top).
      const isVisible =
        rect.bottom > containerRect.top && rect.top < containerRect.bottom;

      if (!isVisible) return;

      // Score approach:
      // - Prefer elements whose top is >= 0 (already at/under the top edge), with smaller is better
      // - If none, choose the one with the top just slightly negative (closest to 0)
      const score = distanceTop >= 0 ? distanceTop : Math.abs(distanceTop) + 10000;

      if (score < bestScore) {
        bestScore = score;
        bestEl = el;
      }
    });

    return bestEl;
  },

  extractNodeId(elId) {
    // Expected pattern: "conv-com-<node_id>"
    if (!elId || typeof elId !== "string") return null;
    const prefix = "conv-com-";
    if (!elId.startsWith(prefix)) return null;
    return elId.substring(prefix.length);
  },

  isNearBottom() {
    const el = this.container;
    // How far from the very bottom are we?
    const distanceFromBottom = el.scrollHeight - (el.scrollTop + el.clientHeight);
    return distanceFromBottom <= NEAR_BOTTOM_THRESHOLD_PX;
  },

  scrollToBottom() {
    // Smooth-ish bottom scroll; requestAnimationFrame to avoid fighting layout changes
    requestAnimationFrame(() => {
      this.container.scrollTop = this.container.scrollHeight;
    });
  },
};

export default conversationScrollSync;

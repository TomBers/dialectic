import HighlightUtils from "./highlight_utils.js";

const textSelectionHook = {
  mounted() {
    this.handleSelection = this.handleSelection.bind(this);
    this.hideSelectionActions = this.hideSelectionActions.bind(this);
    this.refreshHighlights = this.refreshHighlights.bind(this);

    // Get node ID from data attribute
    this.nodeId = this.el.dataset.nodeId;
    this.mudgId = this.el.dataset.mudgId;

    // Store element ID to prevent duplicate events
    this.elId = this.el.id;

    // Add event listeners for this specific container
    this.el.addEventListener("mouseup", this.handleSelection);
    this.el.addEventListener("touchend", this.handleSelection);

    // Handle clicks outside the selection
    document.addEventListener("mousedown", (e) => {
      if (!this.el.contains(e.target)) {
        this.hideSelectionActions();
      }
    });

    // Handle selection clearing
    document.addEventListener("selectionchange", () => {
      const selection = window.getSelection();
      if (selection.isCollapsed) {
        this.hideSelectionActions();
      }
    });

    // Initial highlight load
    this.refreshHighlights();

    // Listen for events
    window.addEventListener("highlight:created", this.refreshHighlights);
    this.el.addEventListener("markdown:rendered", this.refreshHighlights);

    this.handleEvent("scroll_to_highlight", this.scrollToHighlight.bind(this));
    this.handleEvent("refresh_highlights", this.refreshHighlights);
  },

  destroyed() {
    this.el.removeEventListener("mouseup", this.handleSelection);
    this.el.removeEventListener("touchend", this.handleSelection);
    window.removeEventListener("highlight:created", this.refreshHighlights);
    this.el.removeEventListener("markdown:rendered", this.refreshHighlights);
  },

  scrollToHighlight({ id }) {
    if (!id) return;

    // Use a slight delay or retry mechanism because the node might be expanding
    // or markdown rendering might be finishing
    const findAndScroll = (attempts = 0) => {
      const span = this.el.querySelector(
        `.highlight-span[data-highlight-id="${id}"]`,
      );
      if (span) {
        span.scrollIntoView({ behavior: "smooth", block: "center" });
        // Pulse effect
        const originalTransition = span.style.transition;
        const originalColor = span.style.backgroundColor;

        span.style.transition = "background-color 0.5s";
        span.style.backgroundColor = "rgba(255, 165, 0, 0.6)"; // Orange pulse

        setTimeout(() => {
          span.style.backgroundColor = originalColor;
          setTimeout(() => {
            span.style.transition = originalTransition;
          }, 500);
        }, 1500);
      } else if (attempts < 10) {
        setTimeout(() => {
          findAndScroll(attempts + 1);
        }, 100);
      }
    };

    findAndScroll();
  },

  refreshHighlights(event) {
    if (event && event.type === "highlight:created") {
      const h = event.detail?.data;
      if (h && (h.mudg_id !== this.mudgId || h.node_id !== this.nodeId)) return;
    }

    // Handle server push event payload
    if (event && event.data && !event.type) {
      const h = event.data;
      if (h && (h.mudg_id !== this.mudgId || h.node_id !== this.nodeId)) return;
    }

    if (!this.mudgId || !this.nodeId) return;

    fetch(`/api/highlights?mudg_id=${this.mudgId}&node_id=${this.nodeId}`, {
      credentials: "include",
    })
      .then((res) => {
        if (!res.ok) throw new Error("Failed to fetch highlights");
        return res.json();
      })
      .then((json) => {
        const highlights = json.data;

        // Find container to render into
        const mdContainer = this.el.querySelector(
          '[phx-hook="Markdown"][data-body-only="true"]',
        );

        if (mdContainer) {
          HighlightUtils.renderHighlights(mdContainer, highlights);
        }
      })
      .catch((err) => console.error("Error loading highlights:", err));
  },

  handleSelection(event) {
    // Add small delay to ensure selection is properly registered
    setTimeout(() => {
      const selection = window.getSelection();
      const selectionActionsEl = this.el.querySelector(".selection-actions");

      if (!selectionActionsEl) return;

      // Check if selection is empty or not within this component
      if (selection.isCollapsed || !this.isSelectionInComponent(selection)) {
        this.hideSelectionActions();
        return;
      }

      const selectedText = selection.toString().trim();
      if (selectedText.length === 0) {
        this.hideSelectionActions();
        return;
      }

      // If we're not the closest container to the selection, don't show our button
      if (!this.isClosestSelectionContainer()) {
        this.hideSelectionActions();
        return;
      }

      // Get the range and its bounding rectangle
      const range = selection.getRangeAt(0);
      const rect = range.getBoundingClientRect();

      // Get the container's bounding rectangle
      const containerRect = this.el.getBoundingClientRect();

      // Make the button visible so we can measure its width
      selectionActionsEl.classList.remove("hidden");

      // Get button dimensions after making it visible
      const buttonWidth = selectionActionsEl.offsetWidth;
      const buttonHeight = selectionActionsEl.offsetHeight;

      // Calculate position relative to the container
      // Position below the selection with some padding
      const top = rect.bottom - containerRect.top + 8;

      // Center the button on the selection, but keep it within bounds
      let leftPos =
        rect.left + rect.width / 2 - buttonWidth / 2 - containerRect.left;

      // Ensure button stays within container bounds with padding
      const padding = 8;
      leftPos = Math.max(padding, leftPos);
      leftPos = Math.min(this.el.clientWidth - buttonWidth - padding, leftPos);

      // Apply the calculated positions
      selectionActionsEl.style.top = `${top}px`;
      selectionActionsEl.style.left = `${leftPos}px`;

      // Set up "Ask" button
      const askButton = selectionActionsEl.querySelector(".ask-btn");
      if (askButton) {
        askButton.onclick = () => {
          this.pushEvent("reply-and-answer", {
            vertex: { content: `Please explain: ${selectedText}` },
            prefix: "explain",
          });

          // Hide the action button after clicking
          this.hideSelectionActions();
        };
      }

      // Set up "Add Note" button
      const addNoteButton = selectionActionsEl.querySelector(".add-note-btn");
      if (addNoteButton) {
        addNoteButton.onclick = () => {
          this.createHighlight(selectedText);
          this.hideSelectionActions();
        };
      }
    }, 10); // 10ms delay
  },

  isSelectionInComponent(selection) {
    if (selection.rangeCount === 0) return false;

    const range = selection.getRangeAt(0);
    const selectionContainer = range.commonAncestorContainer;

    // Check if the selection is within this component
    return this.el.contains(selectionContainer);
  },

  isClosestSelectionContainer() {
    const selection = window.getSelection();
    if (selection.rangeCount === 0) return false;

    const range = selection.getRangeAt(0);
    let container = range.commonAncestorContainer;

    // If the container is a text node, get its parent
    if (container.nodeType === 3) {
      container = container.parentNode;
    }

    // Find all potential selection containers that contain this selection
    const allContainers = document.querySelectorAll(
      '[phx-hook="TextSelectionHook"]',
    );
    let closestContainer = null;
    let minDepth = Infinity;

    // For each potential container, check if it contains the selection
    // and calculate its depth in the DOM
    allContainers.forEach((el) => {
      if (el.contains(container)) {
        // Calculate DOM depth (fewer is closer)
        let depth = 0;
        let parent = container;
        while (parent && parent !== el) {
          depth++;
          parent = parent.parentNode;
        }

        if (depth < minDepth) {
          minDepth = depth;
          closestContainer = el;
        }
      }
    });

    // Return true if this hook's element is the closest container
    return closestContainer === this.el;
  },

  hideSelectionActions() {
    const selectionActionsEl = this.el.querySelector(".selection-actions");
    if (selectionActionsEl) {
      selectionActionsEl.classList.add("hidden");
    }
  },

  createHighlight(text) {
    if (!this.mudgId || !this.nodeId) return;

    // Find the markdown container to calculate offsets relative to it
    const mdContainer = this.el.querySelector(
      '[phx-hook="Markdown"][data-body-only="true"]',
    );
    if (!mdContainer) return;

    const offsets = this.getSelectionOffsets(mdContainer);

    const csrfToken = document
      .querySelector("meta[name='csrf-token']")
      ?.getAttribute("content");

    if (!csrfToken) {
      console.error("CSRF token not found");
      return;
    }

    fetch("/api/highlights", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
      },
      body: JSON.stringify({
        mudg_id: this.mudgId,
        node_id: this.nodeId,
        text_source_type: "node",
        selection_start: offsets.start,
        selection_end: offsets.end,
        selected_text_snapshot: text,
      }),
    })
      .then((response) => {
        if (!response.ok) throw new Error("Failed to create highlight");
        return response.json();
      })
      .then((data) => {
        console.log("Highlight created:", data);
        window.dispatchEvent(
          new CustomEvent("highlight:created", { detail: data }),
        );
      })
      .catch((error) => {
        console.error("Error creating highlight:", error);
      });
  },

  getSelectionOffsets(container) {
    const selection = window.getSelection();
    if (selection.rangeCount === 0) return { start: 0, end: 0 };

    const range = selection.getRangeAt(0);

    // Ensure the selection is actually inside the container
    if (!container.contains(range.commonAncestorContainer)) {
      return { start: 0, end: 0 };
    }

    const preSelectionRange = range.cloneRange();
    preSelectionRange.selectNodeContents(container);
    preSelectionRange.setEnd(range.startContainer, range.startOffset);
    const start = preSelectionRange.toString().length;

    return {
      start: start,
      end: start + range.toString().length,
    };
  },
};

export default textSelectionHook;

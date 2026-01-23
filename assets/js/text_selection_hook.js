import HighlightUtils from "./highlight_utils.js";

const textSelectionHook = {
  mounted() {
    this.handleSelection = this.handleSelection.bind(this);

    this.fetchHighlights = this.fetchHighlights.bind(this);
    const originalFetch = this.fetchHighlights;
    this._fetchTimeout = null;
    this.fetchHighlights = (...args) => {
      clearTimeout(this._fetchTimeout);
      this._fetchTimeout = setTimeout(() => {
        originalFetch(...args);
      }, 300);
    };

    this.refreshHighlights = this.refreshHighlights.bind(this);

    // Reset scroll position for the drawer container to ensure we start at the top
    // We target both parent containers and the internal content container
    const containers = [
      this.el.closest(".overflow-y-auto"),
      this.el.closest(".overflow-auto"),
      this.el.querySelector(".overflow-y-auto"),
      this.el.querySelector(".overflow-auto"),
    ].filter((c) => c);

    // Deduplicate
    const uniqueContainers = [...new Set(containers)];

    uniqueContainers.forEach((container) => {
      container.style.scrollBehavior = "auto";
      container.scrollTop = 0;
      container.style.removeProperty("scroll-behavior");
    });

    // Get node ID from data attribute
    this.nodeId = this.el.dataset.nodeId;
    this.mudgId = this.el.dataset.mudgId;

    // Store element ID to prevent duplicate events
    this.elId = this.el.id;

    // Add event listeners for this specific container
    this.el.addEventListener("mouseup", this.handleSelection);
    this.el.addEventListener("touchend", this.handleSelection);

    // LiveComponent handles all panel interactions - no manual event listeners needed

    // Initial highlight load
    this.refreshHighlights();

    // Listen for events
    window.addEventListener("highlight:created", this.refreshHighlights);
    this.el.addEventListener("markdown:rendered", this.refreshHighlights);

    this.handleEvent("scroll_to_highlight", this.scrollToHighlight.bind(this));
    this.handleEvent("refresh_highlights", this.refreshHighlights);
    this.handleEvent("create_highlight", this.handleCreateHighlight.bind(this));
  },

  handleCreateHighlight({ text, offsets }) {
    this.createHighlight(text, offsets);
  },

  destroyed() {
    clearTimeout(this._fetchTimeout);
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

    this.fetchHighlights();
  },

  fetchHighlights() {
    if (this.el.dataset.streaming === "true") return;
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
    if (this.el.dataset.streaming === "true") {
      return;
    }

    // Add small delay to ensure selection is properly registered
    setTimeout(() => {
      // IMPORTANT: Only handle events that originated within THIS hook's container
      // This prevents multiple hook instances from interfering with each other
      if (!this.el.contains(event.target)) {
        return; // Event didn't happen in this hook's container, ignore it
      }

      const selection = window.getSelection();

      // Check if selection is empty or not within this component
      if (selection.isCollapsed || !this.isSelectionInComponent(selection)) {
        return;
      }

      const selectedText = selection.toString().trim();
      if (selectedText.length === 0) {
        return;
      }

      // If we're not the closest container to the selection, don't show our button
      if (!this.isClosestSelectionContainer()) {
        return;
      }

      // Capture offsets for highlight creation
      const mdContainer = this.el.querySelector(
        '[phx-hook="Markdown"][data-body-only="true"]',
      );
      const capturedOffsets = mdContainer
        ? this.getSelectionOffsets(mdContainer)
        : null;

      // Dispatch custom event to show modal (client-side only, no server round trip)
      window.dispatchEvent(
        new CustomEvent("selection:show", {
          detail: {
            selectedText: selectedText,
            nodeId: this.nodeId,
            offsets: capturedOffsets,
          },
        }),
      );
    }, 10);
  },

  // Store offsets for highlight creation
  storeOffsetsForHighlight(offsets) {
    this._highlightOffsets = offsets;
  },

  // Get stored offsets for highlight creation
  getStoredOffsets() {
    return this._highlightOffsets;
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

  createHighlight(text, capturedOffsets = null) {
    if (!this.mudgId || !this.nodeId) {
      console.warn("Cannot create highlight: missing mudgId or nodeId");
      return;
    }

    // Use captured offsets if provided, otherwise try to get them from current selection
    let offsets = capturedOffsets;

    if (!offsets) {
      // Find the markdown container to calculate offsets relative to it
      const mdContainer = this.el.querySelector(
        '[phx-hook="Markdown"][data-body-only="true"]',
      );
      if (!mdContainer) {
        console.error(
          "Cannot create highlight: markdown container not found. Content may not be rendered yet.",
        );
        return;
      }

      offsets = this.getSelectionOffsets(mdContainer);
    }

    // Validate offsets
    if (!offsets || offsets.start >= offsets.end) {
      console.error("Cannot create highlight: invalid offsets", offsets);
      return;
    }

    const csrfToken = document
      .querySelector("meta[name='csrf-token']")
      ?.getAttribute("content");

    if (!csrfToken) {
      console.error("CSRF token not found");
      return;
    }

    const highlightData = {
      mudg_id: this.mudgId,
      node_id: this.nodeId,
      text_source_type: "node",
      selection_start: offsets.start,
      selection_end: offsets.end,
      selected_text_snapshot: text,
    };

    console.log("Creating highlight with data:", highlightData);

    fetch("/api/highlights", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
      },
      body: JSON.stringify(highlightData),
    })
      .then((response) => {
        if (response.status === 401) {
          this.pushEvent("show_login_required", {});
          return null;
        }

        if (response.status === 422) {
          // Duplicate highlight - find and focus existing one
          return response.json().then((errorData) => {
            console.log("422 Error response:", errorData);

            // Check if it's a duplicate constraint error
            // Phoenix returns errors as an object with field keys mapping to arrays of messages
            const isDuplicateError =
              errorData.errors &&
              Object.values(errorData.errors).some(
                (errorArray) =>
                  Array.isArray(errorArray) &&
                  errorArray.some((msg) =>
                    msg.includes("highlight already exists"),
                  ),
              );

            console.log("Is duplicate error:", isDuplicateError);

            if (isDuplicateError) {
              // Try to find the overlapping highlight
              return fetch(
                `/api/highlights?mudg_id=${this.mudgId}&node_id=${this.nodeId}`,
                { credentials: "include" },
              )
                .then((res) => res.json())
                .then((json) => {
                  // Find any highlight that overlaps with our selection
                  // Two ranges overlap if: start1 < end2 AND start2 < end1
                  const overlappingHighlight = json.data.find(
                    (h) =>
                      h.selection_start < offsets.end &&
                      h.selection_end > offsets.start,
                  );
                  if (overlappingHighlight) {
                    // Scroll to and pulse the overlapping highlight
                    this.scrollToHighlight({ id: overlappingHighlight.id });
                  }
                  return null;
                });
            }

            // Log non-duplicate validation errors
            console.error("Highlight creation validation error:", errorData);
            throw new Error(
              "Failed to create highlight: " + JSON.stringify(errorData.errors),
            );
          });
        }

        if (!response.ok) throw new Error("Failed to create highlight");
        return response.json();
      })
      .then((data) => {
        if (!data) return;
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

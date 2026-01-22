import HighlightUtils from "./highlight_utils.js";

const textSelectionHook = {
  mounted() {
    this.handleSelection = this.handleSelection.bind(this);
    this.hideSelectionActions = this.hideSelectionActions.bind(this);

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

    // Handle clicks outside - close panel only if clicking truly outside
    this.handleOutsideClick = (e) => {
      const selectionActionsEl = this.el.querySelector(".selection-actions");

      console.log("Click detected:", {
        target: e.target,
        panelExists: !!selectionActionsEl,
        panelHidden: selectionActionsEl?.classList.contains("hidden"),
        isInsidePanel: selectionActionsEl?.contains(e.target),
      });

      // If panel is not visible, nothing to do
      if (
        !selectionActionsEl ||
        selectionActionsEl.classList.contains("hidden")
      ) {
        console.log("Panel not visible, ignoring click");
        return;
      }

      // Check if click is inside the selection actions panel
      if (selectionActionsEl.contains(e.target)) {
        console.log("Click inside panel, keeping it open");
        return; // Don't close
      }

      // Close if clicking outside
      console.log("Click outside panel, closing");
      this.hideSelectionActions();
    };
    document.addEventListener("click", this.handleOutsideClick);

    // Handle selection clearing (but not when focused on input)
    this.handleSelectionChange = () => {
      const selection = window.getSelection();
      const selectionActionsEl = this.el.querySelector(".selection-actions");

      console.log("Selection change:", {
        collapsed: selection.isCollapsed,
        activeElement: document.activeElement,
        focusInPanel: selectionActionsEl?.contains(document.activeElement),
      });

      // Don't close if user has focus in the panel (e.g., typing in input)
      if (
        selectionActionsEl &&
        selectionActionsEl.contains(document.activeElement)
      ) {
        console.log("Focus in panel, keeping it open");
        return;
      }

      if (selection.isCollapsed) {
        console.log("Selection collapsed, checking after delay...");
        // Add delay to allow focus to register (focus fires after selection change)
        setTimeout(() => {
          const stillNoFocus =
            !selectionActionsEl ||
            !selectionActionsEl.contains(document.activeElement);
          if (stillNoFocus) {
            console.log("Still no focus in panel after delay, closing");
            this.hideSelectionActions();
          } else {
            console.log("Focus detected after delay, keeping panel open");
          }
        }, 50);
      }
    };
    document.addEventListener("selectionchange", this.handleSelectionChange);

    // Initial highlight load
    this.refreshHighlights();

    // Listen for events
    window.addEventListener("highlight:created", this.refreshHighlights);
    this.el.addEventListener("markdown:rendered", this.refreshHighlights);

    this.handleEvent("scroll_to_highlight", this.scrollToHighlight.bind(this));
    this.handleEvent("refresh_highlights", this.refreshHighlights);
  },

  destroyed() {
    clearTimeout(this._fetchTimeout);
    this.el.removeEventListener("mouseup", this.handleSelection);
    this.el.removeEventListener("touchend", this.handleSelection);
    document.removeEventListener("click", this.handleOutsideClick);
    document.removeEventListener("selectionchange", this.handleSelectionChange);
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
      this.hideSelectionActions();
      return;
    }

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
      selectionActionsEl.classList.add("flex");

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

      // Set up "Explain" quick action button
      const explainButton = selectionActionsEl.querySelector(".explain-btn");
      if (explainButton) {
        explainButton.onclick = () => {
          this.pushEvent("reply-and-answer", {
            vertex: { content: `Please explain: ${selectedText}` },
            prefix: "explain",
            highlight_context: selectedText,
          });
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

      // Set up custom question input and submit
      const customInput = selectionActionsEl.querySelector(
        ".custom-question-input",
      );
      const submitButton = selectionActionsEl.querySelector(
        ".submit-custom-question",
      );

      if (customInput && submitButton) {
        customInput.value = "";
        customInput.placeholder = "What would you like to know?";

        // Auto-focus the input for better UX (after a small delay to ensure panel is visible)
        setTimeout(() => {
          if (!selectionActionsEl.classList.contains("hidden")) {
            customInput.focus();
          }
        }, 100);

        submitButton.onclick = () => {
          const question = customInput.value.trim();
          if (question) {
            this.pushEvent("reply-and-answer", {
              vertex: {
                content: `${question}\n\nRegarding: "${selectedText}"`,
              },
              prefix: "explain",
              highlight_context: selectedText,
            });
            this.hideSelectionActions();
          }
        };

        // Handle Enter key to submit
        customInput.onkeydown = (e) => {
          if (e.key === "Enter" && !e.shiftKey) {
            e.preventDefault();
            submitButton.click();
          } else if (e.key === "Escape") {
            e.preventDefault();
            this.hideSelectionActions();
          }
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
      selectionActionsEl.classList.remove("flex");

      // Clear custom input if present
      const customInput = selectionActionsEl.querySelector(
        ".custom-question-input",
      );
      if (customInput) {
        customInput.value = "";
      }
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
        if (response.status === 401) {
          this.pushEvent("show_login_required", {});
          return null;
        }

        if (response.status === 422) {
          // Duplicate highlight - find and focus existing one
          return response.json().then((errorData) => {
            // Check if it's a duplicate constraint error
            if (
              errorData.errors &&
              errorData.errors.some((e) =>
                e.includes("highlight already exists"),
              )
            ) {
              // Try to find the existing highlight with same offsets
              return fetch(
                `/api/highlights?mudg_id=${this.mudgId}&node_id=${this.nodeId}`,
                { credentials: "include" },
              )
                .then((res) => res.json())
                .then((json) => {
                  const existingHighlight = json.data.find(
                    (h) =>
                      h.selection_start === offsets.start &&
                      h.selection_end === offsets.end,
                  );
                  if (existingHighlight) {
                    // Scroll to and pulse the existing highlight
                    this.scrollToHighlight({ id: existingHighlight.id });
                  }
                  return null;
                });
            }
            throw new Error("Failed to create highlight");
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

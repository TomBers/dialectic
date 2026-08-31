import HighlightUtils from "./highlight_utils.js";

const textSelectionHook = {
  mounted() {
    this.handleSelection = this.handleSelection.bind(this);
    this.handleSelectionStart = this.handleSelectionStart.bind(this);
    this.handleHighlightClick = this.handleHighlightClick.bind(this);
    this.handleLinkIconClick = this.handleLinkIconClick.bind(this);
    this.renderHighlightsForNode = this.renderHighlightsForNode.bind(this);
    this.retryPendingHighlightScroll =
      this.retryPendingHighlightScroll.bind(this);
    this.finalizePendingHighlightScroll =
      this.finalizePendingHighlightScroll.bind(this);
    this.closeHighlightsDrawerOnMobile =
      this.closeHighlightsDrawerOnMobile.bind(this);
    this.highlightsOnly = this.el.dataset.highlightsOnly === "true";
    this.highlightScrollRetryTimer = null;
    this.selectionStartedHere = false;

    // Get node ID from data attribute
    this.nodeId = this.el.dataset.nodeId;
    this.mudgId = this.el.dataset.mudgId;

    // Store element ID to prevent duplicate events
    this.elId = this.el.id;

    // Cache of all highlights pushed from server (shared across hook instances
    // via the window object so every node card sees the same data).
    if (!window.__highlightsCache) {
      window.__highlightsCache = [];
    }

    // Add event listeners for this specific container
    this.el.addEventListener("click", this.handleHighlightClick);
    this.el.addEventListener(
      "highlight-link-clicked",
      this.handleLinkIconClick,
    );

    if (!this.highlightsOnly) {
      this.el.addEventListener("mousedown", this.handleSelectionStart);
      this.el.addEventListener("touchstart", this.handleSelectionStart);
      document.addEventListener("mouseup", this.handleSelection);
      document.addEventListener("touchend", this.handleSelection);
    }

    // When the Markdown hook finishes rendering, re-apply highlights from cache
    this.el.addEventListener("markdown:rendered", this.renderHighlightsForNode);

    // Server pushes all highlights for the graph in one event.
    // Every hook instance listens, updates the shared cache, and renders
    // only the highlights relevant to its own node.
    this.handleEvent(
      "highlights_loaded",
      this.handleHighlightsLoaded.bind(this),
    );

    this.handleEvent("scroll_to_highlight", this.scrollToHighlight.bind(this));

    if (!this.highlightsOnly) {
      this.handleEvent("create_highlight", this.handleCreateHighlight.bind(this));
    }

    // Render any highlights already in the cache (e.g. if this hook mounts
    // after the initial highlights_loaded event already fired).
    this.renderHighlightsForNode();
  },

  handleCreateHighlight({ text, offsets }) {
    this.createHighlight(text, offsets);
  },

  destroyed() {
    if (this.highlightScrollRetryTimer) {
      clearTimeout(this.highlightScrollRetryTimer);
      this.highlightScrollRetryTimer = null;
    }

    this.el.removeEventListener(
      "highlight-link-clicked",
      this.handleLinkIconClick,
    );
    this.el.removeEventListener("click", this.handleHighlightClick);
    this.el.removeEventListener(
      "markdown:rendered",
      this.renderHighlightsForNode,
    );

    if (!this.highlightsOnly) {
      this.el.removeEventListener("mousedown", this.handleSelectionStart);
      this.el.removeEventListener("touchstart", this.handleSelectionStart);
      document.removeEventListener("mouseup", this.handleSelection);
      document.removeEventListener("touchend", this.handleSelection);
    }
  },

  // ── Highlights from server ──────────────────────────────────────────

  handleHighlightsLoaded({ highlights }) {
    window.__highlightsCache = highlights || [];
    this.renderHighlightsForNode();
    this.retryPendingHighlightScroll();
  },

  renderHighlightsForNode() {
    if (this.el.dataset.streaming === "true") return;
    if (!this.nodeId) return;

    const mdContainer = this.el.querySelector(
      '[phx-hook="Markdown"][data-body-only="true"]',
    );
    if (!mdContainer) return;

    const nodeHighlights = (window.__highlightsCache || []).filter(
      (h) => h.node_id === this.nodeId,
    );

    HighlightUtils.renderHighlights(mdContainer, nodeHighlights);
    this.retryPendingHighlightScroll();
  },

  // ── Link / click handling ───────────────────────────────────────────

  handleLinkIconClick(event) {
    const nodeId = event.detail?.nodeId;
    if (!nodeId) return;

    // Push event to parent LiveView to navigate to the linked node
    this.pushEvent("node_clicked", { id: nodeId });
  },

  handleHighlightClick(event) {
    const selection = window.getSelection();
    if (
      selection &&
      !selection.isCollapsed &&
      this.isSelectionInComponent(selection)
    ) {
      event.preventDefault();
      event.stopPropagation();
      return;
    }

    // Check if the clicked element is a highlight with a linked node
    const highlightSpan = event.target.closest(
      ".highlight-span.has-linked-node",
    );

    if (highlightSpan) {
      event.preventDefault();
      event.stopPropagation();

      const linkedNodeId = highlightSpan.dataset.linkedNodeId;
      const linkType = highlightSpan.dataset.linkType || "discussion";

      if (linkedNodeId) {
        // Send event to navigate to the linked node
        this.pushEvent("navigate_to_node", {
          node_id: linkedNodeId,
          source: "highlight_link",
          link_type: linkType,
        });
      }
    }
  },

  scrollToHighlight({ id }) {
    if (!id) return;

    const highlightId = id.toString();
    const cachedHighlight = (window.__highlightsCache || []).find(
      (highlight) => highlight.id?.toString() === highlightId,
    );

    if (
      cachedHighlight?.node_id &&
      this.nodeId &&
      cachedHighlight.node_id !== this.nodeId
    )
      return;

    window.__pendingHighlightScrollRequest = {
      id: highlightId,
      mudgId: this.mudgId,
      status: "requested",
      completedAt: null,
    };

    this.retryPendingHighlightScroll(0);
  },

  retryPendingHighlightScroll(attempts = 0) {
    const pendingRequest = window.__pendingHighlightScrollRequest;

    if (
      pendingRequest?.mudgId &&
      this.mudgId &&
      pendingRequest.mudgId !== this.mudgId
    ) {
      window.__pendingHighlightScrollRequest = null;
      return;
    }

    if (!pendingRequest || pendingRequest.status === "handled") return;

    if (this.highlightScrollRetryTimer) {
      clearTimeout(this.highlightScrollRetryTimer);
      this.highlightScrollRetryTimer = null;
    }

    const span = this.el.querySelector(
      `.highlight-span[data-highlight-id="${pendingRequest.id}"]`,
    );

    if (span) {
      if (pendingRequest.status === "requested") {
        window.__pendingHighlightScrollRequest = {
          ...pendingRequest,
          status: "scrolling",
        };
        this.pulseHighlight(span);
      }
      this.finalizePendingHighlightScroll(span, pendingRequest.id, attempts);
      return;
    }

    if (attempts >= 20) return;

    this.highlightScrollRetryTimer = setTimeout(() => {
      this.retryPendingHighlightScroll(attempts + 1);
    }, 100);
  },

  pulseHighlight(span) {
    this.scrollHighlightIntoView(span);

    const originalTransition = span.style.transition;
    const originalColor = span.style.backgroundColor;

    span.style.transition = "background-color 0.5s";
    span.style.backgroundColor = "rgba(255, 165, 0, 0.6)";

    setTimeout(() => {
      span.style.backgroundColor = originalColor;
      setTimeout(() => {
        span.style.transition = originalTransition;
      }, 500);
    }, 1500);
  },

  finalizePendingHighlightScroll(span, highlightId, attempts) {
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        const pendingRequest = window.__pendingHighlightScrollRequest;

        if (!pendingRequest || pendingRequest.id !== highlightId) return;

        if (this.isHighlightInView(span)) {
          window.__pendingHighlightScrollRequest = {
            ...pendingRequest,
            status: "handled",
            completedAt: Date.now(),
          };
          this.findScrollContainer(span)?.dispatchEvent(
            new CustomEvent("highlight-scroll-complete"),
          );
          this.closeHighlightsDrawerOnMobile();
          return;
        }

        if (attempts >= 20) return;

        this.highlightScrollRetryTimer = setTimeout(() => {
          this.retryPendingHighlightScroll(attempts + 1);
        }, 100);
      });
    });
  },

  scrollHighlightIntoView(span) {
    const scrollContainer = this.findScrollContainer(span);
    const behavior = this.highlightScrollBehavior(span);

    if (!scrollContainer) {
      span.scrollIntoView({ behavior, block: "center" });
      return;
    }

    const spanRect = span.getBoundingClientRect();
    const containerRect = scrollContainer.getBoundingClientRect();
    const currentScrollTop = scrollContainer.scrollTop;
    const containerCenter = containerRect.height / 2;
    const spanCenter = spanRect.top - containerRect.top + spanRect.height / 2;
    const targetScrollTop = currentScrollTop + spanCenter - containerCenter;

    scrollContainer.scrollTo({
      top: Math.max(0, targetScrollTop),
      behavior,
    });
  },

  highlightScrollBehavior(span) {
    const layout = span.closest("[data-reduce-motion]");
    return layout?.dataset.reduceMotion === "true" ? "auto" : "smooth";
  },

  isHighlightInView(span) {
    if (!span?.isConnected) return false;

    const scrollContainer = this.findScrollContainer(span);
    const spanRect = span.getBoundingClientRect();

    if (!scrollContainer) {
      const fullyVisible = spanRect.top >= 0 && spanRect.bottom <= window.innerHeight;
      const centered =
        Math.abs(spanRect.top + spanRect.height / 2 - window.innerHeight / 2) <= 24;
      return centered || fullyVisible;
    }

    const containerRect = scrollContainer.getBoundingClientRect();
    const fullyVisible =
      spanRect.top >= containerRect.top && spanRect.bottom <= containerRect.bottom;
    const centered =
      Math.abs(
        spanRect.top +
          spanRect.height / 2 -
          (containerRect.top + containerRect.height / 2),
      ) <= 24;
    const maxScrollTop = scrollContainer.scrollHeight - scrollContainer.clientHeight;
    const atScrollBoundary =
      scrollContainer.scrollTop <= 1 || scrollContainer.scrollTop >= maxScrollTop - 1;

    return centered || (fullyVisible && atScrollBoundary);
  },

  closeHighlightsDrawerOnMobile() {
    if (!window.matchMedia("(max-width: 639px)").matches) return;

    const drawer = document.getElementById("highlights-drawer");
    if (!drawer || drawer.classList.contains("translate-x-full")) return;

    const layout =
      document.getElementById("outline-layout") ||
      document.getElementById("graph-layout");

    if (!layout) return;

    layout.dispatchEvent(
      new CustomEvent("close-panel-on-mobile", {
        detail: { id: "highlights-drawer" },
      }),
    );
  },

  findScrollContainer(element) {
    let current = element.parentElement;

    while (current) {
      const style = window.getComputedStyle(current);
      const overflowY = style.overflowY;
      const canScroll =
        (overflowY === "auto" || overflowY === "scroll") &&
        current.scrollHeight > current.clientHeight;

      if (canScroll) {
        return current;
      }

      current = current.parentElement;
    }

    const scrollingElement = document.scrollingElement;
    return scrollingElement && scrollingElement.scrollHeight > window.innerHeight
      ? scrollingElement
      : null;
  },

  // ── Text selection handling ─────────────────────────────────────────

  handleSelectionStart(event) {
    this.selectionStartedHere =
      !event.target.closest(".highlight-link-icon") &&
      !event.target.closest(".highlight-links-container");
  },

  handleSelection(event) {
    if (!this.selectionStartedHere) return;
    this.selectionStartedHere = false;

    if (this.el.dataset.streaming === "true") {
      return;
    }

    const selection = window.getSelection();

    if (
      !selection ||
      selection.isCollapsed ||
      !this.isSelectionInComponent(selection)
    ) {
      return;
    }

    const selectedText = selection.toString().trim();
    if (selectedText.length === 0 || !this.isClosestSelectionContainer()) return;

    const mdContainer = this.el.querySelector(
      '[phx-hook="Markdown"][data-body-only="true"]',
    );
    const capturedOffsets = mdContainer
      ? this.getSelectionOffsets(mdContainer)
      : null;

    window.dispatchEvent(
      new CustomEvent("selection:show", {
        detail: {
          selectedText,
          nodeId: this.nodeId,
          offsets: capturedOffsets,
        },
      }),
    );
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

  // ── Highlight creation (still uses the API for writes) ──────────────

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
          return response.json().then((errorData) => {
            // Check if it's a duplicate constraint error
            const isDuplicateError =
              errorData.errors &&
              Object.values(errorData.errors).some(
                (errorArray) =>
                  Array.isArray(errorArray) &&
                  errorArray.some((msg) =>
                    msg.includes("highlight already exists"),
                  ),
              );

            if (isDuplicateError) {
              // Find the overlapping highlight from the local cache
              const overlapping = (window.__highlightsCache || []).find(
                (h) =>
                  h.node_id === this.nodeId &&
                  h.selection_start < offsets.end &&
                  h.selection_end > offsets.start,
              );
              if (overlapping) {
                this.scrollToHighlight({ id: overlapping.id });
              }
              return null;
            }

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
        // The server PubSub will push an updated highlights_loaded event,
        // so we don't need to manually refresh here.
        if (!data) return;
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

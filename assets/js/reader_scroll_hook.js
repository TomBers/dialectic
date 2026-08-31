const ReaderScrollHook = {
  mounted() {
    this.storageKey = this.el.dataset.readerScrollKey;
    this.savedScrollTop = this.el.scrollTop;
    this.savedScrollLeft = this.el.scrollLeft;
    this.activeNodeId = null;
    this.scrollFrame = null;
    this.setRestoringScroll(false);
    this.onHighlightScrollComplete = () => {
      this.savedScrollTop = this.el.scrollTop;
      this.syncViewedSection();
    };
    this.onGraphNavigation = (event) => {
      const graphLink = event.target.closest(
        'a[data-view-transition-direction="graph"]',
      );
      if (!graphLink) return;

      const selectedNodeId = new URL(window.location.href).searchParams.get("node");
      if (selectedNodeId) {
        const graphUrl = new URL(graphLink.href, window.location.origin);
        graphUrl.searchParams.set("node", selectedNodeId);
        graphLink.href = graphUrl.toString();
      }

      this.storeReaderPosition();
    };
    this.onScroll = () => {
      if (
        this.restoringScroll ||
        this.highlightScrollActive() ||
        this.scrollFrame !== null
      )
        return;

      this.scrollFrame = requestAnimationFrame(() => {
        this.scrollFrame = null;
        if (this.highlightScrollActive()) return;
        this.syncViewedSection();
      });
    };
    this.el.addEventListener("scroll", this.onScroll, { passive: true });
    this.el.addEventListener(
      "highlight-scroll-complete",
      this.onHighlightScrollComplete,
    );
    if (this.storageKey)
      document.addEventListener("click", this.onGraphNavigation, true);
    this.handleEvent?.("scroll_to_reader_node", ({ id }) => {
      requestAnimationFrame(() => {
        requestAnimationFrame(() => this.scrollToNode(id));
      });
    });
    const restoredPosition = this.restoreReaderPosition();
    const requestedNodeId = this.el.dataset.selectedReaderNodeId;

    if (
      !restoredPosition &&
      requestedNodeId &&
      this.viewedNodeId() !== requestedNodeId
    ) {
      this.setRestoringScroll(true);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          if (!this.el.isConnected) return;
          this.scrollToNode(requestedNodeId);
        });
      });
    } else if (!restoredPosition && requestedNodeId) {
      this.activeNodeId = requestedNodeId;
    }
  },

  destroyed() {
    this.el.removeEventListener("scroll", this.onScroll);
    this.el.removeEventListener(
      "highlight-scroll-complete",
      this.onHighlightScrollComplete,
    );
    if (this.storageKey)
      document.removeEventListener("click", this.onGraphNavigation, true);
    if (this.scrollFrame !== null) cancelAnimationFrame(this.scrollFrame);
  },

  storeReaderPosition() {
    if (!this.storageKey) return;

    const anchor = this.firstVisibleSection();
    const position = {
      top: this.el.scrollTop,
      left: this.el.scrollLeft,
      anchor,
      nodeId: this.viewedNodeId(),
    };

    sessionStorage.setItem(this.storageKey, JSON.stringify(position));
    sessionStorage.setItem(`${this.storageKey}:restore`, "true");
  },

  restoreReaderPosition() {
    if (
      !this.storageKey ||
      sessionStorage.getItem(`${this.storageKey}:restore`) !== "true"
    )
      return false;

    sessionStorage.removeItem(`${this.storageKey}:restore`);

    let position;
    try {
      position = JSON.parse(sessionStorage.getItem(this.storageKey) || "null");
    } catch (_error) {
      return false;
    }

    if (!position) return false;

    const requestedNodeId = this.el.dataset.selectedReaderNodeId;

    if (
      position.nodeId &&
      requestedNodeId &&
      position.nodeId !== requestedNodeId
    ) {
      this.setRestoringScroll(true);
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          if (!this.el.isConnected) return;
          this.scrollToNode(requestedNodeId);
        });
      });
      return true;
    }

    this.setRestoringScroll(true);
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        if (!this.el.isConnected) return;

        this.el.scrollTop = position.top || 0;
        this.el.scrollLeft = position.left || 0;

        if (position.anchor?.id) {
          const section = document.getElementById(position.anchor.id);
          if (section && this.el.contains(section)) {
            const containerTop = this.el.getBoundingClientRect().top;
            const currentOffset = section.getBoundingClientRect().top - containerTop;
            this.el.scrollTop += currentOffset - position.anchor.offset;
          }
        }

        this.savedScrollTop = this.el.scrollTop;
        this.savedScrollLeft = this.el.scrollLeft;
        this.setRestoringScroll(false);
      });
    });

    return true;
  },

  highlightScrollActive() {
    const status = window.__pendingHighlightScrollRequest?.status;
    return status === "requested" || status === "scrolling";
  },

  beforeUpdate() {
    this.savedScrollTop = this.el.scrollTop;
    this.savedScrollLeft = this.el.scrollLeft;
    this.savedAnchor = this.firstVisibleSection();
    this.setRestoringScroll(true);
  },

  updated() {
    const top = this.savedScrollTop;
    const left = this.savedScrollLeft;
    const anchor = this.savedAnchor;

    this.setRestoringScroll(true);
    this.el.scrollTop = top;
    this.el.scrollLeft = left;

    requestAnimationFrame(() => {
      if (!this.el.isConnected) return;

      if (anchor) {
        const section = document.getElementById(anchor.id);
        if (section && this.el.contains(section)) {
          const containerTop = this.el.getBoundingClientRect().top;
          const currentOffset = section.getBoundingClientRect().top - containerTop;
          this.el.scrollTop += currentOffset - anchor.offset;
          this.el.scrollLeft = left;
          requestAnimationFrame(() => {
            this.setRestoringScroll(false);
          });
          return;
        }
      }

      this.el.scrollTop = top;
      this.el.scrollLeft = left;
      requestAnimationFrame(() => {
        this.setRestoringScroll(false);
      });
    });
  },

  scrollToNode(nodeId) {
    const section = document.getElementById(`reading-node-${nodeId}`);
    if (!section || !this.el.contains(section)) return;

    const containerTop = this.el.getBoundingClientRect().top;
    const sectionTop = section.getBoundingClientRect().top;
    const targetTop = Math.max(0, this.el.scrollTop + sectionTop - containerTop - 24);

    this.activeNodeId = String(nodeId);
    this.setRestoringScroll(true);
    this.el.scrollTop = targetTop;
    this.savedScrollTop = targetTop;

    requestAnimationFrame(() => {
      this.setRestoringScroll(false);
    });
  },

  setRestoringScroll(restoring) {
    this.restoringScroll = restoring;
    this.el.dataset.readerScrollRestoring = restoring ? "true" : "false";
  },

  syncViewedSection() {
    const nodeId = this.viewedNodeId();
    if (!nodeId || nodeId === this.activeNodeId) return;

    this.activeNodeId = nodeId;
    this.pushEvent?.("reader_node_viewed", { id: nodeId });

    const url = new URL(window.location.href);
    url.searchParams.set("node", nodeId);
    window.history.replaceState(window.history.state, "", url);
  },

  viewedNodeId() {
    const containerRect = this.el.getBoundingClientRect();
    const marker = containerRect.top + Math.min(120, containerRect.height * 0.25);
    const sections = Array.from(this.el.querySelectorAll("[id^='reading-node-']"));
    const visibleSections = sections.filter((section) => {
      const rect = section.getBoundingClientRect();
      return rect.bottom > containerRect.top && rect.top < containerRect.bottom;
    });

    if (visibleSections.length === 0) return null;

    const active =
      [...visibleSections]
        .reverse()
        .find((section) => section.getBoundingClientRect().top <= marker) ||
      visibleSections[0];

    return active.id.replace("reading-node-", "");
  },

  firstVisibleSection() {
    const containerTop = this.el.getBoundingClientRect().top;
    const sections = this.el.querySelectorAll("[id^='reading-node-']");

    for (const section of sections) {
      const rect = section.getBoundingClientRect();
      if (rect.bottom > containerTop) {
        return { id: section.id, offset: rect.top - containerTop };
      }
    }

    return null;
  },
};

export default ReaderScrollHook;

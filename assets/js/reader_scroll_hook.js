const ReaderScrollHook = {
  mounted() {
    this.savedScrollTop = this.el.scrollTop;
    this.savedScrollLeft = this.el.scrollLeft;
    this.activeNodeId = null;
    this.scrollFrame = null;
    this.restoringScroll = false;
    this.onHighlightScrollComplete = () => {
      this.savedScrollTop = this.el.scrollTop;
      this.syncViewedSection();
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
    this.handleEvent?.("scroll_to_reader_node", ({ id }) => {
      requestAnimationFrame(() => {
        requestAnimationFrame(() => this.scrollToNode(id));
      });
    });
  },

  destroyed() {
    this.el.removeEventListener("scroll", this.onScroll);
    this.el.removeEventListener(
      "highlight-scroll-complete",
      this.onHighlightScrollComplete,
    );
    if (this.scrollFrame !== null) cancelAnimationFrame(this.scrollFrame);
  },

  highlightScrollActive() {
    const status = window.__pendingHighlightScrollRequest?.status;
    return status === "requested" || status === "scrolling";
  },

  beforeUpdate() {
    this.savedScrollTop = this.el.scrollTop;
    this.savedScrollLeft = this.el.scrollLeft;
    this.savedAnchor = this.firstVisibleSection();
  },

  updated() {
    const top = this.savedScrollTop;
    const left = this.savedScrollLeft;
    const anchor = this.savedAnchor;

    this.restoringScroll = true;
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
            this.restoringScroll = false;
          });
          return;
        }
      }

      this.el.scrollTop = top;
      this.el.scrollLeft = left;
      requestAnimationFrame(() => {
        this.restoringScroll = false;
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
    this.restoringScroll = true;
    this.el.scrollTop = targetTop;
    this.savedScrollTop = targetTop;

    requestAnimationFrame(() => {
      this.restoringScroll = false;
    });
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

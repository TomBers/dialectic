const SelectionActionsHook = {
  mounted() {
    // Bind methods
    this.handleSelectionShow = this.handleSelectionShow.bind(this);
    this.handleKeydown = this.handleKeydown.bind(this);
    this.clearBrowserSelection = this.clearBrowserSelection.bind(this);
    this.handleModalMutations = this.handleModalMutations.bind(this);
    this.handleClick = this.handleClick.bind(this);
    this.handleSubmit = this.handleSubmit.bind(this);

    // Store reference to the component element (first child div of this hook)
    this.componentEl = this.el.firstElementChild;
    this.wasVisible = this.isModalVisible();
    this.modalObserver = null;
    this.observeModalVisibility();

    // Listen for custom event from text selection to show modal
    window.addEventListener("selection:show", this.handleSelectionShow);

    // Window keydown for escape
    window.addEventListener("keydown", this.handleKeydown);
    this.el.addEventListener("click", this.handleClick);
    this.el.addEventListener("submit", this.handleSubmit);
  },

  destroyed() {
    if (this.modalObserver) {
      this.modalObserver.disconnect();
      this.modalObserver = null;
    }
    window.removeEventListener("selection:show", this.handleSelectionShow);
    window.removeEventListener("keydown", this.handleKeydown);
    this.el.removeEventListener("click", this.handleClick);
    this.el.removeEventListener("submit", this.handleSubmit);
  },

  updated() {
    this.observeModalVisibility();
  },

  isModalVisible() {
    const modalEl = this.componentEl?.querySelector('[id^="selection-actions-modal-"]');
    return !!modalEl && !modalEl.classList.contains("hidden");
  },

  observeModalVisibility() {
    const modalEl = this.componentEl?.querySelector('[id^="selection-actions-modal-"]');
    if (!modalEl) return;

    if (this.modalObserverTarget === modalEl) {
      this.wasVisible = !modalEl.classList.contains("hidden");
      return;
    }

    if (this.modalObserver) {
      this.modalObserver.disconnect();
    }

    this.modalObserverTarget = modalEl;
    this.wasVisible = !modalEl.classList.contains("hidden");
    this.modalObserver = new MutationObserver(this.handleModalMutations);
    this.modalObserver.observe(modalEl, {
      attributes: true,
      attributeFilter: ["class"],
    });
  },

  handleModalMutations() {
    const isVisible = this.isModalVisible();

    if (this.wasVisible && !isVisible) {
      this.clearBrowserSelection();
    }

    this.wasVisible = isVisible;
  },

  clearBrowserSelection() {
    const selection = window.getSelection();
    if (selection && selection.rangeCount > 0) {
      selection.removeAllRanges();
    }
  },

  handleClick(event) {
    const actionEl = event.target.closest(
      '[phx-click="close"], [phx-click="explain"], [phx-click="highlight_only"], [phx-click="pros_cons"], [phx-click="related_ideas"]',
    );

    if (!actionEl || !this.el.contains(actionEl)) return;

    window.setTimeout(() => this.clearBrowserSelection(), 0);
  },

  handleSubmit(event) {
    const formEl = event.target.closest('form[phx-submit="submit_input"]');
    if (!formEl || !this.el.contains(formEl)) return;

    window.setTimeout(() => this.clearBrowserSelection(), 0);
  },

  handleSelectionShow(event) {
    const { selectedText, nodeId, offsets } = event.detail;

    // Push event to LiveComponent to show modal and load data
    if (this.componentEl) {
      this.pushEventTo(this.componentEl, "show", {
        selectedText: selectedText,
        nodeId: nodeId,
        offsets: offsets,
      });
    }
  },

  handleKeydown(e) {
    if (e.key === "Escape") {
      e.preventDefault();
      // Push close event to component
      if (this.componentEl) {
        this.pushEventTo(this.componentEl, "close", {});
      }
    }
  },
};

export default SelectionActionsHook;

const SelectionActionsHook = {
  mounted() {
    // Bind methods
    this.handleSelectionShow = this.handleSelectionShow.bind(this);
    this.handleKeydown = this.handleKeydown.bind(this);

    // Store reference to the component element (first child div of this hook)
    this.componentEl = this.el.firstElementChild;

    // Listen for custom event from text selection to show modal
    window.addEventListener("selection:show", this.handleSelectionShow);

    // Window keydown for escape
    window.addEventListener("keydown", this.handleKeydown);
  },

  destroyed() {
    window.removeEventListener("selection:show", this.handleSelectionShow);
    window.removeEventListener("keydown", this.handleKeydown);
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
      // Clear selection
      window.getSelection().removeAllRanges();
    }
  },
};

export default SelectionActionsHook;

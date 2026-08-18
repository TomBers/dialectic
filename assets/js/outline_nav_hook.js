const OutlineNavHook = {
  mounted() {
    this.lastSelectedId = null;
    this.syncSelectedIntoView();
  },

  updated() {
    this.syncSelectedIntoView();
  },

  syncSelectedIntoView() {
    const selected = this.el.querySelector("[data-outline-selected='true']");
    if (!selected) return;

    const selectedId = selected.id || null;
    if (selectedId === this.lastSelectedId) return;

    this.lastSelectedId = selectedId;

    const scrollToSelection = () => {
      const containerRect = this.el.getBoundingClientRect();
      const selectedRect = selected.getBoundingClientRect();
      const centeredOffset = (this.el.clientHeight - selectedRect.height) / 2;

      this.el.scrollTop = Math.max(
        0,
        this.el.scrollTop + selectedRect.top - containerRect.top - centeredOffset,
      );
    };

    requestAnimationFrame(() => {
      scrollToSelection();
      requestAnimationFrame(scrollToSelection);
    });
  },
};

export default OutlineNavHook;

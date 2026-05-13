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
      selected.scrollIntoView({
        behavior: "auto",
        block: "center",
        inline: "nearest",
      });
    };

    requestAnimationFrame(() => {
      scrollToSelection();
      requestAnimationFrame(scrollToSelection);
    });
  },
};

export default OutlineNavHook;

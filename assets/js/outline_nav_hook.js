const OutlineNavHook = {
  mounted() {
    this.scrollSelectedIntoView();
  },

  updated() {
    this.scrollSelectedIntoView();
  },

  scrollSelectedIntoView() {
    const selected = this.el.querySelector("[data-outline-selected='true']");
    if (!selected) return;

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

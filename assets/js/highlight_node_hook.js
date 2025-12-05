const HighlightNode = {
  mounted() {
    // Bind the handler so we can add/remove it properly
    this.onHashChange = this.onHashChange.bind(this);

    // Run initial check
    this.onHashChange();

    // Listen for hash changes
    window.addEventListener("hashchange", this.onHashChange);
  },

  destroyed() {
    window.removeEventListener("hashchange", this.onHashChange);
  },

  onHashChange() {
    const currentNodeId = this.el.id.replace("node-", "");
    const hashNodeId = window.location.hash.substring(1);

    if (hashNodeId && currentNodeId === hashNodeId) {
      this.el.classList.add("selected-node");
      this.scrollToNode();
    } else {
      this.el.classList.remove("selected-node");
    }
  },

  scrollToNode() {
    // We use manual window.scrollTo instead of scrollIntoView to better control
    // the offset, ensuring the sticky header doesn't obscure the content.
    // Using a timeout allows any native browser behavior or layout shifts to settle first.
    setTimeout(() => {
      const offset = 150; // Adjust for header height + padding
      const elementRect = this.el.getBoundingClientRect();
      const absoluteElementTop = elementRect.top + window.scrollY;
      const targetPosition = absoluteElementTop - offset;

      window.scrollTo({
        top: targetPosition,
        behavior: "smooth",
      });
    }, 100);
  },
};

export default HighlightNode;

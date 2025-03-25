const HighlightNode = {
  mounted() {
    // Check if this node matches the current hash
    const currentNodeId = this.el.id.replace("node-", "");
    const hashNodeId = window.location.hash.substring(1);

    if (currentNodeId === hashNodeId) {
      this.el.classList.add("selected-node");
      this.el.scrollIntoView({ behavior: "smooth", block: "center" });
    }

    // Listen for hash changes
    window.addEventListener("hashchange", () => {
      const hashNodeId = window.location.hash.substring(1);
      if (currentNodeId === hashNodeId) {
        this.el.classList.add("selected-node");
        this.el.scrollIntoView({ behavior: "smooth", block: "center" });
      } else {
        this.el.classList.remove("selected-node");
      }
    });
  },
};

export default HighlightNode;

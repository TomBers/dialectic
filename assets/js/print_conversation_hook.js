const printConversationHook = {
  mounted() {
    this.el.addEventListener("click", () => {
      // Set current date/time as a data attribute on body for the print header
      document.body.setAttribute(
        "data-print-date",
        new Date().toLocaleString(),
      );

      // Expand all nodes before printing if some are collapsed
      const hiddenNodes = document.querySelectorAll(
        '.node[style*="display: none"]',
      );
      const wasExpanded = [];

      hiddenNodes.forEach((node) => {
        wasExpanded.push(node);
        node.style.display = "flex"; // Make visible for printing
      });

      // Call browser print function
      window.print();

      // After print dialog closes, restore collapsed nodes
      setTimeout(() => {
        wasExpanded.forEach((node) => {
          node.style.display = "none";
        });
      }, 500);
    });
  },
};

export default printConversationHook;

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

      // Add a small delay to ensure nodes have time to expand before printing
      setTimeout(() => {
        // Call browser print function
        window.print();

        // After print dialog closes, restore collapsed nodes
        setTimeout(() => {
          wasExpanded.forEach((node) => {
            node.style.display = "none";
          });
        }, 500);
      }, 300); // 300ms delay should be enough for the DOM to update
    });
  },
};

export default printConversationHook;

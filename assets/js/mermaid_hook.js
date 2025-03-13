// In your app.js or hooks.js file

const mermaidHook = {
  // Called when the element is initially added to the DOM
  mounted() {
    this.renderMermaid();

    // Set up a listener to be notified when the content changes
    this.handleEvent("mermaid-update", () => {
      this.renderMermaid();
    });
  },

  // Called when any direct property of the element changes
  // (e.g., data attributes)
  updated() {
    this.renderMermaid();
  },

  // Render the Mermaid diagram
  renderMermaid() {
    // Make sure Mermaid.js is loaded
    if (typeof mermaid === "undefined") {
      console.error("Mermaid.js not loaded");
      this.loadMermaid();
      return;
    }

    // Get the content from the data attribute
    const content = this.el.dataset.mermaid;

    if (!content) {
      console.warn("No Mermaid content found");
      return;
    }

    // Configure Mermaid
    mermaid.initialize({
      startOnLoad: false,
      theme: "neutral",
      securityLevel: "loose", // Required for callbacks
      flowchart: {
        htmlLabels: true,
        curve: "basis",
      },
    });

    // Create a unique ID for this diagram
    const id = `mermaid-${Date.now()}`;

    try {
      // Clear previous content
      this.el.innerHTML = "";

      // Render the new diagram
      mermaid.render(id, content).then((result) => {
        this.el.innerHTML = result.svg;

        // Add click handlers to nodes
        this.addNodeClickHandlers();
      });
    } catch (error) {
      console.error("Error rendering Mermaid diagram:", error);
      this.el.innerHTML = `<pre class="error">${error.message}</pre><pre>${content}</pre>`;
    }
  },

  // Add click handlers to nodes in the diagram
  addNodeClickHandlers() {
    const nodes = this.el.querySelectorAll(".node");

    nodes.forEach((node) => {
      // Get the node ID from the element
      const nodeId = node.id;

      if (!nodeId) return;

      // Add click event listener
      node.style.cursor = "pointer";
      node.addEventListener("click", (event) => {
        // Push the event to the server
        this.pushEvent("node_selected", { id: nodeId });

        // Highlight the selected node
        nodes.forEach((n) => n.classList.remove("selected"));
        node.classList.add("selected");

        event.stopPropagation();
      });
    });
  },

  // Load Mermaid.js dynamically if not present
  loadMermaid() {
    if (window.mermaidLoading) return;

    window.mermaidLoading = true;

    const script = document.createElement("script");
    script.src = "https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js";
    script.onload = () => {
      window.mermaidLoading = false;
      this.renderMermaid();
    };
    document.head.appendChild(script);
  },
};

// Add CSS for the selected node highlight
const style = document.createElement("style");
style.textContent = `
  .node.selected rect, .node.selected circle, .node.selected ellipse, .node.selected polygon, .node.selected path {
    stroke-width: 3px !important;
    filter: drop-shadow(0 0 5px rgba(0, 0, 0, 0.3));
  }
`;
document.head.appendChild(style);

// Export the hooks for use in your LiveView
export default mermaidHook;

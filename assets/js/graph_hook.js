import { draw_graph } from "./draw_graph";
import { layoutConfig } from "./layout_config.js";

const layoutGraph = (cy) => {
  const layout = cy.layout({
    ...layoutConfig.baseLayout,
    // Add callback for when layout is done
    ready: function () {},
    // Make sure animation settings are applied
    animate: true,
  });

  // Run the layout
  layout.run();
};

const graphHook = {
  mounted() {
    const { graph, node, div } = this.el.dataset;

    this.cy = draw_graph(
      document.getElementById(div),
      this,
      JSON.parse(graph),
      node,
    );
  },
  updated() {
    const { graph, node, operation } = this.el.dataset;

    this.cy.json({ elements: JSON.parse(graph) });

    const reorderOperations = new Set([
      // "delete_node",
      // "edit_node",
      // "branch",
      "combine",
      "answer",
      "llm_request_complete",
      "comment",
    ]);

    if (reorderOperations.has(operation)) {
      // Apply layout with minor delay to ensure nodes are ready
      setTimeout(() => layoutGraph(this.cy), 50);
    }

    this.cy.elements().removeClass("selected");
    this.cy.$(`#${node}`).addClass("selected");
  },
};

export default graphHook;

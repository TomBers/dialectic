import { draw_graph } from "./draw_graph";
import { layoutConfig } from "./layout_config.js";

const layoutGraph = (cy) => {
  const layout = cy.layout({
    ...layoutConfig.baseLayout,
    // Add callback for when layout is done
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

    // Listen for the center_node event from LiveView
    this.handleEvent("center_node", ({ id }) => {
      const nodeToCenter = this.cy.$(`#${id}`);
      if (nodeToCenter.length > 0) {
        this.cy.animate({
          center: {
            eles: nodeToCenter,
          },
          zoom: 1.2,
          duration: 150,
          easing: "ease-in-out-quad",
        });
      }
    });
  },
  updated() {
    const { graph, node, operation } = this.el.dataset;

    this.cy.json({ elements: JSON.parse(graph) });

    const reorderOperations = new Set([
      "combine",
      "answer",
      "llm_request_complete",
      "comment",
      "other_user_change",
    ]);

    if (reorderOperations.has(operation)) {
      layoutGraph(this.cy);
    }

    this.cy.elements().removeClass("selected");
    this.cy.$(`#${node}`).addClass("selected");
  },
};

export default graphHook;

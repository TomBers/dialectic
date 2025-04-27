import { draw_graph } from "./draw_graph";

const layoutGraph = (cy) => {
  const sep = 50;
  const layout = cy.layout({
    name: "dagre",
    rankDir: "TB",
    nodeSep: sep,
    edgeSep: sep,
    rankSep: sep,
    // Add a callback for when layout is done
    ready: function () {},
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
      "delete_node",
      "edit_node",
      "branch",
      "combine",
      "answer",
      "llm_request_complete",
      "comment",
    ]);

    if (reorderOperations.has(operation)) {
      layoutGraph(this.cy); // your Dagre call
    }

    this.cy.elements().removeClass("selected");
    this.cy.$(`#${node}`).addClass("selected");
  },
};

export default graphHook;

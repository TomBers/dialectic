import { draw_graph } from "./draw_graph";

const layoutGraph = (cy) => {
  const layout = cy.layout({
    name: "dagre",
    rankDir: "TB",
    nodeSep: 20,
    edgeSep: 15,
    rankSep: 30,
    // Add a callback for when layout is done
    ready: function () {},
  });

  // Run the layout
  layout.run();
};

const graphHook = {
  mounted() {
    const { graph, node, div } = this.el.dataset;

    const div_id = document.getElementById(div);
    const elements = JSON.parse(graph);
    nodes = elements;

    this.cy = draw_graph(div_id, this, elements, node);
    this.handleEvent("llm_request_complete", () => {
      layoutGraph(this.cy);
    });
  },
  updated() {
    const { graph, node, operation } = this.el.dataset;

    const newElements = JSON.parse(graph);

    this.cy.json({ elements: newElements });
    const reorderOerations = new Set([
      "grouping",
      "ungrouping",
      "move",
      "colorchange",
    ]);

    if (reorderOerations.has(operation)) {
      layoutGraph(this.cy); // your Dagre call
    }

    this.cy.elements().removeClass("selected");
    this.cy.$(`#${node}`).addClass("selected");
  },
};

export default graphHook;

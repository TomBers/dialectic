import { draw_graph } from "./draw_graph";

let numNodes = null;
let nodeId = null;

const graphHook = {
  mounted() {
    // Hide the user header
    document.getElementById("userHeader").style.display = "none";

    const { graph, node, cols, div } = this.el.dataset;
    const div_id = document.getElementById(div);
    const elements = JSON.parse(graph);

    numNodes = elements;
    nodeId = node;
    this.cy = draw_graph(div_id, this, elements, cols, node);
  },
  updated() {
    const { graph, node, updateview } = this.el.dataset;

    const newElements = JSON.parse(graph);
    this.cy.json({ elements: newElements });

    if (newElements.length != numNodes.length) {
      this.cy
        .layout({
          name: "dagre",
          rankDir: "TB",
          nodeSep: 20,
          edgeSep: 15,
          rankSep: 30,
        })
        .run();
    }
    if (node != nodeId && updateview == "true") {
      this.cy.animate({
        center: {
          eles: `#${node}`,
        },
        zoom: 2,
      });
    }

    this.cy.elements().removeClass("selected");
    this.cy.$(`#${node}`).addClass("selected");

    nodeId = node;
    numNodes = newElements;
  },
};

export default graphHook;

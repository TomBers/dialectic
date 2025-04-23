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
    const { graph, node } = this.el.dataset;

    const newElements = JSON.parse(graph);
    this.cy.json({ elements: newElements });

    const prevNodeCount = numNodes.filter(
      (n) => n.data && n.data.compound !== true,
    );

    const newNodeCount = newElements.filter(
      (n) => n.data && n.data.compound !== true,
    );

    // Only relayout if the number of actual nodes changed
    if (prevNodeCount.length !== newNodeCount.length) {
      // Create the layout but don't run it yet
      const layout = this.cy.layout({
        name: "dagre",
        rankDir: "TB",
        nodeSep: 20,
        edgeSep: 15,
        rankSep: 30,
        // Add a callback for when layout is done
        ready: function () {
          console.log("Layout ready");
        },
        // This gets called when the layout is done running
        stop: function () {
          console.log("Layout finished");
          // Now center on the node
          this.cy.animate({
            center: {
              eles: `#${node}`,
            },
            zoom: 2,
            // Optional: make this animation a bit slower to allow user to see context
            duration: 750,
          });
        }.bind(this), // Bind 'this' to maintain context
      });

      // Run the layout
      layout.run();
    }

    this.cy.elements().removeClass("selected");
    this.cy.$(`#${node}`).addClass("selected");

    nodeId = node;
    numNodes = newElements;
  },
};

export default graphHook;

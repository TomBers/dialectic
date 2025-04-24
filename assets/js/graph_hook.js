import { draw_graph } from "./draw_graph";

let nodes = null;

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

function hasRelevantChanges(oldNodes, newNodes) {
  // Filter out compound nodes from both sets
  const filteredOldNodes = oldNodes.filter((node) => !node.data.compound);
  const filteredNewNodes = newNodes.filter((node) => !node.data.compound);

  // Create maps for faster lookups by ID
  const oldNodesMap = new Map(
    filteredOldNodes.map((node) => [node.data.id, node]),
  );
  const newNodesMap = new Map(
    filteredNewNodes.map((node) => [node.data.id, node]),
  );

  // Check for new nodes that don't exist in the old set
  for (const node of filteredNewNodes) {
    const nodeId = node.data.id;

    // If node doesn't exist in old set, it's a relevant change
    if (!oldNodesMap.has(nodeId)) {
      return true;
    }

    // If node exists but content changed, it's a relevant change
    const oldNode = oldNodesMap.get(nodeId);
    if (oldNode.data.content !== node.data.content) {
      return true;
    }
  }

  // Check if any nodes were removed
  for (const nodeId of oldNodesMap.keys()) {
    if (!newNodesMap.has(nodeId)) {
      return true;
    }
  }

  // No relevant changes found
  return false;
}

const graphHook = {
  mounted() {
    const { graph, node, div } = this.el.dataset;

    const div_id = document.getElementById(div);
    const elements = JSON.parse(graph);
    nodes = elements;

    this.cy = draw_graph(div_id, this, elements, node);
  },
  updated() {
    const { graph, node } = this.el.dataset;

    const newElements = JSON.parse(graph);

    this.cy.json({ elements: newElements });
    if (hasRelevantChanges(nodes, newElements)) {
      layoutGraph(this.cy); // your Dagre call
    }

    this.cy.elements().removeClass("selected");
    this.cy.$(`#${node}`).addClass("selected");
    nodes = newElements;
  },
};

export default graphHook;

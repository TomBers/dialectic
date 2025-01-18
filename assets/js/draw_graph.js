import cytoscape from "cytoscape";

export function draw_graph(graph, context, elements, node_clicked) {
  window.cy = cytoscape({
    container: graph, // container to render in
    elements: elements,

    style: [
      // the stylesheet for the graph
      {
        selector: "node",
        style: {
          "background-color": "#666",
          label: "data(id)",
        },
      },
      {
        selector: `#${node_clicked}`,
        css: { "border-width": 3, "border-color": "black" },
      },
      {
        selector: "edge",
        style: {
          width: 3,
          "line-color": "#ccc",
          "target-arrow-color": "#ccc",
          "target-arrow-shape": "triangle",
          "curve-style": "bezier",
        },
      },
    ],

    layout: {
      name: "breadthfirst",
      directed: true,
      padding: 10,
    },
  });
  cy.on("tap", "node", function () {
    // console.log(this);
    var node = this;
    context.pushEvent("node_clicked", { id: node.id() });
  });
  window.cy = cy;
}

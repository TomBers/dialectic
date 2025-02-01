import cytoscape from "cytoscape";
import dagre from "cytoscape-dagre";
cytoscape.use(dagre);

function style_graph(cols_str) {
  const base_style =
    // Base node style
    [
      {
        selector: "node",
        style: {
          "background-color": "#f3f4f6", // gray-100
          "border-width": 2,
          "border-color": "#d1d5db", // gray-300
          label: "data(id)",
          "text-valign": "center",
          "text-halign": "center",
          "font-family": "monospace",
          // "font-size": "18px",
          "font-weight": "600",
          color: "#374151", // gray-700
          // padding: "4px",
          shape: "round-rectangle",
        },
      },
      // Clicked node highlight
      {
        selector: "node.selected",
        css: {
          "font-weight": "800",
          color: "red",
        },
      },
      // Edge styling
      {
        selector: "edge",
        style: {
          width: 2,
          "line-color": "#9ca3af", // gray-400
          "target-arrow-color": "#9ca3af", // gray-400
          "target-arrow-shape": "triangle",
          "curve-style": "bezier",
          "arrow-scale": 1.2,
        },
      },
    ];

  const cols = JSON.parse(cols_str);
  for (const nodeType in cols) {
    base_style.push({
      selector: `node[class = "${nodeType}"]`,
      css: {
        "border-color": cols[nodeType].border,
        "background-color": cols[nodeType].background,
      },
    });
  }
  return base_style;
}

export function draw_graph(graph, context, elements, cols, node) {
  const cy = cytoscape({
    container: graph, // container to render in
    elements: elements,
    style: style_graph(cols),
    layout: {
      name: "dagre",
    },
  });
  cy.on("tap", "node", function () {
    var n = this;
    context.pushEvent("node_clicked", { id: n.id() });
    cy.animate({
      center: {
        eles: n,
      },
      duration: 500, // duration in milliseconds for the animation
    });
  });
  cy.elements().removeClass("selected");
  cy.$(`#${node}`).addClass("selected");
  cy.animate({
    center: {
      eles: `#${node}`,
    },
    duration: 500, // duration in milliseconds for the animation
  });

  return cy;
}

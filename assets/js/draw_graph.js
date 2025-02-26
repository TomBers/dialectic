import cytoscape from "cytoscape";
import dagre from "cytoscape-dagre";
import { computePosition, autoUpdate, offset } from "@floating-ui/dom";

cytoscape.use(dagre);

function style_graph(cols_str) {
  const base_style = [
    {
      selector: "node",
      style: {
        "background-color": "#f3f4f6", // gray-100
        "border-width": 1,
        "border-color": "#d1d5db", // gray-300
        label: "data(id)",
        "text-valign": "center",
        "text-halign": "center",
        "font-family": "monospace",
        "font-weight": "400",
        color: "#374151", // gray-700
        padding: "4px",
        shape: "round-rectangle",
      },
    },
    // Clicked node highlight
    {
      selector: "node.selected",
      css: {
        "font-weight": "800",
        "border-color": "red",
        color: "red",
      },
    },
    // Edge styling
    {
      selector: "edge",
      style: {
        width: 2,
        "line-color": "#f3f4f6",
        "target-arrow-color": "#d1d5db", // gray-400
        "target-arrow-shape": "triangle",
        "curve-style": "bezier",
        "arrow-scale": 1.0,
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
        color: cols[nodeType].text,
      },
    });
    base_style.push({
      selector: `node[class = "${nodeType}"].selected`,
      css: {
        "font-weight": "800",
        "border-color": "red",
        color: "red",
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
      nodeSep: 20,
      edgeSep: 15,
      rankSep: 30,
    },
  });

  cy.minZoom(0.5);
  cy.maxZoom(10);

  // Node selection handling
  cy.on("tap", "node", function (event) {
    const n = this;
    const nodeId = n.id();

    // Send basic click event
    context.pushEvent("node_clicked", { id: nodeId });

    // Center on the node
    cy.animate({
      center: {
        eles: n,
      },
      zoom: 2,
      duration: 200,
    });

    setTimeout(() => {
      const node = event.target;

      // Get node position in screen coordinates
      const bb = node.renderedBoundingBox();
      const position = {
        x: (bb.x1 + bb.x2) / 2,
        y: bb.y2 + 10, // Position below the node
        width: bb.x2 - bb.x1,
        height: bb.y2 - bb.y1,
      };

      // Show menu with position information
      context.pushEvent("show_node_menu", {
        id: nodeId,
        position: position,
      });
    }, 300);
  });

  // Click elsewhere to hide menu
  cy.on("tap", function (event) {
    if (event.target === cy) {
      context.pushEvent("hide_node_menu", {});
    }
  });

  cy.elements().removeClass("selected");
  cy.$(`#${node}`).addClass("selected");
  cy.animate({
    center: {
      eles: `#${node}`,
    },
    zoom: 2,
    duration: 500,
  });

  return cy;
}

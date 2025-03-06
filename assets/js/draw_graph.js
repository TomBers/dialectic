import cytoscape from "cytoscape";
import dagre from "cytoscape-dagre";

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
        "border-color": "#D2042D",
        color: "#F88379",
      },
    },
    // Edge styling
    {
      selector: "edge",
      style: {
        width: 2,
        "line-color": "#f3f4f6",
        "curve-style": "bezier",
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
        "border-color": "#D2042D",
        color: "#F88379",
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

  cy.on("mouseover", "node", function (e) {
    this.animate({
      style: { width: this.width() * 1.1, height: this.height() * 1.1 },
      duration: 100,
    });
  });

  // Reset scale on mouseout
  cy.on("mouseout", "node", function (e) {
    this.animate({
      style: { width: this.width() / 1.1, height: this.height() / 1.1 },
      duration: 100,
    });
  });
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
      complete: function () {
        // This runs after animation completes
        const node = n;
        const bb = node.renderedBoundingBox();

        // Just send node position data, no tooltip positioning logic here
        context.pushEvent("show_node_menu", {
          id: nodeId,
          node_position: {
            center_x: (bb.x1 + bb.x2) / 2,
            center_y: (bb.y1 + bb.y2) / 2,
            width: bb.x2 - bb.x1,
            height: bb.y2 - bb.y1,
            bb_x1: bb.x1,
            bb_y1: bb.y1,
            bb_x2: bb.x2,
            bb_y2: bb.y2,
          },
        });
      },
    });
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

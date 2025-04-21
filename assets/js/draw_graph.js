import cytoscape from "cytoscape";
import dagre from "cytoscape-dagre";

cytoscape.use(dagre);

const selectState = {
  "font-weight": "800",
  "border-color": "white", // Dark green border
  color: "#FFFFFF", // White text
  "background-color": "#14e37c", // Bright mint green (very vibrant)
};

function style_graph(cols_str) {
  const base_style = [
    {
      selector: "node",
      style: {
        "background-color": "#f3f4f6", // gray-100
        "border-width": 2,
        "border-color": "#d1d5db", // gray-300
        label: function (ele) {
          const content = ele.data("content") || "";
          const truncatedContent =
            content.substring(0, 100) + (content.length > 100 ? "..." : "");
          return ele.data("id") + "\n\n" + truncatedContent;
        },
        "text-valign": "center",
        "text-halign": "center",
        "font-family": "InterVariable, sans-serif",
        "font-weight": "400",
        color: "#374151", // gray-700
        "text-wrap": "wrap",
        "text-max-width": "200px",
        shape: "roundrectangle", // Changed from round-diamond to roundrectangle
        width: "label", // Makes the node size fit the content
        height: "label",
        padding: "15px",
        "text-margin-y": 0, // Ensure text is centered vertically
      },
    },
    {
      selector: "node[compound]",
      style: {
        label: "data(id)", // ← use the id field
        "text-halign": "center",
        "text-valign": "top",
        "text-margin-y": 0,
        "font-size": 12,
        "font-weight": 600,
        "text-opacity": 1, // make sure it isn’t zero
        /* …border / background… */
      },
    },
    { selector: ".hidden", style: { display: "none" } },

    /* draw the parent differently when it’s collapsed --- */
    {
      selector: 'node[compound][collapsed = "true"]',
      style: {
        /* fixed badge size */
        width: 150, // px – tweak to taste
        height: 40,

        /* look & feel */
        shape: "roundrectangle",
        "background-opacity": 0.6,
        "background-color": "#E5E7EB", // slate‑200
        "border-width": 2,
        "border-color": "#4B5563",

        /* text centred inside the badge */
        label: "data(id)",
        "text-valign": "center",
        "text-halign": "center",
        "font-size": 12,
        "font-weight": 600,
        "text-wrap": "wrap",
        "text-max-width": 80,
      },
    },
    {
      selector: "node.preview",
      style: {
        "border-width": 6,
        opacity: 1,
      },
    },
    // Clicked node highlight
    {
      selector: "node.selected",
      css: selectState,
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
        // color: cols[nodeType].text,
      },
    });
    base_style.push({
      selector: `node[class = "${nodeType}"].selected`,
      css: selectState,
    });
  }
  return base_style;
}

export function draw_graph(graph, context, elements, cols, node) {
  const cy = cytoscape({
    container: graph, // container to render in
    elements: elements,
    style: style_graph(cols),
    boxSelectionEnabled: true, // ⬅️ lets users drag‑select
    autounselectify: false, // allow multi‑select
    wheelSensitivity: 0.2,
    layout: {
      name: "dagre",
      rankDir: "TB",
      nodeSep: 20,
      edgeSep: 15,
      rankSep: 30,
    },
  });

  let boxSelecting = false;
  let dragOrigin = null;

  cy.minZoom(0.5);
  cy.maxZoom(10);

  // Enhanced hover effect
  cy.on("mouseover", "node", function (e) {
    const node = this;

    // Apply highlight class instead of animating border directly
    node.addClass("node-hover");
    node.connectedEdges().addClass("edge-hover");
  });

  // Reset on mouseout
  cy.on("mouseout", "node", function (e) {
    const node = this;

    // Remove the highlight classes
    node.removeClass("node-hover");
    node.connectedEdges().removeClass("edge-hover");
  });

  cy.on("boxstart", (e) => {
    boxSelecting = true;
    dragOrigin = e.position; // remembers first corner
  });

  cy.on("mousemove", (e) => {
    if (!boxSelecting) return;

    const pos = e.position;
    const x1 = Math.min(dragOrigin.x, pos.x);
    const y1 = Math.min(dragOrigin.y, pos.y);
    const x2 = Math.max(dragOrigin.x, pos.x);
    const y2 = Math.max(dragOrigin.y, pos.y);

    cy.nodes().forEach((n) => {
      const bb = n.boundingBox({ includeLabels: false });
      const inside = bb.x1 >= x1 && bb.x2 <= x2 && bb.y1 >= y1 && bb.y2 <= y2;

      n.toggleClass("preview", inside);
    });
  });

  cy.on("boxend", (e) => {
    boxSelecting = false;
    /* remove the live preview colours */
    cy.nodes(".preview").removeClass("preview");

    requestAnimationFrame(() => {
      const selectedNodes = cy
        .$(":selected")
        .filter("node")
        .filter((n) => !n.isParent()); // ⬅️ ignore compound nodes;
      if (selectedNodes.length) {
        const ids = selectedNodes.map((n) => n.id());
        console.log(ids);
        context.pushEvent("nodes_box_selected", {
          ids: ids,
        });
      }
      selectedNodes.unselect();
    });
  });

  const selectColor = "#83f28f"; // Light green color

  cy.style()
    .selector(".node-hover")
    .css({
      "border-width": 3,
      // "border-color": selectColor,
      "z-index": 9999,
    })
    .selector(".edge-hover")
    .css({
      width: 3,
      "line-color": selectColor,
      "z-index": 9998,
    })
    .update();

  cy.on("tap", "node[compound]", (e) => toggle(e.target));

  // Node selection handling
  cy.on("tap", "node", function (event) {
    const n = this;
    /* exit early if it’s a parent / compound node */
    if (n.isParent()) return; // 👈  true when the node owns children

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

function collapse(parent) {
  if (parent.data("collapsed") === "true") return; // already collapsed

  const children = parent.children();
  const intEdges = children
    .connectedEdges()
    .filter(
      (edge) =>
        children.contains(edge.source()) && children.contains(edge.target()),
    );
  const extEdges = children.connectedEdges().subtract(intEdges);

  // stash what we’ll need for restore
  parent.data({
    collapsed: true,
    _children: children.map((n) => n.id()),
    _intEdges: intEdges.map((e) => e.id()),
    _extEdges: extEdges.map((e) => e.id()),
  });

  children.addClass("hidden");
  intEdges.addClass("hidden");

  // reroute edges that leave the group so they point to the parent
  extEdges.forEach((e) => {
    if (children.contains(e.source())) e.move({ source: parent.id() });
    if (children.contains(e.target())) e.move({ target: parent.id() });
  });
  parent.data("collapsed", "true");
}

function expand(parent) {
  if (parent.data("collapsed") !== "true") return;

  const cy = parent.cy();
  const children = cy.collection(
    parent.data("_children").map((id) => cy.getElementById(id)),
  );
  const intEdges = cy.collection(
    parent.data("_intEdges").map((id) => cy.getElementById(id)),
  );
  const extEdges = cy.collection(
    parent.data("_extEdges").map((id) => cy.getElementById(id)),
  );

  children.removeClass("hidden");
  intEdges.removeClass("hidden");

  // restore edge endpoints
  extEdges.forEach((e) => {
    const src = e.data("_origSource");
    const tgt = e.data("_origTarget");
    if (src) e.move({ source: src });
    if (tgt) e.move({ target: tgt });
  });

  parent.removeData("collapsed");
}

function toggle(parent) {
  parent.data("collapsed") ? expand(parent) : collapse(parent);
}

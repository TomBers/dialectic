import cytoscape from "cytoscape";
import dagre from "cytoscape-dagre";
import compoundDragAndDrop from "cytoscape-compound-drag-and-drop";

cytoscape.use(dagre);
cytoscape.use(compoundDragAndDrop);

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
    layout: {
      name: "dagre",
      rankDir: "TB",
      nodeSep: 20,
      edgeSep: 15,
      rankSep: 30,
    },
  });

  const dd_options = {
    grabbedNode: (node) => true, // filter function to specify which nodes are valid to grab and drop into other nodes
    dropTarget: (dropTarget, grabbedNode) => true, // filter function to specify which parent nodes are valid drop targets
    dropSibling: (dropSibling, grabbedNode) => true, // filter function to specify which orphan nodes are valid drop siblings
    newParentNode: (grabbedNode, dropSibling) => ({}), // specifies element json for parent nodes added by dropping an orphan node on another orphan (a drop sibling). You can chose to return the dropSibling in which case it becomes the parent node and will be preserved after all its children are removed.
    boundingBoxOptions: {
      // same as https://js.cytoscape.org/#eles.boundingBox, used when calculating if one node is dragged over another
      includeOverlays: false,
      includeLabels: true,
    },
    overThreshold: 10, // make dragging over a drop target easier by expanding the hit area by this amount on all sides
    outThreshold: 10, // make dragging out of a drop target a bit harder by expanding the hit area by this amount on all sides
  };

  cy.compoundDragAndDrop(dd_options);

  let boxSelecting = false;
  let dragOrigin = null;

  cy.minZoom(0.5);
  cy.maxZoom(10);

  /* remember where the drag started */
  cy.on("cdndgrab", (evt) => {
    evt.target.scratch("_oldParent", evt.target.data("parent") || null);
  });

  /* fire after the drop */
  cy.on("cdnddrop", (evt, dropTarget /*, dropSibling */) => {
    const ele = evt.target; // dragged node
    const oldParent = ele.scratch("_oldParent"); // what we saved
    ele.removeScratch("_oldParent");

    /* decide what the *new* parent should be */
    const targetIsGroup = dropTarget && dropTarget.isParent();
    const newParent = targetIsGroup ? dropTarget.id() : null;

    /* ——— ensure the data matches that decision ——— */
    if (!targetIsGroup) ele.move({ parent: null }); // detach from old group
    // (If targetIsGroup, CDnD has already moved it for us.)

    /* ——— skip no‑ops ——— */
    if (oldParent === newParent) return;

    /* ——— notify LiveView ——— */
    if (newParent) {
      context.pushEvent("node:join_group", {
        node: ele.id(),
        parent: newParent,
        old: oldParent,
      });
    } else {
      context.pushEvent("node:leave_group", {
        node: ele.id(),
        parent: oldParent,
      });
    }
  });

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

      /* 1 ▸ is the *centre* inside the rectangle? */
      const cx = (bb.x1 + bb.x2) / 2;
      const cyy = (bb.y1 + bb.y2) / 2;
      const centerInside = cx >= x1 && cx <= x2 && cyy >= y1 && cyy <= y2;

      /* 2 ▸ otherwise, does ≥ 40 % of the area overlap? */
      const ix1 = Math.max(bb.x1, x1);
      const iy1 = Math.max(bb.y1, y1);
      const ix2 = Math.min(bb.x2, x2);
      const iy2 = Math.min(bb.y2, y2);
      const intersectArea = Math.max(0, ix2 - ix1) * Math.max(0, iy2 - iy1);
      const nodeArea = (bb.x2 - bb.x1) * (bb.y2 - bb.y1);
      const enoughOverlap = intersectArea / nodeArea >= 0.4; // 40 %

      const inside = centerInside || enoughOverlap;

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

/* ───────────────────────── collapse ───────────────────────── */
function collapse(parent) {
  if (parent.data("collapsed") === "true") return; // already collapsed

  const children = parent.children();
  const intEdges = children
    .connectedEdges()
    .filter(
      (e) => children.contains(e.source()) && children.contains(e.target()),
    );
  const extEdges = children.connectedEdges().subtract(intEdges);

  /* 1 · save where each child sits so we can restore it */
  children.forEach((n) => {
    n.data("_prevPos", { x: n.position("x"), y: n.position("y") });
  });

  /* 2 · stash IDs for quick lookup */
  parent.data({
    collapsed: "true",
    _children: children.map((n) => n.id()),
    _intEdges: intEdges.map((e) => e.id()),
    _extEdges: extEdges.map((e) => e.id()),
  });

  /* 3 · hide kids + interior edges, reroute externals */
  children.addClass("hidden");
  intEdges.addClass("hidden");

  extEdges.forEach((e) => {
    if (!e.data("_origSource")) e.data("_origSource", e.data("source"));
    if (!e.data("_origTarget")) e.data("_origTarget", e.data("target"));

    if (children.contains(e.source())) e.move({ source: parent.id() });
    if (children.contains(e.target())) e.move({ target: parent.id() });
  });
}

/* ───────────────────────── expand ───────────────────────── */
function expand(parent) {
  if (parent.data("collapsed") !== "true") return;

  const cy = parent.cy();

  /* collections we stashed earlier */
  const children = cy.collection(
    parent.data("_children").map((id) => cy.getElementById(id)),
  );
  const intEdges = cy.collection(
    parent.data("_intEdges").map((id) => cy.getElementById(id)),
  );
  const extEdges = cy.collection(
    parent.data("_extEdges").map((id) => cy.getElementById(id)),
  );

  /* 1 · show kids + interior edges */
  children.removeClass("hidden");
  intEdges.removeClass("hidden");

  /* 2 · restore edge endpoints */
  extEdges.forEach((e) => {
    const src = e.data("_origSource");
    const tgt = e.data("_origTarget");
    if (src) e.move({ source: src });
    if (tgt) e.move({ target: tgt });
  });

  /* 3 · restore previous coordinates *or* run a mini‑layout */
  const anyPrev = children.some((n) => n.data("_prevPos"));
  if (anyPrev) {
    children.forEach((n) => {
      const p = n.data("_prevPos");
      if (p) n.position(p);
    });
  } else {
    cy.layout({
      name: "dagre",
      eles: children.union(intEdges),
      fit: false,
      padding: 20,
      animate: true,
      nodeSep: 20,
      edgeSep: 15,
      rankSep: 30,
    }).run();
  }

  /* 4 · clean up flags */
  parent.removeData("collapsed");
}

function toggle(parent) {
  parent.data("collapsed") ? expand(parent) : collapse(parent);
}

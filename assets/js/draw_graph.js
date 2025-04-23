import cytoscape from "cytoscape";
import dagre from "cytoscape-dagre";
import compoundDragAndDrop from "cytoscape-compound-drag-and-drop";
import { graphStyle } from "./graph_style";

cytoscape.use(dagre);
cytoscape.use(compoundDragAndDrop);

export function draw_graph(graph, context, elements, cols, node) {
  const cy = cytoscape({
    container: graph, // container to render in
    elements: elements,
    style: graphStyle(cols),
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
    grabbedNode: () => true,
    dropTarget: () => true,

    /* 1 ▸ never treat an orphan-on-orphan drop as a “make new group” */
    dropSibling: () => false,

    /* 2 ▸ and even if the plugin tries, give it nothing to add */
    newParentNode: () => null, // or just omit this line entirely

    /* other tweaks stay the same */
    boundingBoxOptions: { includeLabels: true, includeOverlays: false },
    overThreshold: 10,
    outThreshold: 10,
  };

  cy.compoundDragAndDrop(dd_options);

  let boxSelecting = false;
  let dragOrigin = null;

  cy.minZoom(0.1);
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
      zoom: 1.2,
      duration: 100,
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

import cytoscape from "cytoscape";
import dagre from "cytoscape-dagre";
import compoundDragAndDrop from "cytoscape-compound-drag-and-drop";
import { graphStyle } from "./graph_style";
import { layoutConfig } from "./layout_config.js";

cytoscape.use(dagre);
cytoscape.use(compoundDragAndDrop);

export function draw_graph(graph, context, elements, node) {
  // Check if we have a small graph (2 nodes)

  const edgeCount = elements.filter((ele) =>
    ele.data.hasOwnProperty("source"),
  ).length;

  const isSmallGraph = edgeCount === 1;

  // Create a modified layout config for small graphs
  const layoutOptions = {
    ...layoutConfig.baseLayout,
    // For small graphs, use a larger padding to prevent excessive zoom
    padding: isSmallGraph ? 200 : layoutConfig.baseLayout.padding,
  };

  const cy = cytoscape({
    container: graph, // container to render in
    elements: elements,
    style: graphStyle(),

    boxSelectionEnabled: true, // ⬅️ lets users drag‑select
    autounselectify: false, // allow multi‑select
    layout: layoutOptions,
  });

  // Figma-like navigation controls
  // - Scroll to pan (Shift for horizontal bias)
  // - Cmd/Ctrl+Scroll or trackpad pinch to zoom at cursor
  // - Hold Space and drag to pan; otherwise keep box selection
  const container = graph;

  // Disable Cytoscape's default wheel zoom so we fully control it
  cy.userZoomingEnabled(false);

  // Smooth, cursor-centered zoom
  const clamp = (val, min, max) => Math.max(min, Math.min(max, val));
  const wheelHandler = (e) => {
    // Zoom with Cmd/Ctrl (or trackpad pinch where ctrlKey is true)
    if (e.ctrlKey || e.metaKey) {
      e.preventDefault();
      const rect = container.getBoundingClientRect();
      const renderedPosition = {
        x: e.clientX - rect.left,
        y: e.clientY - rect.top,
      };

      const current = cy.zoom();
      // Exponential scale for smooth zooming
      const zoomFactor = Math.pow(1.0015, -e.deltaY);
      const next = clamp(current * zoomFactor, 0.05, 4);

      cy.zoom({ level: next, renderedPosition });
    } else {
      // Two-finger scroll / mouse wheel pans the canvas
      e.preventDefault();

      // If Shift is pressed and the gesture is mostly vertical,
      // bias the movement to horizontal (Figma-like)
      let dx = e.deltaX;
      let dy = e.deltaY;
      if (e.shiftKey && Math.abs(e.deltaX) < Math.abs(e.deltaY)) {
        dx = e.deltaY;
        dy = 0;
      }

      // Natural pan (scroll right -> content moves right)
      cy.panBy({ x: -dx, y: -dy });
    }
  };

  container.addEventListener("wheel", wheelHandler, { passive: false });

  // Space-drag to pan while preserving box selection otherwise
  let isSpaceDown = false;
  let isMouseDown = false;
  let lastPos = null;
  let prevBoxSelect = cy.boxSelectionEnabled();

  const keydownHandler = (e) => {
    // Don't hijack Space when typing in form fields or contenteditable areas
    const target = e.target;
    const tag = (target && target.tagName) || "";
    const isEditable =
      tag === "INPUT" ||
      tag === "TEXTAREA" ||
      (target &&
        (target.isContentEditable ||
          target.closest('[contenteditable="true"], [contenteditable=""]')));
    if (isEditable) return;

    if (e.code === "Space" && !isSpaceDown) {
      isSpaceDown = true;
      prevBoxSelect = cy.boxSelectionEnabled();
      cy.boxSelectionEnabled(false); // disable box to allow background drag to pan
      container.style.cursor = "grab";
      e.preventDefault();
    }
  };

  const keyupHandler = (e) => {
    if (e.code === "Space") {
      isSpaceDown = false;
      cy.boxSelectionEnabled(prevBoxSelect);
      container.style.cursor = "";
    }
  };

  const mousedownHandler = (e) => {
    if (isSpaceDown) {
      isMouseDown = true;
      lastPos = { x: e.clientX, y: e.clientY };
      container.style.cursor = "grabbing";
      e.preventDefault();
    }
  };

  const mousemoveHandler = (e) => {
    if (isSpaceDown && isMouseDown) {
      const dx = e.clientX - lastPos.x;
      const dy = e.clientY - lastPos.y;
      cy.panBy({ x: dx, y: dy });
      lastPos = { x: e.clientX, y: e.clientY };
      e.preventDefault();
    }
  };

  const mouseupHandler = () => {
    if (isMouseDown) {
      isMouseDown = false;
      container.style.cursor = isSpaceDown ? "grab" : "";
    }
  };

  document.addEventListener("keydown", keydownHandler);
  document.addEventListener("keyup", keyupHandler);
  container.addEventListener("mousedown", mousedownHandler);
  window.addEventListener("mousemove", mousemoveHandler);
  window.addEventListener("mouseup", mouseupHandler);

  const dd_options = layoutConfig.compoundDragDropOptions;

  cy.compoundDragAndDrop(dd_options);

  let boxSelecting = false;
  let dragOrigin = null;

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

    node.connectedEdges().addClass("edge-hover");
  });

  // Reset on mouseout
  cy.on("mouseout", "node", function (e) {
    const node = this;

    // Remove the highlight classes
    node.connectedEdges().removeClass("edge-hover");
  });

  cy.on("boxstart", (e) => {
    boxSelecting = true;
    dragOrigin = e.position; // remembers first corner
  });

  cy.on("boxend", (e) => {
    boxSelecting = false;

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
      zoom: 1.6,
      duration: 150,
      easing: "ease-in-out-quad",
    });
  });

  requestAnimationFrame(() => {
    cy.elements().removeClass("selected");
    let initial = null;
    if (node) {
      initial = cy.getElementById(node);
    }
    if (!initial || initial.length === 0) {
      initial = cy
        .nodes()
        .filter((n) => !n.isParent())
        .first();
    }
    if (initial && initial.length > 0) {
      initial.addClass("selected");
    }
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
      ...layoutConfig.expandLayout,
      eles: children.union(intEdges),
    }).run();
  }

  /* 4 · clean up flags */
  parent.removeData("collapsed");
}

function toggle(parent) {
  parent.data("collapsed") ? expand(parent) : collapse(parent);
}

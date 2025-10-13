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

    boxSelectionEnabled: false, // box selection disabled
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
      const zoomFactor = Math.pow(1.001, -e.deltaY);
      const next = clamp(current * zoomFactor, 0.1, 2.5);

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

    /* prevent leaving if old group would become empty (last child) */
    if (!targetIsGroup && oldParent) {
      const oldGroup = cy.getElementById(oldParent);
      if (oldGroup && oldGroup.length) {
        // Remaining children excluding the dragged node
        const remaining = oldGroup.children().filter((n) => !n.same(ele));
        if (remaining.length === 0) {
          // Revert: reattach to old group and abort
          ele.move({ parent: oldParent });
          return;
        }
      }
    }

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

  cy.on("boxstart", (_e) => {
    // box selection disabled
  });

  cy.on("boxend", (_e) => {
    // box selection disabled
  });

  // Disabled: prevent accidental collapse of compound groups via tap
  // Toggling is controlled exclusively by the Streams panel
  cy.on("tap", "node[compound]", function (e) {
    e.preventDefault();
    e.stopPropagation();
  });

  // Make compound/group nodes non-selectable so they are ignored by navigation selection
  try {
    cy.$("node[compound]").forEach((n) => {
      n.selectable(false);
      n.grabbable(false);
    });
  } catch (_e) {}

  cy.on("add", "node", function (e) {
    try {
      const n = e.target;
      if (n && n.isParent()) {
        n.selectable(false);
        n.grabbable(false);
      } else if (n && n.isNode && n.isNode()) {
        // Hide any node added under a collapsed group
        const anc = n.ancestors().filter((a) => a.isParent() && isCollapsed(a));
        if (anc && anc.length) {
          n.addClass("hidden");
        }
      }
    } catch (_e) {}
  });

  // Ensure edges respect collapsed groups when added
  cy.on("add", "edge", function (e) {
    try {
      const edge = e.target;
      const src = edge.source();
      const tgt = edge.target();

      // Find nearest collapsed ancestor for a node, if any
      const collapsedAncestor = (n) => {
        if (!n || !n.isNode || !n.isNode()) return null;
        const anc = n.ancestors().filter((a) => a.isParent() && isCollapsed(a));
        return anc.length ? anc[0] : null;
      };

      const srcGroup = collapsedAncestor(src);
      const tgtGroup = collapsedAncestor(tgt);

      // Hide interior edges if both ends are within the same collapsed group
      if (srcGroup && tgtGroup && srcGroup.id() === tgtGroup.id()) {
        edge.addClass("hidden");
        return;
      }

      // Reroute external edges to the collapsed parent on the inside end
      if (!edge.data("_origSource"))
        edge.data("_origSource", edge.data("source"));
      if (!edge.data("_origTarget"))
        edge.data("_origTarget", edge.data("target"));

      if (srcGroup) {
        edge.move({ source: srcGroup.id() });
      }
      if (tgtGroup) {
        edge.move({ target: tgtGroup.id() });
      }
    } catch (_e) {}
  });

  // Node selection handling
  cy.on("tap", "node", function (event) {
    const n = this;
    // exit early for compound/group nodes so they are not navigable
    if (n.isParent()) return;

    const nodeId = n.id();

    // Send basic click event
    context.pushEvent("node_clicked", { id: nodeId });

    // Center on the node within visible area (account for right-hand panel)
    const panel = document.getElementById("right-panel");
    const rect = container.getBoundingClientRect();
    const panelRect = panel ? panel.getBoundingClientRect() : null;
    const panelWidth = panelRect && panelRect.width > 10 ? panelRect.width : 0;
    const desiredX = Math.max(0, (rect.width - panelWidth) / 2);
    const desiredY = rect.height / 2;
    const pos = n.renderedPosition();
    const dx = desiredX - pos.x;
    const dy = desiredY - pos.y;
    cy.animate({
      panBy: { x: dx, y: dy },
      duration: 150,
      easing: "ease-in-out-quad",
    });
    enforceCollapsedState(cy);
  });

  requestAnimationFrame(() => {
    cy.elements().removeClass("selected");
    let initial = null;
    if (node) {
      initial = cy.getElementById(node);
    }
    if (!initial || (initial.length !== undefined && initial.length === 0)) {
      const candidates = cy.nodes().filter((n) => !n.isParent());
      initial = candidates.length ? candidates[0] : null;
    }
    if (initial) {
      initial.addClass("selected");
    }
  });

  // Streams: focus and toggle group handlers
  context.handleEvent("focus_group", ({ id }) => {
    try {
      const group = cy.getElementById(id);
      if (group && group.isParent()) {
        cy.animate({
          center: { eles: group },
          duration: 150,
          easing: "ease-in-out-quad",
        });
      }
    } catch (_e) {}
  });

  context.handleEvent("toggle_group", ({ id }) => {
    try {
      const group = cy.getElementById(id);
      if (group && group.isParent()) {
        toggle(group);
        // No viewport changes on toggle; keep current pan/zoom
      }
    } catch (_e) {}
  });

  // Enforce collapsed state for compound groups on init and common lifecycle hooks
  try {
    enforceCollapsedState(cy);
    cy.ready(() => enforceCollapsedState(cy));
    cy.on("layoutstop", () => enforceCollapsedState(cy));
    cy.on("render", () => enforceCollapsedState(cy));
  } catch (_e) {}

  // Expose collapsed-state enforcement for external callers
  cy.enforceCollapsedState = () => enforceCollapsedState(cy);

  return cy;
}

/* ───────────────────────── collapse ───────────────────────── */
function collapse(parent) {
  // always apply collapse; no early return

  let descendants = parent.descendants();
  if (!descendants || descendants.length === 0) {
    // Fallback to direct children if descendants are not yet computed
    descendants = parent.children();
  }
  const intEdges = descendants
    .connectedEdges()
    .filter(
      (e) =>
        descendants.contains(e.source()) && descendants.contains(e.target()),
    );
  const extEdges = descendants.connectedEdges().subtract(intEdges);

  /* 1 · save where each child sits so we can restore it */
  descendants.forEach((n) => {
    n.data("_prevPos", { x: n.position("x"), y: n.position("y") });
  });

  /* 2 · stash IDs for quick lookup */
  parent.data({
    collapsed: "true",
    _descendants: descendants.map((n) => n.id()),
    _intEdges: intEdges.map((e) => e.id()),
    _extEdges: extEdges.map((e) => e.id()),
  });

  /* 3 · hide kids + interior edges, reroute externals */
  descendants.addClass("hidden");
  const hiddenCount = descendants.filter((n) => n.hasClass("hidden")).length;

  // Final fallback: hide by selector if structural descendants are not present
  if (!descendants || descendants.length === 0) {
    const cy = parent.cy && parent.cy();
    if (cy) {
      const fallbackKids = cy.nodes(`[parent = "${parent.id()}"]`);
      fallbackKids.addClass("hidden");
    }
  }
  intEdges.addClass("hidden");
  const hiddenIntEdges = intEdges.filter((e) => e.hasClass("hidden")).length;

  let movedSrc = 0;
  let movedTgt = 0;
  extEdges.forEach((e) => {
    if (!e.data("_origSource")) e.data("_origSource", e.data("source"));
    if (!e.data("_origTarget")) e.data("_origTarget", e.data("target"));

    if (descendants.contains(e.source())) {
      e.move({ source: parent.id() });
      movedSrc++;
    }
    if (descendants.contains(e.target())) {
      e.move({ target: parent.id() });
      movedTgt++;
    }
  });
}

/* ───────────────────────── expand ───────────────────────── */
function expand(parent) {
  if (!isCollapsed(parent)) return;

  const cy = parent.cy();

  const descIds = parent.data("_descendants");
  const intIds = parent.data("_intEdges");
  const extIds = parent.data("_extEdges");

  if (!descIds || !intIds || !extIds) {
    // No stored collapse state in this instance; just clear the flag
    parent.removeData("collapsed");
    return;
  }

  /* collections we stashed earlier */
  const descendants = cy.collection(descIds.map((id) => cy.getElementById(id)));
  const intEdges = cy.collection(intIds.map((id) => cy.getElementById(id)));
  const extEdges = cy.collection(extIds.map((id) => cy.getElementById(id)));

  /* 1 · show kids + interior edges */
  descendants.removeClass("hidden");
  intEdges.removeClass("hidden");

  /* 2 · restore edge endpoints */
  extEdges.forEach((e) => {
    const src = e.data("_origSource");
    const tgt = e.data("_origTarget");
    if (src) e.move({ source: src });
    if (tgt) e.move({ target: tgt });
  });

  /* 3 · restore previous coordinates *or* run a mini‑layout */
  const anyPrev = descendants.some((n) => n.data("_prevPos"));
  if (anyPrev) {
    descendants.forEach((n) => {
      const p = n.data("_prevPos");
      if (p) n.position(p);
    });
  } else {
    cy.layout({
      ...layoutConfig.expandLayout,
      eles: descendants.union(intEdges),
    }).run();
  }

  /* 4 · clean up flags */
  parent.removeData("collapsed");
}

function toggle(parent) {
  parent.data("collapsed") ? expand(parent) : collapse(parent);
}

function isCollapsed(ele) {
  const v = ele && ele.data && ele.data("collapsed");
  return v === true || v === "true";
}

function enforceCollapsedState(cy) {
  try {
    cy.$("node[compound]")
      .filter((n) => isCollapsed(n))
      .forEach((n) => {
        collapse(n);
      });
  } catch (_e) {}
}

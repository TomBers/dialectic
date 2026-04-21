import cytoscape from "cytoscape";
import dagre from "cytoscape-dagre";
import compoundDragAndDrop from "cytoscape-compound-drag-and-drop";
import { graphStyle } from "./graph_style";
import { layoutConfig } from "./layout_config.js";
import {
  applyBadgeStyles,
  removeBadgeStyles,
  areBadgesEnabled,
  toggleTypeBadges,
} from "./node_type_badges.js";

cytoscape.use(dagre);
cytoscape.use(compoundDragAndDrop);

/* ─── Depth-based collapse configuration ─── */
export const DEPTH_COLLAPSE_DEFAULTS = {
  nodeThreshold: 10, // Auto-collapse when graph has more non-compound nodes than this
  initialMaxDepth: 1, // Show root (depth 0) + depth 1; collapse children of depth ≥ 1
};

export function draw_graph(
  graph,
  context,
  elements,
  node,
  viewMode = "spaced",
  graphId = null,
) {
  // Check if we have a small graph (2 nodes)

  const edgeCount = elements.filter((ele) =>
    ele.data.hasOwnProperty("source"),
  ).length;

  const isSmallGraph = edgeCount === 1;

  // Get graph direction from localStorage
  const graphDirection = localStorage.getItem("graph_direction") || "TB";

  // Select layout based on view mode
  const baseLayoutConfig =
    viewMode === "compact"
      ? layoutConfig.compactLayout
      : layoutConfig.baseLayout;

  // Create a modified layout config for small graphs
  const layoutOptions = {
    ...baseLayoutConfig,
    rankDir: graphDirection,
    // For small graphs, use a larger padding to prevent excessive zoom
    padding: isSmallGraph ? 200 : baseLayoutConfig.padding,
  };

  const cy = cytoscape({
    container: graph, // container to render in
    elements: elements,
    style: graphStyle(viewMode),

    boxSelectionEnabled: false, // box selection disabled
    autounselectify: false, // allow multi‑select
    // Layout is deferred — we apply depth-collapse first, then run layout manually
    minZoom: layoutConfig.zoomSettings.min || 0.05,
    maxZoom: layoutConfig.zoomSettings.max || 4.0,
  });

  // Store graphId on the cy instance so persistence helpers can find it
  cy._graphId = graphId || null;

  // ── Restore or auto-collapse large graphs before first layout ──
  // savedState is:
  //   null           → never saved (first visit) → auto-collapse if large
  //   {}  (empty)    → user explicitly expanded everything → honour that
  //   {id: true, …}  → specific collapse state → restore it
  let didCollapse = false;
  const savedState = _loadDepthStateFromStorage(graphId);

  if (savedState !== null && Object.keys(savedState).length > 0) {
    // Persisted collapse state exists — restore it
    computeNodeDepths(cy);
    Object.keys(savedState).forEach((id) => {
      const n = cy.getElementById(id);
      if (n && n.length > 0 && !n.isParent()) {
        n.data("_depthCollapsed", "true");
        n.addClass("node-collapsed");
      }
    });
    recomputeDepthVisibility(cy);
    didCollapse = true;
  } else if (savedState === null) {
    // No saved state at all (first visit) — auto-collapse if the graph is large
    didCollapse = autoCollapseGraph(cy);
    if (didCollapse) {
      _persistDepthState(cy);
    }
  }
  // else: savedState is {} → user previously expanded all, leave graph fully open

  // If the target node ended up hidden, expand its ancestors so it's visible
  if (didCollapse && node) {
    ensureDepthVisible(cy, node);
    _persistDepthState(cy);
  }

  // Figma-like navigation controls
  // - Scroll to pan (Shift for horizontal bias)
  // - Cmd/Ctrl+Scroll or trackpad pinch to zoom at cursor
  // - Hold Space and drag to pan; otherwise keep box selection
  const container = graph;

  // Track layout running to avoid pre-layout panning/centering flicker
  let layoutRunning = false;
  cy.on("layoutstart", () => {
    layoutRunning = true;
  });
  cy.on("layoutstop", () => {
    layoutRunning = false;
  });

  // Now run the initial layout (only visible nodes are positioned)
  // Placed after layoutRunning listeners so the initial layout is tracked
  cy.layout(layoutOptions).run();

  // Disable Cytoscape's default wheel zoom so we fully control it
  cy.userZoomingEnabled(false);

  // Hover styles are defined per-type in graph_style.js and applied via "node-hover" class

  // Toggle hover class, excluding compound (parent) nodes
  cy.on("mouseover", "node", (evt) => {
    const n = evt.target;
    if (n.isParent && n.isParent()) return;
    n.addClass("node-hover");
  });
  cy.on("mouseout", "node", (evt) => {
    const n = evt.target;
    n.removeClass("node-hover");
  });

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
      const sensitivity = layoutConfig.zoomSettings.sensitivity || 0.0025;
      const zoomFactor = Math.pow(1 + sensitivity, -e.deltaY);
      const next = clamp(
        current * zoomFactor,
        layoutConfig.zoomSettings.min || 0.05,
        layoutConfig.zoomSettings.max || 4.0,
      );

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

  // Touch handling for pinch-to-zoom
  let touchStartDist = 0;
  let touchStartZoom = 1;
  let touchCenter = { x: 0, y: 0 };
  let isPinching = false;

  const getTouchDist = (e) => {
    const dx = e.touches[0].clientX - e.touches[1].clientX;
    const dy = e.touches[0].clientY - e.touches[1].clientY;
    return Math.sqrt(dx * dx + dy * dy);
  };

  const getTouchCenter = (e) => {
    const rect = container.getBoundingClientRect();
    return {
      x: (e.touches[0].clientX + e.touches[1].clientX) / 2 - rect.left,
      y: (e.touches[0].clientY + e.touches[1].clientY) / 2 - rect.top,
    };
  };

  const touchStartHandler = (e) => {
    if (e.touches.length === 2) {
      e.preventDefault();
      touchStartDist = getTouchDist(e);
      touchStartZoom = cy.zoom();
      touchCenter = getTouchCenter(e);
      isPinching = true;
    }
  };

  const touchMoveHandler = (e) => {
    if (isPinching && e.touches.length === 2) {
      if (e.cancelable) e.preventDefault();

      const dist = getTouchDist(e);
      const rawScale = dist / touchStartDist;
      const sensitivity = layoutConfig.zoomSettings.pinchSensitivity || 1.0;
      const zoomFactor = Math.pow(rawScale, sensitivity);

      const next = clamp(
        touchStartZoom * zoomFactor,
        layoutConfig.zoomSettings.min || 0.05,
        layoutConfig.zoomSettings.max || 4.0,
      );

      cy.zoom({
        level: next,
        renderedPosition: touchCenter,
      });
    }
  };

  const touchEndHandler = (e) => {
    if (e.touches.length < 2) {
      isPinching = false;
    }
  };

  container.addEventListener("touchstart", touchStartHandler, {
    passive: false,
  });
  container.addEventListener("touchmove", touchMoveHandler, { passive: false });
  container.addEventListener("touchend", touchEndHandler);
  container.addEventListener("touchcancel", touchEndHandler);

  // Space-drag to pan while preserving box selection otherwise
  let isSpaceDown = false;
  let isMouseDown = false;
  let lastPos = null;
  let prevBoxSelect = cy.boxSelectionEnabled();

  const keydownHandler = (e) => {
    // Don't hijack keyboard shortcuts when typing in form fields or contenteditable areas
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

    // Arrow-key navigation — direction-aware
    if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(e.key)) {
      const selected = cy.$(".selected").filter((n) => !n.isParent());
      if (selected.length > 0) {
        const current = selected[0];
        const dir = localStorage.getItem("graph_direction") || "TB";

        // Map arrow keys to semantic actions based on graph orientation
        const actionMap = {
          TB: {
            ArrowUp: "parent",
            ArrowDown: "child",
            ArrowLeft: "prev",
            ArrowRight: "next",
          },
          BT: {
            ArrowUp: "child",
            ArrowDown: "parent",
            ArrowLeft: "prev",
            ArrowRight: "next",
          },
          LR: {
            ArrowLeft: "parent",
            ArrowRight: "child",
            ArrowUp: "prev",
            ArrowDown: "next",
          },
          RL: {
            ArrowLeft: "child",
            ArrowRight: "parent",
            ArrowUp: "prev",
            ArrowDown: "next",
          },
        };
        const action = (actionMap[dir] || actionMap.TB)[e.key];
        let target = null;

        if (action === "parent") {
          // Direct parents: sources of incoming edges
          const parents = current.incomers("node").filter((n) => !n.isParent());
          if (parents.length > 0) target = parents[0];
        } else if (action === "child") {
          // Direct children: targets of outgoing edges
          const children = current
            .outgoers("node")
            .filter((n) => !n.isParent());
          if (children.length > 0) target = children[0];
        } else {
          // prev / next sibling — sorted by visual position
          const parents = current.incomers("node").filter((n) => !n.isParent());
          if (parents.length > 0) {
            const siblings = parents[0]
              .outgoers("node")
              .filter(
                (n) =>
                  !n.isParent() &&
                  !n.hasClass("depth-hidden") &&
                  !n.hasClass("hidden"),
              );
            if (siblings.length > 1) {
              // Sort perpendicular to the flow axis
              const sorted = siblings.toArray().sort((a, b) => {
                if (dir === "TB" || dir === "BT") {
                  return a.position("x") - b.position("x");
                }
                return a.position("y") - b.position("y");
              });
              const idx = sorted.findIndex((n) => n.id() === current.id());
              if (action === "prev" && idx > 0) {
                target = sorted[idx - 1];
              } else if (action === "next" && idx < sorted.length - 1) {
                target = sorted[idx + 1];
              }
            }
          }
        }

        if (target) {
          context.pushEvent("node_clicked", { id: target.id() });

          // Update selection visuals immediately for responsiveness
          cy.elements().removeClass("selected");
          target.addClass("selected");

          // Ensure the target is visible (expand depth/group if needed)
          if (
            target.hasClass("depth-hidden") &&
            typeof cy.ensureDepthVisible === "function"
          ) {
            cy.ensureDepthVisible(target.id());
          }

          // Minimal pan to keep target in view
          requestAnimationFrame(() => {
            const zoom = cy.zoom();
            const pan = cy.pan();
            const bb = target.boundingBox();
            const pad = 12;
            const rect = container.getBoundingClientRect();

            const rbbLeft = bb.x1 * zoom + pan.x - pad;
            const rbbRight = bb.x2 * zoom + pan.x + pad;
            const rbbTop = bb.y1 * zoom + pan.y - pad;
            const rbbBottom = bb.y2 * zoom + pan.y + pad;

            const margin = 16;
            let dx = 0;
            let dy = 0;

            if (rbbLeft < margin) dx = margin - rbbLeft;
            else if (rbbRight > rect.width - margin)
              dx = rect.width - margin - rbbRight;
            if (rbbTop < margin) dy = margin - rbbTop;
            else if (rbbBottom > rect.height - margin)
              dy = rect.height - margin - rbbBottom;

            if (dx !== 0 || dy !== 0) {
              cy.animate({
                pan: { x: pan.x + dx, y: pan.y + dy },
                duration: 150,
                easing: "ease-in-out-quad",
              });
            }
          });

          enforceCollapsedState(cy);
        }
        e.preventDefault();
      }
    }

    // E = expand selected node's children, C = collapse
    if (e.key === "e" || e.key === "E") {
      const selected = cy.$(".selected").filter((n) => !n.isParent());
      if (selected.length > 0 && isDepthCollapsed(selected[0])) {
        expandNodeChildren(cy, selected[0]);
        e.preventDefault();
      }
    }
    if (e.key === "c" || e.key === "C") {
      const selected = cy.$(".selected").filter((n) => !n.isParent());
      if (selected.length > 0) {
        const children = selected[0]
          .outgoers("node")
          .filter((n) => !n.isParent());
        if (children.length > 0) {
          collapseNodeChildren(cy, selected[0]);
          e.preventDefault();
        }
      }
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

      // Skip reroute during bulk JSON reloads when a scratch flag is set
      const cyInst = edge.cy && edge.cy();
      if (cyInst && cyInst.scratch && cyInst.scratch("_bulkReload")) {
        return;
      }

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
  let lastTapTime = 0;
  let lastTapNode = null;

  cy.on("tap", "node", function (event) {
    const n = this;
    // exit early for compound/group nodes so they are not navigable
    if (n.isParent()) return;

    const nodeId = n.id();

    // Double-tap detection (within 300ms)
    const now = Date.now();
    const timeDiff = now - lastTapTime;

    if (timeDiff < 300 && lastTapNode === nodeId) {
      // Double-tap detected - open reader panel
      setTimeout(() => {
        const layout = document.getElementById("graph-layout");
        if (layout) {
          layout.dispatchEvent(
            new CustomEvent("toggle-side-drawer", {
              detail: { force: "open" },
            }),
          );
        }
      }, 200);
      lastTapTime = 0;
      lastTapNode = null;
      return;
    }

    lastTapTime = now;
    lastTapNode = nodeId;

    // Send basic click event
    context.pushEvent("node_clicked", { id: nodeId });

    // Update selection visuals immediately for responsiveness (same as keyboard nav)
    cy.elements().removeClass("selected");
    n.addClass("selected");

    // Ensure node is within visible bounds using model-space + zoom/pan; pan minimally if off-screen
    const rect = container.getBoundingClientRect();
    const panels = ["right-panel", "highlights-drawer"];
    let overlap = 0;

    panels.forEach((id) => {
      const panel = document.getElementById(id);
      const pr = panel ? panel.getBoundingClientRect() : null;
      if (pr) {
        const currentOverlap = Math.min(
          rect.width,
          Math.max(0, rect.right - pr.left),
        );
        if (currentOverlap > overlap) overlap = currentOverlap;
      }
    });

    // Visible region inside the container
    const margin = 16; // outer margin from container edges
    const deadzone = 8; // hysteresis to avoid bounce
    const pad = 12; // ensure node box + padding is visible

    const visLeft = margin;
    const visTop = margin;
    const visRight = Math.max(margin, rect.width - overlap - margin);
    const visBottom = Math.max(margin, rect.height - margin);

    // Deadzone-shrunk inner box to prevent small back-and-forth nudges
    const okLeft = visLeft + deadzone;
    const okTop = visTop + deadzone;
    const okRight = visRight - deadzone;
    const okBottom = visBottom - deadzone;

    const zoom = cy.zoom();
    const pan = cy.pan();

    // Node bounding box in model space
    const bb = n.boundingBox();
    // Convert to rendered coords and add padding
    const rbbLeft = bb.x1 * zoom + pan.x - pad;
    const rbbRight = bb.x2 * zoom + pan.x + pad;
    const rbbTop = bb.y1 * zoom + pan.y - pad;
    const rbbBottom = bb.y2 * zoom + pan.y + pad;

    // Minimal pan to bring padded box fully inside ok-bounds
    let dx = 0;
    let dy = 0;

    if (rbbLeft < okLeft) dx = okLeft - rbbLeft;
    else if (rbbRight > okRight) dx = okRight - rbbRight;

    if (rbbTop < okTop) dy = okTop - rbbTop;
    else if (rbbBottom > okBottom) dy = okBottom - rbbBottom;

    if (!layoutRunning && (dx !== 0 || dy !== 0)) {
      cy.animate({
        pan: { x: pan.x + dx, y: pan.y + dy },
        duration: 150,
        easing: "ease-in-out-quad",
      });
    }
    // If a layout is running, skip the pre-layout nudge to avoid flicker.
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
        // Relayout after toggle to prevent overlapping nodes
        _relayoutAfterDepthChange(cy);
      }
    } catch (_e) {}
  });

  // Force a full relayout (e.g., after creating a new group)
  // Delay ensures any in-flight layout from updated() completes first
  context.handleEvent("reflow_layout", () => {
    setTimeout(() => {
      try {
        _relayoutAfterDepthChange(cy);
        // After layout, spread out any overlapping compound nodes
        setTimeout(() => {
          _spreadOverlappingCompoundNodes(cy);
        }, 300);
      } catch (_e) {}
    }, 350);
  });

  // Depth-collapse events from LiveView
  context.handleEvent("expand_node", ({ id }) => {
    try {
      const n = cy.getElementById(id);
      if (n && n.length > 0 && !n.isParent()) {
        expandNodeChildren(cy, n);
      }
    } catch (_e) {}
  });

  context.handleEvent("collapse_node", ({ id }) => {
    try {
      const n = cy.getElementById(id);
      if (n && n.length > 0 && !n.isParent()) {
        collapseNodeChildren(cy, n);
      }
    } catch (_e) {}
  });

  context.handleEvent("expand_all_depth", () => {
    try {
      expandAllDepth(cy);
    } catch (_e) {}
  });

  context.handleEvent("collapse_all_depth", (payload) => {
    try {
      const maxDepth =
        payload && payload.max_depth != null
          ? payload.max_depth
          : DEPTH_COLLAPSE_DEFAULTS.initialMaxDepth;
      collapseAllDepth(cy, maxDepth);
    } catch (_e) {}
  });

  // Enforce collapsed state for compound groups on init and common lifecycle hooks
  try {
    enforceCollapsedState(cy);
    cy.ready(() => enforceCollapsedState(cy));
    // Removed: collapse enforcement on layoutstop to avoid unexpected edge reroutes
    // Removed: collapse enforcement on render to avoid unexpected edge reroutes
  } catch (_e) {}

  // Expose collapsed-state enforcement for external callers
  cy.enforceCollapsedState = () => enforceCollapsedState(cy);

  // Expose depth-collapse helpers on the cy instance for graph_hook.js
  cy.saveDepthCollapseState = () => saveDepthCollapseState(cy);
  cy.restoreDepthCollapseState = (state) =>
    restoreDepthCollapseState(cy, state);
  cy.recomputeDepthVisibility = () => recomputeDepthVisibility(cy);
  cy.autoCollapseGraph = (cfg) => autoCollapseGraph(cy, cfg);
  cy.ensureDepthVisible = (id) => ensureDepthVisible(cy, id);
  cy.ensureGroupVisible = (id) => ensureGroupVisible(cy, id);
  cy.expandNodeChildren = (n) =>
    expandNodeChildren(cy, typeof n === "string" ? cy.getElementById(n) : n);
  cy.collapseNodeChildren = (n) =>
    collapseNodeChildren(cy, typeof n === "string" ? cy.getElementById(n) : n);

  // ── Node action badges (expand/collapse and future corner actions) ──
  _injectNodeActionBadgeStyles();

  // Initialize cache for bottom-menu overlap to avoid forced layout on every render
  cy._bottomMenuOverlapCache = { bottomOverlap: 0, containerHeight: 0 };

  // Rebuild action badges after every layout completes (covers init + expand/collapse relayouts)
  cy.on("layoutstop", () => {
    _rebuildNodeActionBadges(cy, container);
  });

  // Keep badge positions in sync with pan / zoom / animation (throttled to 1 rAF)
  let _nodeActionBadgeRafPending = false;
  cy.on("render", () => {
    if (!_nodeActionBadgeRafPending) {
      _nodeActionBadgeRafPending = true;
      requestAnimationFrame(() => {
        _nodeActionBadgeRafPending = false;
        _updateNodeActionBadgePositions(cy);
      });
    }
  });

  // Set up ResizeObserver to update bottom-menu overlap cache when layout changes
  if (typeof ResizeObserver !== "undefined") {
    const bottomMenu = document.getElementById("bottom-menu");
    const resizeObserver = new ResizeObserver(() => {
      _computeBottomMenuOverlap(cy);
    });
    if (container) resizeObserver.observe(container);
    if (bottomMenu) resizeObserver.observe(bottomMenu);
    cy._bottomMenuResizeObserver = resizeObserver;
  } else {
    // Fallback for browsers without ResizeObserver
    window.addEventListener("resize", () => _computeBottomMenuOverlap(cy));
  }

  // Compute initial bottom-menu overlap
  _computeBottomMenuOverlap(cy);

  // Build initial overlays — the first layoutstop may fire before the listener
  // above is registered (if dagre finishes synchronously), so schedule a fallback.
  requestAnimationFrame(() => {
    _rebuildNodeActionBadges(cy, container);
  });

  // Apply type badge styles using native Cytoscape background-image
  if (areBadgesEnabled()) {
    applyBadgeStyles(cy);
  }

  // Expose cleanup so graph_hook.js can remove the node action badge overlay on destroy
  cy.cleanupNodeActionBadges = () => {
    try {
      if (cy._nodeActionBadgeOverlay && cy._nodeActionBadgeOverlay.parentNode) {
        cy._nodeActionBadgeOverlay.parentNode.removeChild(
          cy._nodeActionBadgeOverlay,
        );
      }
      cy._nodeActionBadgeOverlay = null;
      cy._nodeActionBadges = null;
      if (cy._bottomMenuResizeObserver) {
        cy._bottomMenuResizeObserver.disconnect();
        cy._bottomMenuResizeObserver = null;
      }
    } catch (_e) {}
  };

  // ── Type badge style controls ──
  cy.cleanupTypeBadges = () => {
    try {
      removeBadgeStyles(cy);
    } catch (_e) {}
  };

  cy.toggleTypeBadges = (enabled) => {
    toggleTypeBadges(cy, enabled);
  };

  cy.areBadgesEnabled = areBadgesEnabled;

  cy.rebuildTypeBadges = () => {
    if (areBadgesEnabled()) {
      applyBadgeStyles(cy);
    }
  };

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

/* ═══════════════════════════════════════════════════════════
   Depth-based progressive disclosure (DAG collapse/expand)
   ═══════════════════════════════════════════════════════════ */

/**
 * BFS from root nodes to assign a `_depth` value to every non-compound node.
 * Roots (no incoming edges from non-compound nodes) get depth 0.
 */
function computeNodeDepths(cy) {
  const nodes = cy.nodes().filter((n) => !n.isParent());
  const roots = nodes.filter(
    (n) => n.incomers("node").filter((m) => !m.isParent()).length === 0,
  );

  // Initialise all depths to Infinity (unreachable)
  nodes.forEach((n) => n.data("_depth", Infinity));

  const queue = [];
  roots.forEach((n) => {
    n.data("_depth", 0);
    queue.push(n);
  });

  let qi = 0;
  while (qi < queue.length) {
    const current = queue[qi++];
    const currentDepth = current.data("_depth");
    const children = current.outgoers("node").filter((n) => !n.isParent());
    children.forEach((child) => {
      const newDepth = currentDepth + 1;
      if (newDepth < child.data("_depth")) {
        child.data("_depth", newDepth);
        queue.push(child);
      }
    });
  }
}

/** Check whether a node's children are depth-collapsed */
function isDepthCollapsed(node) {
  if (!node || node.length === 0) return false;
  const v = node.data("_depthCollapsed");
  return v === true || v === "true";
}

/**
 * Recompute visibility of every node/edge based on the current
 * `_depthCollapsed` flags.  Visible = reachable from a root via a chain
 * of non-collapsed ancestors.
 */
function recomputeDepthVisibility(cy) {
  const nodes = cy.nodes().filter((n) => !n.isParent());
  const roots = nodes.filter(
    (n) => n.incomers("node").filter((m) => !m.isParent()).length === 0,
  );

  // Start: hide everything, then reveal reachable nodes
  nodes.addClass("depth-hidden");
  roots.forEach((n) => n.removeClass("depth-hidden"));

  const queue = [...roots.toArray()];
  const visited = new Set(roots.toArray().map((n) => n.id()));

  let qi = 0;
  while (qi < queue.length) {
    const current = queue[qi++];
    if (isDepthCollapsed(current)) continue; // don't reveal children

    const children = current.outgoers("node").filter((n) => !n.isParent());
    children.forEach((child) => {
      child.removeClass("depth-hidden");
      if (!visited.has(child.id())) {
        visited.add(child.id());
        queue.push(child);
      }
    });
  }

  // Edges: hide if either endpoint is depth-hidden
  cy.edges().forEach((edge) => {
    const src = edge.source();
    const tgt = edge.target();
    if (src.hasClass("depth-hidden") || tgt.hasClass("depth-hidden")) {
      edge.addClass("depth-hidden");
    } else {
      edge.removeClass("depth-hidden");
    }
  });

  // Update badge counts on visible nodes
  nodes
    .filter((n) => !n.hasClass("depth-hidden"))
    .forEach((n) => {
      const allChildren = n.outgoers("node").filter((m) => !m.isParent());
      const hiddenChildren = allChildren.filter((c) =>
        c.hasClass("depth-hidden"),
      );
      n.data("_hiddenChildCount", hiddenChildren.length);
    });

  // Clear badge on hidden nodes so stale counts don't persist
  nodes
    .filter((n) => n.hasClass("depth-hidden"))
    .forEach((n) => {
      n.data("_hiddenChildCount", 0);
    });
}

/**
 * Collapse a node's children: mark it as depth-collapsed, recompute
 * visibility, and re-run the layout so visible nodes reposition cleanly.
 */
function collapseNodeChildren(cy, node) {
  if (!node || node.length === 0 || node.isParent()) return;
  const children = node.outgoers("node").filter((n) => !n.isParent());
  if (children.length === 0) return; // leaf node, nothing to collapse

  node.data("_depthCollapsed", "true");
  node.addClass("node-collapsed");
  recomputeDepthVisibility(cy);
  _persistDepthState(cy);
  _relayoutAfterDepthChange(cy);
}

/**
 * Expand a node's direct children: clear the collapsed flag, recompute
 * visibility, and re-run the layout.
 */
function expandNodeChildren(cy, node) {
  if (!node || node.length === 0 || node.isParent()) return;
  if (!isDepthCollapsed(node)) return;

  node.removeData("_depthCollapsed");
  node.removeClass("node-collapsed");
  recomputeDepthVisibility(cy);
  _persistDepthState(cy);
  _relayoutAfterDepthChange(cy);
}

/** Expand every depth-collapsed node in the graph */
function expandAllDepth(cy) {
  cy.nodes()
    .filter((n) => !n.isParent() && isDepthCollapsed(n))
    .forEach((n) => {
      n.removeData("_depthCollapsed");
      n.removeClass("node-collapsed");
    });
  recomputeDepthVisibility(cy);
  _persistDepthState(cy);
  _relayoutAfterDepthChange(cy);
}

/** Collapse all nodes at or beyond `maxDepth` that have children */
function collapseAllDepth(cy, maxDepth) {
  computeNodeDepths(cy);
  const nodes = cy.nodes().filter((n) => !n.isParent());
  nodes.forEach((n) => {
    const depth = n.data("_depth");
    const children = n.outgoers("node").filter((m) => !m.isParent());
    if (depth >= maxDepth && children.length > 0) {
      n.data("_depthCollapsed", "true");
      n.addClass("node-collapsed");
    }
  });
  recomputeDepthVisibility(cy);
  _persistDepthState(cy);
  _relayoutAfterDepthChange(cy);
}

/**
 * Auto-collapse a graph if it exceeds the node threshold.
 * Returns `true` if collapse was applied.
 */
function autoCollapseGraph(cy, config) {
  const cfg = { ...DEPTH_COLLAPSE_DEFAULTS, ...(config || {}) };
  const nodes = cy.nodes().filter((n) => !n.isParent());

  if (nodes.length <= cfg.nodeThreshold) return false;

  computeNodeDepths(cy);

  // Collapse every node at depth ≥ initialMaxDepth that has children
  nodes.forEach((n) => {
    const depth = n.data("_depth");
    const children = n.outgoers("node").filter((m) => !m.isParent());
    if (depth >= cfg.initialMaxDepth && children.length > 0) {
      n.data("_depthCollapsed", "true");
      n.addClass("node-collapsed");
    }
  });

  recomputeDepthVisibility(cy);
  return true;
}

/**
 * Ensure a specific node is visible by expanding any collapsed ancestors
 * along the path from a root to it.
 */
/**
 * If the target node is inside a collapsed compound group (.hidden),
 * expand that group so the node becomes visible on the canvas.
 */
function ensureGroupVisible(cy, nodeId) {
  const node = cy.getElementById(nodeId);
  if (!node || node.length === 0 || !node.hasClass("hidden")) return false;

  // Walk up compound parents until we find the collapsed one
  let expanded = false;
  let current = node;
  while (current && current.length > 0) {
    const parent = current.parent();
    if (parent && parent.length > 0 && isCollapsed(parent)) {
      expand(parent);
      expanded = true;
      // After expanding, the node should be visible — but if it's still
      // hidden (nested collapse), keep walking up.
      if (!node.hasClass("hidden")) break;
    }
    current = parent;
  }

  // Return whether we expanded anything so the caller can trigger a reflow
  return expanded;
}

function ensureDepthVisible(cy, nodeId) {
  const node = cy.getElementById(nodeId);
  if (!node || node.length === 0 || !node.hasClass("depth-hidden")) return;

  // Collect all ancestors via upward BFS
  const ancestors = new Set();
  const queue = [node];
  let qi = 0;
  while (qi < queue.length) {
    const current = queue[qi++];
    const parents = current.incomers("node").filter((n) => !n.isParent());
    parents.forEach((p) => {
      if (!ancestors.has(p.id())) {
        ancestors.add(p.id());
        queue.push(p);
      }
    });
  }

  // Expand any collapsed ancestors along the path
  let changed = false;
  ancestors.forEach((id) => {
    const anc = cy.getElementById(id);
    if (anc && anc.length > 0 && isDepthCollapsed(anc)) {
      anc.removeData("_depthCollapsed");
      anc.removeClass("node-collapsed");
      changed = true;
    }
  });

  if (changed) {
    recomputeDepthVisibility(cy);
    _persistDepthState(cy);
  }
}

/** Save current depth-collapse flags (node id → true) for persistence across cy.json() reloads */
function saveDepthCollapseState(cy) {
  const state = {};
  try {
    cy.nodes()
      .filter((n) => !n.isParent())
      .forEach((n) => {
        if (isDepthCollapsed(n)) {
          state[n.id()] = true;
        }
      });
  } catch (_e) {}
  return state;
}

/** Restore depth-collapse flags after a cy.json() reload and recompute visibility */
function restoreDepthCollapseState(cy, state) {
  if (!state || Object.keys(state).length === 0) return;

  computeNodeDepths(cy);

  Object.keys(state).forEach((id) => {
    const node = cy.getElementById(id);
    if (node && node.length > 0 && !node.isParent()) {
      node.data("_depthCollapsed", "true");
      node.addClass("node-collapsed");
    }
  });

  recomputeDepthVisibility(cy);
}

/* ─── localStorage persistence for depth-collapse state ─── */

/** Build the localStorage key for a given graph */
function _depthStorageKey(graphId) {
  return graphId ? `dialectic_depth_collapse_${graphId}` : null;
}

/** Persist the current collapse flags to localStorage.
 *  An empty object ({}) is stored intentionally — it means
 *  "user explicitly expanded everything" and must be distinguished
 *  from a missing key (null) which means "first visit".
 */
function _persistDepthState(cy) {
  const key = _depthStorageKey(cy._graphId);
  if (!key) return;
  try {
    const state = saveDepthCollapseState(cy);
    localStorage.setItem(key, JSON.stringify(state));
  } catch (_e) {}
}

/** Load saved collapse flags from localStorage (returns object or null) */
function _loadDepthStateFromStorage(graphId) {
  const key = _depthStorageKey(graphId);
  if (!key) return null;
  try {
    const raw = localStorage.getItem(key);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
      return parsed;
    }
  } catch (_e) {}
  return null;
}

/**
 * Spread out overlapping compound (group) nodes by shifting them apart.
 * This is useful after creating new groups that might overlap existing ones.
 */
function _spreadOverlappingCompoundNodes(cy) {
  try {
    const compoundNodes = cy
      .nodes()
      .filter((n) => n.isParent() && !n.hasClass("hidden"));
    if (compoundNodes.length < 2) return;

    const padding = 50; // Minimum spacing between compound nodes
    const nodeData = [];

    // Collect bounding boxes for all compound nodes
    compoundNodes.forEach((node) => {
      const bb = node.boundingBox({
        includeLabels: false,
        includeOverlays: false,
      });
      nodeData.push({
        node,
        bb,
        cx: (bb.x1 + bb.x2) / 2,
        cy: (bb.y1 + bb.y2) / 2,
        width: bb.x2 - bb.x1,
        height: bb.y2 - bb.y1,
      });
    });

    // Check for overlaps and spread nodes apart
    let hasOverlap = true;
    let iterations = 0;
    const maxIterations = 10;

    while (hasOverlap && iterations < maxIterations) {
      hasOverlap = false;
      iterations++;

      for (let i = 0; i < nodeData.length; i++) {
        for (let j = i + 1; j < nodeData.length; j++) {
          const a = nodeData[i];
          const b = nodeData[j];

          // Check if bounding boxes overlap (with padding)
          const overlapX = Math.max(
            0,
            Math.min(a.bb.x2, b.bb.x2) - Math.max(a.bb.x1, b.bb.x1) + padding,
          );
          const overlapY = Math.max(
            0,
            Math.min(a.bb.y2, b.bb.y2) - Math.max(a.bb.y1, b.bb.y1) + padding,
          );

          if (overlapX > 0 && overlapY > 0) {
            hasOverlap = true;

            // Calculate direction to push nodes apart
            const dx = b.cx - a.cx;
            const dy = b.cy - a.cy;
            const dist = Math.sqrt(dx * dx + dy * dy) || 1;

            // Push nodes apart based on overlap
            const pushX = (dx / dist) * (overlapX / 2 + padding);
            const pushY = (dy / dist) * (overlapY / 2 + padding);

            // Move node b and its children
            const bChildren = b.node.descendants().union(b.node);
            bChildren.forEach((child) => {
              child.position({
                x: child.position("x") + pushX,
                y: child.position("y") + pushY,
              });
            });

            // Update bounding box data for b
            const newBb = b.node.boundingBox({
              includeLabels: false,
              includeOverlays: false,
            });
            b.bb = newBb;
            b.cx = (newBb.x1 + newBb.x2) / 2;
            b.cy = (newBb.y1 + newBb.y2) / 2;
          }
        }
      }
    }
  } catch (_e) {}
}

/**
 * Internal helper: re-run the dagre layout after a depth visibility change
 * so that visible nodes reposition into a clean arrangement.
 */
function _relayoutAfterDepthChange(cy) {
  try {
    const viewMode = localStorage.getItem("graph_view_mode") || "spaced";
    const graphDirection = localStorage.getItem("graph_direction") || "TB";
    const baseLayout =
      viewMode === "compact"
        ? layoutConfig.compactLayout
        : layoutConfig.baseLayout;

    cy.layout({
      ...baseLayout,
      rankDir: graphDirection,
      animate: true,
      animationDuration: 250,
    }).run();
  } catch (_e) {}
}

/* ═══════════════════════════════════════════════════════════
   Node action badges (DOM overlays anchored to node corners)
   ═══════════════════════════════════════════════════════════ */

function _snapOverlayPixel(value) {
  const dpr = window.devicePixelRatio || 1;
  return Math.round(value * dpr) / dpr;
}

function _nodeActionBadgeMetrics(zoom) {
  const scale = Math.max(0.55, Math.min(1, Math.pow(zoom || 1, 0.22)));
  const height = _snapOverlayPixel(20 * scale);
  const fadeStartZoom = 0.22;
  const hideBelowZoom = 0.12;
  const opacity =
    zoom <= hideBelowZoom
      ? 0
      : zoom >= fadeStartZoom
        ? 1
        : (zoom - hideBelowZoom) / (fadeStartZoom - hideBelowZoom);
  const clampedOpacity = Math.max(0, Math.min(1, opacity));

  return {
    height,
    minWidth: height,
    paddingX: _snapOverlayPixel(Math.max(3, 5 * scale)),
    borderRadius: _snapOverlayPixel(height / 2),
    borderWidth: _snapOverlayPixel(Math.max(1, 1.5 * scale)),
    fontSize: _snapOverlayPixel(Math.max(8, 10 * scale)),
    outsideGap: _snapOverlayPixel(Math.max(0.5, 1.25 * scale)),
    visible: zoom > hideBelowZoom,
    opacity: clampedOpacity,
  };
}

/** Inject the CSS for node action badges once into <head> */
function _injectNodeActionBadgeStyles() {
  if (document.getElementById("node-action-badge-styles")) return;
  const s = document.createElement("style");
  s.id = "node-action-badge-styles";
  s.textContent = `
.node-action-badge-overlay {
  position: absolute;
  top: 0; left: 0;
  width: 100%; height: 100%;
  pointer-events: none;
  z-index: 10;
  overflow: hidden;
}
.node-action-badge {
  pointer-events: auto;
  position: absolute;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 20px;
  height: 20px;
  padding: 0 5px;
  border-radius: 10px;
  background: #ffffff;
  border: 1.5px solid #cbd5e1;
  color: #475569;
  font-size: 10px;
  font-weight: 600;
  font-family: ui-sans-serif, system-ui, -apple-system, sans-serif;
  cursor: pointer;
  transition: background 0.15s ease, border-color 0.15s ease,
              box-shadow 0.15s ease, transform 0.1s ease;
  box-shadow: 0 1px 2px rgba(0,0,0,0.08);
  user-select: none;
  line-height: 1;
  white-space: nowrap;
}
.node-action-badge:hover {
  background: #f1f5f9;
  border-color: #94a3b8;
  box-shadow: 0 2px 4px rgba(0,0,0,0.12);
}
.node-action-badge:active {
  background: #e2e8f0;
  filter: brightness(0.98);
}
/* collapsed → warm amber "+N" pill — stands out from all node types */
.node-action-badge.depth-collapsed-btn {
  background: #fef3c7;
  border-color: #f59e0b;
  color: #92400e;
  box-shadow: 0 0 6px rgba(245, 158, 11, 0.45), 0 1px 2px rgba(0,0,0,0.08);
}
.node-action-badge.depth-collapsed-btn:hover {
  background: #fde68a;
  border-color: #d97706;
  box-shadow: 0 0 10px rgba(245, 158, 11, 0.6), 0 2px 4px rgba(0,0,0,0.12);
}
/* expanded → subtle grey "−" circle */
.node-action-badge.depth-expanded-btn {
  background: #ffffff;
  border-color: #d1d5db;
  color: #6b7280;
}
.node-action-badge.depth-expanded-btn:hover {
  background: #f9fafb;
  border-color: #9ca3af;
}`;
  document.head.appendChild(s);
}

/**
 * Node-action slots are explicit so adding future corner badges does not
 * require changing positioning logic.
 */
const NODE_ACTION_SLOTS = new Set([
  "top-left",
  "top-right",
  "bottom-left",
  "bottom-right",
]);

/**
 * Compute and cache bottom-menu overlap to avoid forced layout on every render.
 */
function _computeBottomMenuOverlap(cy) {
  const container = cy.container();
  const containerHeight = container ? container.clientHeight : 0;
  let bottomOverlap = 0;
  const bottomMenu = document.getElementById("bottom-menu");
  if (container && bottomMenu) {
    const cRect = container.getBoundingClientRect();
    const bmRect = bottomMenu.getBoundingClientRect();
    const isVisible =
      bmRect.height > 0 &&
      !bottomMenu.classList.contains("invisible") &&
      !bottomMenu.classList.contains("opacity-0");
    if (isVisible) {
      bottomOverlap = Math.max(0, cRect.bottom - bmRect.top);
    }
  }
  cy._bottomMenuOverlapCache = {
    bottomOverlap,
    containerHeight,
  };
}

function _getBadgeSizeCacheKey(btn, metrics) {
  return [
    btn.textContent || "",
    btn.className || "",
    metrics.minWidth,
    metrics.height,
  ].join("|");
}

function _measureBadgeSize(btn, metrics) {
  const cacheKey = _getBadgeSizeCacheKey(btn, metrics);
  const cachedSize = btn._badgeSizeCache;
  if (cachedSize && cachedSize.key === cacheKey) {
    return cachedSize.size;
  }
  const rect = btn.getBoundingClientRect();
  const size = {
    width: Math.max(metrics.minWidth, rect.width || 0),
    height: Math.max(metrics.height, rect.height || 0),
  };
  btn._badgeSizeCache = {
    key: cacheKey,
    size,
  };
  return size;
}

function _outsideCornerPosition(slot, bb, size, gap) {
  switch (slot) {
    case "top-left":
      return {
        x: bb.x1 - gap - size.width / 2,
        y: bb.y1 - gap - size.height / 2,
      };
    case "top-right":
      return {
        x: bb.x2 + gap - size.width / 2,
        y: bb.y1 - gap - size.height / 2,
      };
    case "bottom-left":
      return {
        x: bb.x1 - gap - size.width / 2,
        y: bb.y2 + gap - size.height / 2,
      };
    default:
      return {
        x: bb.x2 + gap - size.width / 2,
        y: bb.y2 + gap - size.height / 2,
      };
  }
}

function _nodeRenderedRect(node) {
  const rp = node.renderedPosition();
  const rw = node.renderedOuterWidth();
  const rh = node.renderedOuterHeight();
  if (
    rp &&
    Number.isFinite(rp.x) &&
    Number.isFinite(rp.y) &&
    Number.isFinite(rw) &&
    Number.isFinite(rh) &&
    rw > 0 &&
    rh > 0
  ) {
    return {
      x1: rp.x - rw / 2,
      y1: rp.y - rh / 2,
      x2: rp.x + rw / 2,
      y2: rp.y + rh / 2,
      w: rw,
      h: rh,
    };
  }

  return node.renderedBoundingBox({
    includeLabels: false,
    includeOverlays: false,
  });
}

function _getDepthToggleActionSpec(cy, node) {
  const children = node.outgoers("node").filter((m) => !m.isParent());
  if (children.length === 0) return null;

  const collapsed = isDepthCollapsed(node);
  const hiddenCount = node.data("_hiddenChildCount") || children.length;

  if (collapsed) {
    return {
      key: "depth-toggle",
      slot: "bottom-right",
      text: `+${hiddenCount}`,
      className: "depth-collapsed-btn",
      title: `Expand ${hiddenCount} hidden child${hiddenCount === 1 ? "" : "ren"} (E)`,
      ariaLabel: `Expand ${hiddenCount} hidden child${hiddenCount === 1 ? "" : "ren"} of node ${node.id()}`,
      onClick: () => expandNodeChildren(cy, node),
    };
  }

  return {
    key: "depth-toggle",
    slot: "bottom-right",
    text: "\u2212",
    className: "depth-expanded-btn",
    title: `Collapse ${children.length} child${children.length === 1 ? "" : "ren"} (C)`,
    ariaLabel: `Collapse ${children.length} child${children.length === 1 ? "" : "ren"} of node ${node.id()}`,
    onClick: () => collapseNodeChildren(cy, node),
  };
}

function _getNodeActionSpecs(cy, node) {
  const specs = [];
  const depthSpec = _getDepthToggleActionSpec(cy, node);
  if (depthSpec) specs.push(depthSpec);
  return specs;
}

function _createNodeActionBadge(spec, nodeId) {
  const btn = document.createElement("button");
  btn.type = "button";
  btn.className = "node-action-badge";
  btn.tabIndex = -1;
  btn.dataset.nodeId = nodeId;
  btn.dataset.actionKey = spec.key;
  btn.dataset.slot = spec.slot;
  btn.textContent = spec.text;
  btn.title = spec.title;
  btn.setAttribute("aria-label", spec.ariaLabel);
  if (spec.className) {
    btn.classList.add(spec.className);
  }

  btn.addEventListener("mousedown", (e) => e.stopPropagation());
  btn.addEventListener("pointerdown", (e) => e.stopPropagation());
  btn.addEventListener("click", (e) => {
    e.preventDefault();
    e.stopPropagation();
    spec.onClick();
  });

  return btn;
}

function _rebuildNodeActionBadges(cy, container) {
  if (!container) return;

  _injectNodeActionBadgeStyles();

  let overlay = container.querySelector(".node-action-badge-overlay");
  if (!overlay) {
    overlay = document.createElement("div");
    overlay.className = "node-action-badge-overlay";
    const pos = getComputedStyle(container).position;
    if (pos === "static") container.style.position = "relative";
    container.appendChild(overlay);
  }

  overlay.innerHTML = "";

  cy._nodeActionBadgeOverlay = overlay;
  cy._nodeActionBadges = new Map();

  const visible = cy
    .nodes()
    .filter(
      (n) =>
        !n.isParent() && !n.hasClass("depth-hidden") && !n.hasClass("hidden"),
    );

  visible.forEach((node) => {
    _getNodeActionSpecs(cy, node).forEach((spec) => {
      const btn = _createNodeActionBadge(spec, node.id());
      overlay.appendChild(btn);
      cy._nodeActionBadges.set(`${node.id()}:${spec.key}`, {
        el: btn,
        nodeId: node.id(),
        slot: spec.slot,
      });
    });
  });

  _updateNodeActionBadgePositions(cy);
}

/**
 * Reposition every action badge to its configured node corner.
 */
function _updateNodeActionBadgePositions(cy) {
  if (!cy._nodeActionBadges) return;

  // Use cached bottom-menu overlap to avoid forced layout on every render
  const cache = cy._bottomMenuOverlapCache || {
    bottomOverlap: 0,
    containerHeight: 0,
  };
  const visibleBottom = Math.max(
    0,
    cache.containerHeight - cache.bottomOverlap,
  );

  const metrics = _nodeActionBadgeMetrics(cy.zoom());

  cy._nodeActionBadges.forEach((badge) => {
    const btn = badge.el;
    const nodeId = badge.nodeId;
    const node = cy.getElementById(nodeId);
    if (
      !node ||
      node.length === 0 ||
      node.hasClass("depth-hidden") ||
      node.hasClass("hidden")
    ) {
      btn.style.display = "none";
      return;
    }

    const bb = _nodeRenderedRect(node);
    if (!bb || bb.w === 0) {
      btn.style.display = "none";
      return;
    }
    const slot = NODE_ACTION_SLOTS.has(badge.slot)
      ? badge.slot
      : "bottom-right";

    btn.style.display = metrics.visible ? "inline-flex" : "none";
    btn.style.opacity = `${metrics.opacity}`;
    btn.style.pointerEvents = metrics.visible ? "auto" : "none";
    if (!metrics.visible) return;

    btn.style.minWidth = `${metrics.minWidth}px`;
    btn.style.height = `${metrics.height}px`;
    btn.style.padding = `0 ${metrics.paddingX}px`;
    btn.style.borderRadius = `${metrics.borderRadius}px`;
    btn.style.borderWidth = `${metrics.borderWidth}px`;
    btn.style.fontSize = `${metrics.fontSize}px`;

    const size = _measureBadgeSize(btn, metrics);
    const pos = _outsideCornerPosition(slot, bb, size, metrics.outsideGap);
    if (pos.y + size.height > visibleBottom) {
      btn.style.display = "none";
      return;
    }
    btn.style.left = `${_snapOverlayPixel(pos.x)}px`;
    btn.style.top = `${_snapOverlayPixel(pos.y)}px`;
  });
}

import cytoscape from "cytoscape";
import dagre from "cytoscape-dagre";
import { graphStyle } from "./graph_style";
import { layoutConfig } from "./layout_config.js";
import { createGraphRenderer } from "./graph_renderer.js";

cytoscape.use(dagre);

const VISIBLE_GRAPH_NODE_FILTER = (n) =>
  !n.hasClass("hidden") &&
  !n.hasClass("depth-hidden") &&
  !n.hasClass("focus-hidden") &&
  !n.hasClass("presentation-hidden") &&
  !n.hasClass("presentation-hidden-parent");

const clampValue = (value, min, max) => Math.max(min, Math.min(max, value));
const RIGHT_DRAWER_SELECTOR = "[data-right-drawer]";

const getRightDrawers = () =>
  Array.from(document.querySelectorAll(RIGHT_DRAWER_SELECTOR));

const getRightDrawerOverlap = (containerRect) => {
  let overlap = 0;

  getRightDrawers().forEach((panel) => {
    const panelRect = panel.getBoundingClientRect();
    if (!panelRect) return;

    const currentOverlap = Math.min(
      containerRect.width,
      Math.max(0, containerRect.right - panelRect.left),
    );

    if (currentOverlap > overlap) overlap = currentOverlap;
  });

  return overlap;
};

const getVisibleViewport = (container) => {
  const rect = container.getBoundingClientRect();
  const interactionSettings = layoutConfig.interactionSettings || {};
  const margin = interactionSettings.viewportMargin || 24;
  const rightInset = getRightDrawerOverlap(rect);

  let bottomInset = 0;
  const bottomMenu = document.getElementById("bottom-menu");
  if (bottomMenu) {
    const menuRect = bottomMenu.getBoundingClientRect();
    const menuVisible =
      menuRect.height > 0 &&
      !bottomMenu.classList.contains("invisible") &&
      !bottomMenu.classList.contains("opacity-0");

    if (menuVisible) {
      bottomInset = Math.max(0, rect.bottom - menuRect.top);
    }
  }

  const left = margin;
  const top = margin;
  const right = Math.max(left, rect.width - rightInset - margin);
  const bottom = Math.max(top, rect.height - bottomInset - margin);

  return {
    left,
    top,
    right,
    bottom,
    width: Math.max(0, right - left),
    height: Math.max(0, bottom - top),
  };
};

const constrainViewport = (cy, container) => {
  if (!cy || !container) return false;

  const visibleNodes = cy.nodes().filter(VISIBLE_GRAPH_NODE_FILTER);
  if (!visibleNodes || visibleNodes.length === 0) return false;

  const viewport = getVisibleViewport(container);
  const interactionSettings = layoutConfig.interactionSettings || {};
  const tolerance = interactionSettings.viewportTolerance || 0.5;
  const minVisibleRatio = interactionSettings.minVisibleRatio || 0.18;
  const minVisiblePixels = interactionSettings.minVisiblePixels || 120;
  const maxVisiblePixels = interactionSettings.maxVisiblePixels || 220;

  const zoom = cy.zoom();
  const pan = cy.pan();
  const bb = visibleNodes.boundingBox();

  const renderedLeft = bb.x1 * zoom + pan.x;
  const renderedRight = bb.x2 * zoom + pan.x;
  const renderedTop = bb.y1 * zoom + pan.y;
  const renderedBottom = bb.y2 * zoom + pan.y;
  const renderedWidth = Math.max(1, renderedRight - renderedLeft);
  const renderedHeight = Math.max(1, renderedBottom - renderedTop);

  const targetVisibleX = clampValue(
    viewport.width * minVisibleRatio,
    minVisiblePixels,
    maxVisiblePixels,
  );
  const targetVisibleY = clampValue(
    viewport.height * minVisibleRatio,
    minVisiblePixels,
    maxVisiblePixels,
  );

  const minOverlapX = Math.max(
    Math.min(24, renderedWidth),
    Math.min(renderedWidth * 0.8, targetVisibleX),
  );
  const minOverlapY = Math.max(
    Math.min(24, renderedHeight),
    Math.min(renderedHeight * 0.8, targetVisibleY),
  );

  let dx = 0;
  let dy = 0;

  if (renderedRight < viewport.left + minOverlapX) {
    dx = viewport.left + minOverlapX - renderedRight;
  } else if (renderedLeft > viewport.right - minOverlapX) {
    dx = viewport.right - minOverlapX - renderedLeft;
  }

  if (renderedBottom < viewport.top + minOverlapY) {
    dy = viewport.top + minOverlapY - renderedBottom;
  } else if (renderedTop > viewport.bottom - minOverlapY) {
    dy = viewport.bottom - minOverlapY - renderedTop;
  }

  if (Math.abs(dx) <= tolerance && Math.abs(dy) <= tolerance) {
    return false;
  }

  cy.pan({ x: pan.x + dx, y: pan.y + dy });
  return true;
};

export const fitVisibleGraph = (cy, container, padding = 24) => {
  if (!cy || !container || cy.destroyed()) {
    return false;
  }

  const visibleNodes = cy.nodes().filter(VISIBLE_GRAPH_NODE_FILTER);
  if (visibleNodes.length === 0) return false;

  const viewport = getVisibleViewport(container);
  const width = viewport.width - 2 * padding;
  const height = viewport.height - 2 * padding;
  if (width <= 0 || height <= 0) return false;

  const bounds = visibleNodes.boundingBox();
  if (![bounds.x1, bounds.y1, bounds.w, bounds.h].every(Number.isFinite)) {
    return false;
  }

  // Fit the overview into the unobscured canvas, without enlarging small grids.
  const zoom = clampValue(
    Math.min(width / Math.max(1, bounds.w), height / Math.max(1, bounds.h), 1),
    cy.minZoom(),
    cy.maxZoom(),
  );
  cy.viewport({
    zoom,
    pan: {
      x: viewport.left + viewport.width / 2 - (bounds.x1 + bounds.w / 2) * zoom,
      y: viewport.top + viewport.height / 2 - (bounds.y1 + bounds.h / 2) * zoom,
    },
  });

  return true;
};

export const frameReadingGraph = (
  cy, container, focusNodeId, viewMode = "spaced", direction = "TB",
) => {
  if (!cy || !container || cy.destroyed()) return false;
  const nodes = cy.nodes().filter(VISIBLE_GRAPH_NODE_FILTER);
  if (nodes.length === 0) return false;

  const viewport = getVisibleViewport(container);
  const padding = 24;
  const width = viewport.width - 2 * padding;
  const height = viewport.height - 2 * padding;
  if (width <= 0 || height <= 0) return false;

  const focus = nodes.getElementById(String(focusNodeId)).first();
  const node = focus.length ? focus : nodes.first();
  const bounds = nodes.boundingBox();
  const nodeBounds = node.boundingBox();
  const minReadingZoom = viewMode === "compact"
    ? layoutConfig.readabilitySettings.compactMinInitialZoom
    : layoutConfig.readabilitySettings.spacedMinInitialZoom;
  const zoom = clampValue(Math.min(
    1,
    Math.max(minReadingZoom, Math.min(width / bounds.w, height / bounds.h)),
    width / Math.max(1, nodeBounds.w),
    height / Math.max(1, nodeBounds.h),
  ), cy.minZoom(), cy.maxZoom());

  // Leave most of the canvas ahead of the selected idea in the flow direction.
  // Clamp the anchor so the entire title remains visible on narrow screens.
  const leadingAnchor = (length, nodeSize) => clampValue(
    length * 0.22,
    padding + nodeSize * zoom / 2,
    length - padding - nodeSize * zoom / 2,
  );
  let x = viewport.width / 2;
  let y = viewport.height / 2;
  if (direction === "LR" || direction === "RL") {
    x = leadingAnchor(viewport.width, nodeBounds.w);
    if (direction === "RL") x = viewport.width - x;
  } else {
    y = leadingAnchor(viewport.height, nodeBounds.h);
    if (direction === "BT") y = viewport.height - y;
  }
  const position = node.position();
  cy.viewport({
    zoom,
    pan: {
      x: viewport.left + x - position.x * zoom,
      y: viewport.top + y - position.y * zoom,
    },
  });
  return true;
};

export function draw_graph(
  graph,
  context,
  elements,
  node,
  viewMode = "spaced",
  graphId = null,
  options = {},
) {
  const reduceMotion = options.reduceMotion === true;
  const highContrast = options.highContrast === true;

  // Get graph direction from localStorage
  const graphDirection = localStorage.getItem("graph_direction") || "TB";

  // Select layout based on view mode
  const baseLayoutConfig =
    viewMode === "compact"
      ? layoutConfig.compactLayout
      : layoutConfig.baseLayout;

  const initialFitPadding = 24;
  const layoutOptions =
    options.layoutName === "preset"
      ? {
          name: "preset",
          fit: false,
          padding: initialFitPadding,
        }
      : {
          ...baseLayoutConfig,
          rankDir: graphDirection,
          fit: false,
          padding: initialFitPadding,
          ...(reduceMotion || options.animateInitialLayout === false
            ? { animate: false, animationDuration: 0 }
            : {}),
        };

  const cy = createGraphRenderer(
    {
      container: graph,
      elements,
      style: graphStyle(viewMode, { highContrast, reduceMotion }),
      layout: { name: "preset", fit: false },
      boxSelectionEnabled: false,
      autounselectify: false,
      // Apply depth-collapse before running the initial layout.
      minZoom: layoutConfig.zoomSettings.min || 0.05,
      maxZoom: layoutConfig.zoomSettings.max || 4.0,
      webgl: options.webgl !== false,
    },
    (lostCy) => {
      if (context.cy !== lostCy) return;
      const focusedBranchId = lostCy._focusedBranchId;
      const readerPathFocus = lostCy._readerPathFocus;
      context._recreateCy(lostCy.elements().jsons(), {
        webgl: false,
        preserveViewport: true,
        skipInitialLayout: true,
        layoutName: "preset",
      });
      context.cy._focusedBranchId = focusedBranchId;
      context.cy._readerPathFocus = readerPathFocus;
    },
  );

  // Store graphId on the cy instance so persistence helpers can find it
  cy._graphId = graphId || null;
  cy._reduceMotion = reduceMotion;
  cy._highContrast = highContrast;

  // ── Restore only explicit user depth-collapse state before first layout ──
  const savedState = _loadDepthStateFromStorage(graphId);

  if (savedState && Object.keys(savedState).length > 0) {
    computeNodeDepths(cy);
    Object.keys(savedState).forEach((id) => {
      const n = cy.getElementById(id);
      if (n && n.length > 0 && !n.isParent()) {
        n.data("_depthCollapsed", "true");
        n.addClass("node-collapsed");
      }
    });
    recomputeDepthVisibility(cy);
  }

  // If the target node ended up hidden, expand its ancestors so it's visible
  if (savedState && node) {
    ensureDepthVisible(cy, node);
    _persistDepthState(cy);
  }

  // Figma-like navigation controls
  // - Scroll to pan (Shift for horizontal bias)
  // - Cmd/Ctrl+Scroll or trackpad pinch to zoom at cursor
  // - Hold Space and drag to pan; otherwise keep box selection
  const container = graph;
  const interactionSettings = layoutConfig.interactionSettings || {};
  const normalizeWheelDelta = (delta, deltaMode) => {
    if (deltaMode === 1) {
      return delta * (interactionSettings.wheelLineStep || 18);
    }

    if (deltaMode === 2) {
      return delta * container.clientHeight * (interactionSettings.wheelPageFactor || 0.85);
    }

    return delta;
  };
  const shapePanDelta = (delta) => {
    const speed = interactionSettings.wheelPanSpeed || 0.7;
    const maxStep = interactionSettings.wheelPanMaxStep || 140;
    return clampValue(delta * speed, -maxStep, maxStep);
  };
  let clampPending = false;
  let clampInProgress = false;
  let layoutRunning = false;
  const scheduleViewportClamp = ({ immediate = false } = {}) => {
    if (
      clampInProgress ||
      !cy ||
      (typeof cy.destroyed === "function" && cy.destroyed())
    ) {
      return;
    }

    if (layoutRunning) {
      clampPending = true;
      return;
    }

    const runClamp = () => {
      clampPending = false;
      if (
        clampInProgress ||
        !cy ||
        (typeof cy.destroyed === "function" && cy.destroyed())
      ) {
        return;
      }

      if (layoutRunning) {
        clampPending = true;
        return;
      }

      clampInProgress = true;
      try {
        constrainViewport(cy, container);
      } finally {
        clampInProgress = false;
      }
    };

    if (immediate) {
      runClamp();
      return;
    }

    if (clampPending) return;
    clampPending = true;
    requestAnimationFrame(runClamp);
  };

  let initialLayoutReadyNotified = false;
  const notifyInitialLayoutReady = () => {
    if (
      initialLayoutReadyNotified ||
      typeof options.onInitialLayoutReady !== "function"
    ) {
      return;
    }

    initialLayoutReadyNotified = true;
    requestAnimationFrame(() => {
      if (!cy || (typeof cy.destroyed === "function" && cy.destroyed())) return;
      options.onInitialLayoutReady();
    });
  };

  // Track layout running to avoid pre-layout panning/centering flicker
  let initialGraphFitted = options.skipInitialLayout === true;
  cy._initialLayoutComplete = options.skipInitialLayout === true;
  cy.on("layoutstart", () => {
    layoutRunning = true;
  });
  cy.on("layoutstop", () => {
    layoutRunning = false;
    cy._initialLayoutComplete = true;
    const hadPendingClamp = clampPending;
    clampPending = false;

    if (!initialGraphFitted) {
      initialGraphFitted = true;
      requestAnimationFrame(() => {
        if (!cy || (typeof cy.destroyed === "function" && cy.destroyed())) return;
        if (options.fitInitialViewport !== false) {
          frameReadingGraph(cy, container, node, viewMode, graphDirection);
        }
        scheduleViewportClamp({ immediate: true });
        notifyInitialLayoutReady();
      });
      return;
    }

    scheduleViewportClamp({ immediate: hadPendingClamp });
  });

  // Now run the initial layout (only visible nodes are positioned)
  // Placed after layoutRunning listeners so the initial layout is tracked.
  // Presentation mode can opt out and provide explicit coordinates.
  if (options.skipInitialLayout === true) {
    requestAnimationFrame(() => {
      scheduleViewportClamp({ immediate: true });
      notifyInitialLayoutReady();
    });
  } else {
    cy.layout(layoutOptions).run();
  }

  // Disable Cytoscape's default wheel zoom so we fully control it
  cy.userZoomingEnabled(false);

  const applySelectionContext = (nodeOrId) => {
    try {
      cy.$(".selected-neighbor, .selected-edge").removeClass(
        "selected-neighbor selected-edge",
      );

      const selected =
        typeof nodeOrId === "string" ? cy.getElementById(nodeOrId) : nodeOrId;

      if (!selected || selected.length === 0 || selected.isParent()) return;

      const contextualEdges = selected.connectedEdges().filter((edge) => {
        return (
          !edge.hasClass("hidden") &&
          !edge.hasClass("depth-hidden") &&
          !edge.hasClass("focus-hidden") &&
          !edge.hasClass("presentation-hidden")
        );
      });

      contextualEdges.addClass("selected-edge");

      contextualEdges
        .connectedNodes()
        .filter((node) => {
          return (
            node.id() !== selected.id() &&
            !node.isParent() &&
            !node.hasClass("hidden") &&
            !node.hasClass("depth-hidden") &&
            !node.hasClass("focus-hidden") &&
            !node.hasClass("presentation-hidden")
          );
        })
        .addClass("selected-neighbor");

      _rebuildFocusControls(cy, container);
    } catch (_e) {}
  };

  cy.applySelectionContext = applySelectionContext;

  // Hover styles are defined per-type in graph_style.js and applied via "node-hover" class

  // Toggle hover class, excluding compound (parent) nodes
  cy.on("mouseover", "node", (evt) => {
    const n = evt.target;
    if (n.isParent && n.isParent()) return;
    cy.batch(() => {
      n.addClass("node-hover");
      n.connectedEdges().addClass("edge-hover");
    });
    if (!isSpaceDown && !isMouseDown) {
      container.style.cursor = "pointer";
    }
  });
  cy.on("mouseout", "node", (evt) => {
    const n = evt.target;
    cy.batch(() => {
      n.removeClass("node-hover");
      n.connectedEdges().removeClass("edge-hover");
    });
    if (!isMouseDown) {
      container.style.cursor = isSpaceDown ? "grab" : "";
    }
  });

  // Smooth, cursor-centered zoom
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
      const zoomDelta = normalizeWheelDelta(e.deltaY, e.deltaMode);
      const zoomFactor = Math.pow(1 + sensitivity, -zoomDelta);
      const next = clampValue(
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
      let dx = shapePanDelta(normalizeWheelDelta(e.deltaX, e.deltaMode));
      let dy = shapePanDelta(normalizeWheelDelta(e.deltaY, e.deltaMode));
      if (e.shiftKey && Math.abs(e.deltaX) < Math.abs(e.deltaY)) {
        dx = shapePanDelta(normalizeWheelDelta(e.deltaY, e.deltaMode));
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

      const next = clampValue(
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
    if (container.closest("#graph-keyboard-workspace") && !container.contains(target)) return;

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
                  !n.hasClass("focus-hidden") &&
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

          cy.elements().removeClass("selected");
          target.addClass("selected");

          const finishNavigation = () => {
            applySelectionContext(target);
            requestAnimationFrame(() => ensureVisible(cy, container, target.id()));
          };
          const needsReflow =
            typeof cy.ensureNodeVisible === "function"
              ? cy.ensureNodeVisible(target.id())
              : false;

          if (needsReflow) {
            cy.reflowAfterVisibilityChange(finishNavigation);
          } else {
            finishNavigation();
          }
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
      scheduleViewportClamp();
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
    applySelectionContext(n);

    // Ensure node is within visible bounds using model-space + zoom/pan; pan minimally if off-screen
    const rect = container.getBoundingClientRect();
    const overlap = getRightDrawerOverlap(rect);

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
        duration: cy._reduceMotion ? 0 : 150,
        easing: "ease-in-out-quad",
      });
    }
    // If a layout is running, skip the pre-layout nudge to avoid flicker.
  });

  requestAnimationFrame(() => {
    if (cy.destroyed()) return;
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
      applySelectionContext(initial);
    }
    scheduleViewportClamp();
  });

  const serverEventRefs = [];
  const handleServerEvent = (name, handler) => {
    serverEventRefs.push(context.handleEvent(name, handler));
  };
  // Force a full relayout after server-side graph changes
  // Delay ensures any in-flight layout from updated() completes first
  handleServerEvent("reflow_layout", () => {
    setTimeout(() => {
      if (cy.destroyed()) return;
      try {
        _relayoutAfterDepthChange(cy);
      } catch (_e) {}
    }, 350);
  });

  // Depth-collapse events from LiveView
  handleServerEvent("expand_node", ({ id }) => {
    try {
      const n = cy.getElementById(id);
      if (n && n.length > 0 && !n.isParent()) {
        expandNodeChildren(cy, n);
      }
    } catch (_e) {}
  });

  handleServerEvent("collapse_node", ({ id }) => {
    try {
      const n = cy.getElementById(id);
      if (n && n.length > 0 && !n.isParent()) {
        collapseNodeChildren(cy, n);
      }
    } catch (_e) {}
  });

  handleServerEvent("expand_all_depth", () => {
    try {
      expandAllDepth(cy);
    } catch (_e) {}
  });

  handleServerEvent("collapse_all_depth", (payload) => {
    try {
      const defaultCollapseDepth = 1;
      const maxDepth =
        payload && payload.max_depth != null
          ? payload.max_depth
          : defaultCollapseDepth;
      collapseAllDepth(cy, maxDepth);
    } catch (_e) {}
  });

  cy.constrainViewport = () => constrainViewport(cy, container);
  cy.scheduleViewportClamp = (opts) => scheduleViewportClamp(opts);

  // Expose depth-collapse helpers on the cy instance for graph_hook.js
  cy.saveDepthCollapseState = () => saveDepthCollapseState(cy);
  cy.restoreDepthCollapseState = (state) =>
    restoreDepthCollapseState(cy, state);
  cy.recomputeDepthVisibility = () => recomputeDepthVisibility(cy);
  cy.ensureDepthVisible = (id) => ensureDepthVisible(cy, id);
  cy.ensureNodeVisible = (id) => ensureNodeVisible(cy, id);
  cy.focusBranch = (nodeOrId) =>
    focusBranch(
      cy,
      typeof nodeOrId === "string" ? cy.getElementById(nodeOrId) : nodeOrId,
      container,
    );
  cy.focusPath = (ids, onDone, focusOptions) =>
    focusPath(cy, ids, container, onDone, focusOptions);
  cy.clearBranchFocus = () => clearBranchFocus(cy, container);
  cy.reflowAfterVisibilityChange = (onDone, reflowOptions) =>
    reflowAfterVisibilityChange(cy, onDone, reflowOptions);
  cy.expandNodeChildren = (n) =>
    expandNodeChildren(cy, typeof n === "string" ? cy.getElementById(n) : n);
  cy.collapseNodeChildren = (n) =>
    collapseNodeChildren(cy, typeof n === "string" ? cy.getElementById(n) : n);

  let viewportClampTimeout = null;
  const queueViewportClamp = () => {
    if (viewportClampTimeout !== null) {
      clearTimeout(viewportClampTimeout);
    }

    viewportClampTimeout = setTimeout(() => {
      viewportClampTimeout = null;
      scheduleViewportClamp();
    }, 80);
  };
  const flushViewportClamp = () => {
    if (viewportClampTimeout !== null) {
      clearTimeout(viewportClampTimeout);
      viewportClampTimeout = null;
    }

    scheduleViewportClamp();
  };

  cy.on("pan zoom", queueViewportClamp);
  cy.on("mouseup touchend", flushViewportClamp);

  // ── Depth-toggle overlay buttons (expand/collapse via mouse click) ──
  _injectDepthToggleStyles();

  // Rebuild overlay buttons after every layout completes (covers init + expand/collapse relayouts)
  cy.on("layoutstop", () => {
    _rebuildDepthToggleOverlays(cy, container);
    _rebuildFocusControls(cy, container);
  });

  // Keep button positions in sync with pan / zoom / animation (throttled to 1 rAF)
  let _depthToggleRafPending = false;
  cy.on("pan zoom position bounds resize", () => {
    if (!_depthToggleRafPending) {
      _depthToggleRafPending = true;
      requestAnimationFrame(() => {
        _depthToggleRafPending = false;
        if (!cy || (typeof cy.destroyed === "function" && cy.destroyed())) return;
        _updateDepthTogglePositions(cy);
      });
    }
  });

  // Build initial overlays — the first layoutstop may fire before the listener
  // above is registered (if dagre finishes synchronously), so schedule a fallback.
  requestAnimationFrame(() => {
    if (cy.destroyed()) return;
    _rebuildDepthToggleOverlays(cy, container);
    _rebuildFocusControls(cy, container);
  });

  // Expose cleanup so graph_hook.js can remove the overlay on destroy
  cy.cleanupDepthOverlay = () => {
    try {
      if (cy._depthToggleOverlay && cy._depthToggleOverlay.parentNode) {
        cy._depthToggleOverlay.parentNode.removeChild(cy._depthToggleOverlay);
      }
      cy._depthToggleOverlay = null;
      cy._depthToggleButtons = null;
      if (cy._focusOverlay && cy._focusOverlay.parentNode) {
        cy._focusOverlay.parentNode.removeChild(cy._focusOverlay);
      }
      cy._focusOverlay = null;
      cy._focusControls = null;
      _depthToggleRafPending = false;
    } catch (_e) {}
  };

  cy.one("destroy", () => {
    serverEventRefs.forEach((ref) => context.removeHandleEvent(ref));
    container.removeEventListener("wheel", wheelHandler);
    container.removeEventListener("mousedown", mousedownHandler);
    container.removeEventListener("touchstart", touchStartHandler);
    container.removeEventListener("touchmove", touchMoveHandler);
    container.removeEventListener("touchend", touchEndHandler);
    container.removeEventListener("touchcancel", touchEndHandler);
    document.removeEventListener("keydown", keydownHandler);
    document.removeEventListener("keyup", keyupHandler);
    window.removeEventListener("mousemove", mousemoveHandler);
    window.removeEventListener("mouseup", mouseupHandler);
    if (viewportClampTimeout !== null) clearTimeout(viewportClampTimeout);
    cy.cleanupDepthOverlay();
  });
  return cy;
}

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

  const viewportAnchor = captureViewportAnchor(cy, node);
  node.data("_depthCollapsed", "true");
  node.addClass("node-collapsed");
  recomputeDepthVisibility(cy);
  _persistDepthState(cy);
  reflowAfterVisibilityChange(cy, null, { animate: false, viewportAnchor });
}

/**
 * Expand a node's direct children: clear the collapsed flag, recompute
 * visibility, and re-run the layout.
 */
function expandNodeChildren(cy, node) {
  if (!node || node.length === 0 || node.isParent()) return;
  if (!isDepthCollapsed(node)) return;

  const viewportAnchor = captureViewportAnchor(cy, node);
  node.removeData("_depthCollapsed");
  node.removeClass("node-collapsed");
  recomputeDepthVisibility(cy);
  _persistDepthState(cy);
  reflowAfterVisibilityChange(cy, null, { animate: false, viewportAnchor });
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
  reflowAfterVisibilityChange(cy);
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
 * Ensure a specific node is visible by expanding any collapsed ancestors
 * along the path from a root to it.
 */
function ensureDepthVisible(cy, nodeId) {
  const node = cy.getElementById(nodeId);
  if (!node || node.length === 0 || !node.hasClass("depth-hidden")) return false;

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

  return changed;
}

function clearBranchFocusState(cy) {
  const changed = Boolean(cy._focusedBranchId) || cy.$(".focus-hidden").length > 0;
  cy.elements().removeClass("focus-hidden");
  cy._focusedBranchId = null;
  return changed;
}

function applyPathFocusState(cy, ids) {
  const requestedIds = [...new Set((ids || []).map((id) => String(id)))];
  const pathNodes = cy.collection(
    requestedIds.map((id) => cy.getElementById(id)).filter((node) => node.length > 0),
  );
  const pathIds = pathNodes.map((node) => node.id());
  if (pathIds.length === 0) return [];

  cy.elements().removeClass("focus-hidden");
  const keptNodes = pathNodes.union(pathNodes.ancestors());
  cy.nodes().difference(keptNodes).addClass("focus-hidden");
  cy.edges().forEach((edge) => {
    if (
      edge.source().hasClass("focus-hidden") ||
      edge.target().hasClass("focus-hidden")
    ) {
      edge.addClass("focus-hidden");
    }
  });

  cy._focusedBranchId = pathIds[pathIds.length - 1];
  return pathIds;
}

function captureViewportAnchor(cy, node) {
  if (!cy || !node || node.length === 0) return null;

  return {
    nodeId: node.id(),
    renderedPosition: node.renderedPosition(),
    zoom: cy.zoom(),
  };
}

function restoreViewportAnchor(cy, anchor) {
  if (!cy || !anchor) return false;

  const node = cy.getElementById(anchor.nodeId);
  if (!node || node.length === 0) return false;

  const position = node.position();
  cy.zoom(anchor.zoom);
  cy.pan({
    x: anchor.renderedPosition.x - position.x * anchor.zoom,
    y: anchor.renderedPosition.y - position.y * anchor.zoom,
  });
  return true;
}

export function focusPath(
  cy,
  ids,
  container = cy.container?.(),
  onDone,
  { animate = true, preserveViewport = false } = {},
) {
  const selectedBeforeFocus = cy
    .$("node.selected")
    .filter((node) => !node.isParent())
    .first();
  const viewportAnchor = preserveViewport
    ? captureViewportAnchor(cy, selectedBeforeFocus)
    : null;
  const pathIds = applyPathFocusState(cy, ids);
  if (pathIds.length === 0) return false;

  cy._readerPathFocus = true;
  _rebuildFocusControls(cy, container);
  reflowAfterVisibilityChange(cy, () => {
    _rebuildFocusControls(cy, container);
    const selected = cy.$("node.selected").filter((node) => !node.isParent());
    if (selected.length > 0) cy.applySelectionContext?.(selected[0]);
    if (container && !preserveViewport) {
      fitVisibleGraph(cy, container);
    }
    onDone?.();
  }, { animate, viewportAnchor });
  return true;
}

export function focusBranch(cy, node, container = cy.container?.()) {
  if (!node || node.length === 0 || node.isParent()) return false;

  const ancestors = node.predecessors().filter((element) => element.isNode());
  const pathIds = ancestors.union(node).map((pathNode) => pathNode.id());
  const viewportAnchor = captureViewportAnchor(cy, node);
  applyPathFocusState(cy, pathIds);

  if (cy._ownerHook?.pushEvent) {
    cy._readerPathFocus = true;
    cy._ownerHook._localReaderPathEndpoint = node.id();
    cy._ownerHook.pushEvent("set_reader_path", { id: node.id() });

    const url = new URL(window.location.href);
    url.searchParams.set("path", node.id());
    window.history.replaceState(window.history.state, "", url);
  } else {
    cy._readerPathFocus = false;
  }

  _rebuildFocusControls(cy, container);
  reflowAfterVisibilityChange(cy, () => {
    _rebuildFocusControls(cy, container);
    cy.applySelectionContext?.(node);
  }, { animate: false, viewportAnchor });
  return true;
}

function clearReaderPathState(cy) {
  if (!cy._readerPathFocus) return false;

  cy._readerPathFocus = false;
  cy._ownerHook?.pushEvent?.("clear_reader_path", {});

  const url = new URL(window.location.href);
  url.searchParams.delete("path");
  window.history.replaceState(window.history.state, "", url);
  return true;
}

export function clearBranchFocus(cy, container = cy.container?.()) {
  const selected = cy.$("node.selected").filter((node) => !node.isParent());
  const viewportAnchor = captureViewportAnchor(cy, selected.first());
  if (!clearBranchFocusState(cy)) return false;

  clearReaderPathState(cy);
  _rebuildDepthToggleOverlays(cy, container);
  _rebuildFocusControls(cy, container);
  reflowAfterVisibilityChange(cy, () => {
    _rebuildFocusControls(cy, container);
    if (selected.length > 0) cy.applySelectionContext?.(selected[0]);
  }, { animate: false, viewportAnchor });
  return true;
}

function ensureNodeVisible(cy, nodeId) {
  const node = cy.getElementById(nodeId);
  const focusChanged =
    node && node.length > 0 && node.hasClass("focus-hidden")
      ? clearBranchFocusState(cy)
      : false;
  if (focusChanged) clearReaderPathState(cy);

  const depthChanged = ensureDepthVisible(cy, nodeId);

  return focusChanged || depthChanged;
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

/** Persist the current collapse flags to localStorage. */
function _persistDepthState(cy) {
  const key = _depthStorageKey(cy._graphId);
  if (!key) return;
  try {
    const state = saveDepthCollapseState(cy);
    localStorage.setItem(
      key,
      JSON.stringify({
        version: 2,
        state,
      }),
    );
  } catch (_e) {}
}

/** Load saved collapse flags from localStorage (returns object or null).
 *  Only explicit user-persisted v2 state is restored.
 */
function _loadDepthStateFromStorage(graphId) {
  const key = _depthStorageKey(graphId);
  if (!key) return null;
  try {
    const raw = localStorage.getItem(key);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (
      parsed &&
      parsed.version === 2 &&
      parsed.state &&
      typeof parsed.state === "object" &&
      !Array.isArray(parsed.state)
    ) {
      return parsed.state;
    }
  } catch (_e) {}
  return null;
}

/**
 * Internal helper: re-run the dagre layout after a depth visibility change
 * so that visible nodes reposition into a clean arrangement.
 */
export function reflowAfterVisibilityChange(
  cy,
  onDone,
  { animate, viewportAnchor } = {},
) {
  if (typeof onDone === "function") {
    cy._visibilityReflowCallbacks ||= [];
    cy._visibilityReflowCallbacks.push(onDone);
  }

  if (animate === false) {
    cy._visibilityReflowAnimate = false;
  } else if (cy._visibilityReflowAnimate === undefined && animate === true) {
    cy._visibilityReflowAnimate = true;
  }

  if (viewportAnchor) {
    cy._visibilityReflowViewportAnchor = viewportAnchor;
  }

  if (cy._visibilityReflowPending) return;
  cy._visibilityReflowPending = true;

  requestAnimationFrame(() => {
    if (!cy || (typeof cy.destroyed === "function" && cy.destroyed())) return;

    try {
      cy.style().update();
      cy.resize();
    } catch (_e) {}

    requestAnimationFrame(() => {
      if (!cy || (typeof cy.destroyed === "function" && cy.destroyed())) return;

      cy._visibilityReflowPending = false;
      const reflowAnimate = cy._visibilityReflowAnimate;
      cy._visibilityReflowAnimate = undefined;
      const callbacks = cy._visibilityReflowCallbacks || [];
      cy._visibilityReflowCallbacks = [];
      const pendingViewportAnchor = cy._visibilityReflowViewportAnchor;
      cy._visibilityReflowViewportAnchor = null;

      if (callbacks.length > 0 || pendingViewportAnchor) {
        cy.one("layoutstop", () => {
          restoreViewportAnchor(cy, pendingViewportAnchor);
          callbacks.forEach((callback) => callback());
        });
      }

      _relayoutAfterDepthChange(cy, { animate: reflowAnimate });
    });
  });
}

export function visibleLayoutElements(cy) {
  return cy.elements().filter((element) => {
    return (
      !element.hasClass("hidden") &&
      !element.hasClass("depth-hidden") &&
      !element.hasClass("focus-hidden") &&
      !element.hasClass("presentation-hidden")
    );
  });
}

function _relayoutAfterDepthChange(cy, { animate } = {}) {
  try {
    const viewMode = localStorage.getItem("graph_view_mode") || "spaced";
    const graphDirection = localStorage.getItem("graph_direction") || "TB";
    const baseLayout =
      viewMode === "compact"
        ? layoutConfig.compactLayout
        : layoutConfig.baseLayout;

    const shouldAnimate =
      typeof animate === "boolean" ? animate && !cy._reduceMotion : !cy._reduceMotion;

    const layoutOptions = {
      ...baseLayout,
      rankDir: graphDirection,
      animate: shouldAnimate,
      animationDuration: shouldAnimate ? 250 : 0,
    };

    if (typeof cy.elements === "function") {
      layoutOptions.eles = visibleLayoutElements(cy);
    }

    cy.layout(layoutOptions).run();
  } catch (_e) {}
}

/* ═══════════════════════════════════════════════════════════
   Depth-toggle overlay buttons (DOM elements over the canvas)
   ═══════════════════════════════════════════════════════════ */

/** Inject the CSS for toggle buttons once into <head> */
function _injectDepthToggleStyles() {
  if (document.getElementById("depth-toggle-styles")) return;
  const s = document.createElement("style");
  s.id = "depth-toggle-styles";
  s.textContent = `
.depth-toggle-overlay {
  position: absolute;
  top: 0; left: 0;
  width: 100%; height: 100%;
  pointer-events: none;
  z-index: 10;
  overflow: hidden;
}
.depth-toggle-btn {
  --depth-toggle-translate-x: -50%;
  --depth-toggle-translate-y: 0;
  --depth-toggle-scale: 1;
  pointer-events: auto;
  position: absolute;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  padding: 0;
  border-radius: 12px;
  background: #ffffff;
  border: 1.5px solid #cbd5e1;
  color: #475569;
  font-size: 16px;
  font-weight: 600;
  font-family: ui-sans-serif, system-ui, -apple-system, sans-serif;
  cursor: pointer;
  transition: background 0.15s ease, border-color 0.15s ease,
              box-shadow 0.15s ease, transform 0.1s ease;
  box-shadow: 0 1px 2px rgba(0,0,0,0.08);
  user-select: none;
  line-height: 1;
  white-space: nowrap;
  transform: translate(var(--depth-toggle-translate-x), var(--depth-toggle-translate-y)) scale(var(--depth-toggle-scale));
  transform-origin: center center;
}

.depth-chevron {
  width: 9px;
  height: 9px;
  border-right: 2px solid currentColor;
  border-bottom: 2px solid currentColor;
  transition: transform 0.15s ease;
}
.depth-expanded-btn .depth-chevron {
  transform: translateY(-1px) rotate(45deg);
}
.depth-collapsed-btn .depth-chevron {
  transform: translateX(-1px) rotate(-45deg);
}
.depth-toggle-btn:hover {
  background: #f1f5f9;
  border-color: #94a3b8;
  box-shadow: 0 2px 4px rgba(0,0,0,0.12);
}
.depth-toggle-btn:active {
  background: #e2e8f0;
  transform: translate(var(--depth-toggle-translate-x), var(--depth-toggle-translate-y)) scale(calc(var(--depth-toggle-scale) * 0.95));
}
/* Hidden branch → explicit amber Show action. */
.depth-toggle-btn.depth-collapsed-btn {
  background: #fef3c7;
  border-color: #f59e0b;
  color: #92400e;
  box-shadow: none;
}
.depth-toggle-btn.depth-collapsed-btn:hover {
  background: #fde68a;
  border-color: #d97706;
  box-shadow: 0 1px 2px rgba(0,0,0,0.08);
}
/* Visible branch → subtle grey Hide action. */
.depth-toggle-btn.depth-expanded-btn {
  background: transparent;
  border-color: transparent;
  color: #64748b;
  box-shadow: none;
}
.depth-toggle-btn.depth-expanded-btn:hover,
.depth-toggle-btn.depth-expanded-btn:focus-visible,
.depth-toggle-btn.depth-expanded-btn.depth-control-active {
  background: #ffffff;
  border-color: #cbd5e1;
  color: #475569;
}
.depth-toggle-btn:focus-visible {
  outline: 2px solid #0f766e;
  outline-offset: 2px;
}
.graph-focus-controls {
  position: absolute;
  z-index: 9;
  pointer-events: none;
  transform: translate(0, -50%) scale(var(--depth-toggle-scale, 1));
  transform-origin: center center;
}
.graph-focus-overlay {
  position: absolute;
  inset: 0;
  z-index: 11;
  overflow: hidden;
  pointer-events: none;
}
.graph-focus-controls.visibility-control-stack::before {
  position: absolute;
  top: 23px;
  left: 13px;
  z-index: -1;
  width: 2px;
  height: max(0px, calc(var(--visibility-stack-span, 28px) - 18px));
  border-radius: 9999px;
  background: #cbd5e1;
  content: "";
}
.graph-focus-controls button {
  position: relative;
  z-index: 2;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  padding: 0;
  border: 1.5px solid #0f766e;
  border-radius: 12px;
  background: #0f766e;
  color: #ffffff;
  cursor: pointer;
  pointer-events: auto;
  box-shadow: 0 1px 3px rgba(15,118,110,0.3);
  transition: background 0.15s ease, border-color 0.15s ease,
              box-shadow 0.15s ease;
}
.graph-focus-controls button:hover {
  background: #115e59;
  border-color: #115e59;
  box-shadow: 0 2px 6px rgba(15,118,110,0.4);
}
.graph-focus-controls button.branch-focused-btn {
  border-color: #2563eb;
  background: #2563eb;
  box-shadow: 0 1px 3px rgba(37,99,235,0.3);
}
.graph-focus-controls button.branch-focused-btn:hover {
  border-color: #1d4ed8;
  background: #1d4ed8;
}
.graph-focus-controls.graph-clear-focus-controls {
  top: 12px;
  left: 50%;
  z-index: 12;
  display: flex;
  align-items: center;
  gap: 8px;
  transform: translateX(-50%);
  pointer-events: auto;
  border: 1px solid #cbd5e1;
  border-radius: 9999px;
  background: rgba(255,255,255,0.96);
  padding: 5px 8px 5px 10px;
  color: #475569;
  box-shadow: 0 2px 8px rgba(15,23,42,0.12);
  font: 600 11px/1 ui-sans-serif, system-ui, -apple-system, sans-serif;
}
.graph-focus-controls.graph-clear-focus-controls button {
  width: auto;
  height: auto;
  border: 0;
  border-radius: 9999px;
  padding: 5px 9px;
  background: #2563eb;
  box-shadow: none;
  font: inherit;
}
.graph-focus-controls.graph-clear-focus-controls button:hover {
  background: #1d4ed8;
}
.branch-focus-icon {
  position: relative;
  width: 12px;
  height: 12px;
  border: 1.5px solid currentColor;
  border-radius: 50%;
}
.branch-focus-icon::after {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 3px;
  height: 3px;
  border-radius: 50%;
  background: currentColor;
  content: "";
  transform: translate(-50%, -50%);
}`;
  document.head.appendChild(s);
}

function _rebuildFocusControls(cy, container) {
  if (!container) return;

  _injectDepthToggleStyles();

  let focusOverlay = container.querySelector(".graph-focus-overlay");
  if (!focusOverlay) {
    focusOverlay = document.createElement("div");
    focusOverlay.className = "graph-focus-overlay";
    container.appendChild(focusOverlay);
  }

  cy._focusOverlay = focusOverlay;

  let controls = focusOverlay.querySelector(".graph-focus-controls");
  if (!controls) {
    controls = document.createElement("div");
    controls.className = "graph-focus-controls";
    focusOverlay.appendChild(controls);
  }

  cy._focusControls = controls;
  controls.replaceChildren();
  controls.className = "graph-focus-controls";
  delete controls.dataset.nodeId;
  controls.style.removeProperty("left");
  controls.style.removeProperty("top");
  controls.style.removeProperty("--depth-toggle-scale");
  controls.style.removeProperty("--visibility-stack-span");

  const presentationMode = cy?._ownerHook?.el?.dataset?.presentationMode || "off";
  if (presentationMode === "presenting") {
    controls.style.display = "none";
    return;
  }

  const focused = Boolean(cy._focusedBranchId);
  const selected = cy
    .$("node.selected")
    .filter(
      (node) =>
        !node.isParent() &&
        !node.hasClass("hidden") &&
        !node.hasClass("depth-hidden") &&
        !node.hasClass("focus-hidden"),
    );

  if (!focused && selected.length === 0) {
    controls.style.display = "none";
    return;
  }

  controls.style.display = "flex";

  if (focused) {
    controls.classList.add("graph-clear-focus-controls");

    const status = document.createElement("span");
    status.textContent = "Focused branch";
    controls.appendChild(status);

    const clearButton = document.createElement("button");
    clearButton.type = "button";
    clearButton.textContent = "Show all paths";
    clearButton.setAttribute("aria-label", "Show all graph paths");
    clearButton.addEventListener("mousedown", (event) => event.stopPropagation());
    clearButton.addEventListener("pointerdown", (event) => event.stopPropagation());
    clearButton.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      clearBranchFocus(cy, container);
    });
    controls.appendChild(clearButton);
    return;
  }

  const button = document.createElement("button");
  button.type = "button";
  button.title = "Focus this path and hide the others";
  button.setAttribute("aria-label", "Focus the selected graph branch");

  const icon = document.createElement("span");
  icon.className = "branch-focus-icon";
  icon.setAttribute("aria-hidden", "true");
  button.appendChild(icon);
  button.addEventListener("mousedown", (event) => event.stopPropagation());
  button.addEventListener("pointerdown", (event) => event.stopPropagation());
  button.addEventListener("click", (event) => {
    event.preventDefault();
    event.stopPropagation();

    focusBranch(cy, selected[0], container);
  });
  controls.appendChild(button);
  const controlNode =
    selected.length > 0
      ? selected[0]
      : cy.getElementById(cy._focusedBranchId || "");
  controls.dataset.nodeId = controlNode.id();
  controls.classList.toggle(
    "visibility-control-stack",
    controlNode.outgoers("node").filter((node) => !node.isParent()).length > 0,
  );
  _updateDepthTogglePositions(cy);
}

/**
 * (Re)build all toggle buttons for the current set of visible, expandable
 * nodes.  Called after every layout-stop and after the initial render.
 */
function _rebuildDepthToggleOverlays(cy, container) {
  if (!container) return;

  _injectDepthToggleStyles();

  // Create or reuse the overlay container
  let overlay = container.querySelector(".depth-toggle-overlay");
  if (!overlay) {
    overlay = document.createElement("div");
    overlay.className = "depth-toggle-overlay";
    // Ensure the graph container is a positioning context
    const pos = getComputedStyle(container).position;
    if (pos === "static") container.style.position = "relative";
    container.appendChild(overlay);
  }

  // Clear old buttons
  overlay.innerHTML = "";

  const presentationMode = cy?._ownerHook?.el?.dataset?.presentationMode || "off";
  if (presentationMode === "presenting") {
    overlay.style.display = "none";
    cy._depthToggleOverlay = overlay;
    cy._depthToggleButtons = new Map();
    return;
  }

  overlay.style.display = "";

  if (cy._focusedBranchId) {
    overlay.replaceChildren();
    overlay.style.display = "none";
    cy._depthToggleOverlay = overlay;
    cy._depthToggleButtons = new Map();
    return;
  }

  // Store refs on the cy instance for position updates
  cy._depthToggleOverlay = overlay;
  cy._depthToggleButtons = new Map();

  // Find visible, non-compound nodes that have DAG children
  const visible = cy
    .nodes()
    .filter(
      (n) =>
        !n.isParent() &&
        !n.hasClass("depth-hidden") &&
        !n.hasClass("focus-hidden") &&
        !n.hasClass("hidden"),
    );

  visible.forEach((n) => {
    const children = n.outgoers("node").filter((m) => !m.isParent());
    if (children.length === 0) return; // leaf — no button

    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "depth-toggle-btn";
    btn.tabIndex = -1; // keep out of tab order — canvas controls aren't keyboard-navigable
    btn.dataset.nodeId = n.id();

    const collapsed = isDepthCollapsed(n);
    const hiddenCount = n.data("_hiddenChildCount") || children.length;

    if (collapsed) {
      btn.classList.add("depth-collapsed-btn");
      btn.title = `Show downstream branch (${hiddenCount} direct child${hiddenCount === 1 ? "" : "ren"}) (E)`;
      btn.setAttribute("aria-label", `Show downstream branch from node ${n.id()}`);
    } else {
      btn.classList.add("depth-expanded-btn");
      btn.title = `Hide downstream branch (${children.length} direct child${children.length === 1 ? "" : "ren"}) (C)`;
      btn.setAttribute("aria-label", `Hide downstream branch from node ${n.id()}`);
    }

    const icon = document.createElement("span");
    icon.className = "depth-chevron";
    icon.setAttribute("aria-hidden", "true");
    btn.appendChild(icon);

    // Stop events from reaching the Cytoscape canvas beneath
    btn.addEventListener("mousedown", (e) => e.stopPropagation());
    btn.addEventListener("pointerdown", (e) => e.stopPropagation());

    btn.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      if (isDepthCollapsed(n)) {
        expandNodeChildren(cy, n);
      } else {
        collapseNodeChildren(cy, n);
      }
      // layoutstop from _relayoutAfterDepthChange will rebuild overlays
    });

    overlay.appendChild(btn);
    cy._depthToggleButtons.set(n.id(), btn);
  });

  _updateDepthTogglePositions(cy);
}

/**
 * Reposition each disclosure control at the node's right-center edge.
 * Called on every Cytoscape render frame so buttons track pan/zoom smoothly.
 */
export function depthTogglePosition(bb) {
  return {
    x: bb.x2 + 8,
    y: (bb.y1 + bb.y2) / 2,
    translateX: "0",
    translateY: "-50%",
  };
}

export function visibilityControlPositions(bb, scale = 1) {
  const inset = 15 * scale;
  const top = bb.y1 + inset;
  const bottom = bb.y2 - inset;
  const minimumSpan = 34 * scale;
  const center = (bb.y1 + bb.y2) / 2;
  const span = Math.max(minimumSpan, bottom - top);

  return {
    x: bb.x2 + 10 * scale,
    focusY: center - span / 2,
    disclosureY: center + span / 2,
    span,
  };
}

function _updateDepthTogglePositions(cy) {
  if (!cy || (typeof cy.destroyed === "function" && cy.destroyed())) {
    return;
  }

  const zoom = typeof cy.zoom === "function" ? cy.zoom() : 1;
  const hideBelowZoom = 0.3;
  const scale = Math.max(0.5, Math.min(1.5, zoom));
  const presentationMode = cy?._ownerHook?.el?.dataset?.presentationMode || "off";

  if (presentationMode === "presenting") {
    if (cy._depthToggleOverlay) {
      cy._depthToggleOverlay.style.display = "none";
    }
    return;
  }

  if (cy._depthToggleOverlay) {
    cy._depthToggleOverlay.style.display =
      cy._focusedBranchId || zoom < hideBelowZoom ? "none" : "";
  }

  const focusControls = cy._focusControls;
  const focusNodeId = focusControls?.dataset?.nodeId;
  const stackedControls = focusControls?.classList.contains(
    "visibility-control-stack",
  );
  const viewportWidth = cy.width();
  const viewportHeight = cy.height();

  cy._depthToggleButtons?.forEach((btn, nodeId) => {
    if (cy._focusedBranchId || zoom < hideBelowZoom) return;
    const node = cy.getElementById(nodeId);
    if (
      !node ||
      node.length === 0 ||
      node.hasClass("depth-hidden") ||
      node.hasClass("focus-hidden") ||
      node.hasClass("hidden")
    ) {
      btn.style.display = "none";
      return;
    }

    const bb = node.renderedBoundingBox({ includeLabels: false });
    if (
      !bb ||
      bb.w === 0 ||
      bb.x2 < -48 ||
      bb.x1 > viewportWidth + 48 ||
      bb.y2 < -48 ||
      bb.y1 > viewportHeight + 48
    ) {
      btn.style.display = "none";
      return;
    }

    // When zoomed far out, the controls become visual noise rather than
    // useful affordances. Hide them entirely below that threshold.
    if (zoom < hideBelowZoom || Math.max(bb.w, bb.h) < 24) {
      btn.style.display = "none";
      return;
    }

    const { x, y, translateX, translateY } = depthTogglePosition(bb);

    btn.style.display = "";
    btn.classList.toggle("depth-control-active", node.hasClass("selected"));
    btn.style.setProperty("--depth-toggle-scale", scale.toFixed(3));
    btn.style.setProperty("--depth-toggle-translate-x", translateX);
    btn.style.setProperty("--depth-toggle-translate-y", translateY);
    if (stackedControls && nodeId === focusNodeId) {
      const pairedPosition = visibilityControlPositions(bb, scale);
      btn.style.left = `${pairedPosition.x}px`;
      btn.style.top = `${pairedPosition.disclosureY}px`;
    } else {
      btn.style.left = `${x}px`;
      btn.style.top = `${y}px`;
    }
  });

  if (focusControls?.classList.contains("graph-clear-focus-controls")) {
    focusControls.style.display = "flex";
    return;
  }

  const focusNode = focusNodeId ? cy.getElementById(focusNodeId) : null;

  if (
    !focusControls ||
    !focusNode ||
    focusNode.length === 0 ||
    focusNode.hasClass("depth-hidden") ||
    focusNode.hasClass("focus-hidden") ||
    focusNode.hasClass("hidden") ||
    zoom < hideBelowZoom
  ) {
    if (focusControls) focusControls.style.display = "none";
    return;
  }

  const focusBounds = focusNode.renderedBoundingBox({ includeLabels: false });
  if (
    !focusBounds ||
    focusBounds.w === 0 ||
    Math.max(focusBounds.w, focusBounds.h) < 24
  ) {
    focusControls.style.display = "none";
    return;
  }

  const focusPosition = visibilityControlPositions(focusBounds, scale);
  focusControls.style.display = "";
  focusControls.style.setProperty("--depth-toggle-scale", scale.toFixed(3));
  focusControls.style.setProperty(
    "--visibility-stack-span",
    `${focusPosition.span / scale}px`,
  );
  focusControls.style.left = `${focusPosition.x}px`;
  focusControls.style.top = `${
    stackedControls ? focusPosition.focusY : (focusBounds.y1 + focusBounds.y2) / 2
  }px`;
}

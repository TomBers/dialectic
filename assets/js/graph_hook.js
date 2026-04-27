import { draw_graph } from "./draw_graph";
import { layoutConfig } from "./layout_config.js";
import { extractListItems } from "./list_detection_hook.js";
import { showToast, copyToClipboard } from "./toast.js";

const layoutGraph = (cy, opts, onDone) => {
  // Back-compat: (cy, onDone)
  if (typeof opts === "function" && onDone === undefined) {
    onDone = opts;
    opts = {};
  }
  try {
    // Stop any in-flight animations to avoid fighting layout animations
    if (cy && typeof cy.stop === "function") {
      cy.stop();
    }
    if (cy.__evMeta) {
      cy.__evMeta.animating = false;
    }
  } catch (_e) {}

  // Determine layout based on view mode
  const viewMode = localStorage.getItem("graph_view_mode") || "spaced";
  const graphDirection = localStorage.getItem("graph_direction") || "TB";
  const baseLayout =
    viewMode === "compact"
      ? layoutConfig.compactLayout
      : layoutConfig.baseLayout;

  // Check for small graph to adjust padding
  const edgeCount = cy.edges().length;
  const isSmallGraph = edgeCount === 1;

  const layoutOptions = {
    ...baseLayout,
    rankDir: graphDirection,
    padding: isSmallGraph ? 200 : baseLayout.padding,
    ...(opts || {}),
  };

  const layout = cy.layout(layoutOptions);

  // Track layout running state on the instance that owns this cy
  try {
    if (layout && typeof layout.one === "function") {
      layout.one("layoutstart", () => {
        if (cy && cy._ownerHook) {
          cy._ownerHook._layoutRunning = true;
        }
        // End any active batch after layout starts to avoid flicker during pre-layout updates
        if (cy && typeof cy.endBatch === "function") {
          try {
            cy.endBatch();
          } catch (_e) {}
        }
      });

      layout.one("layoutstop", () => {
        if (cy && cy._ownerHook) {
          cy._ownerHook._layoutRunning = false;
        }
        if (typeof onDone === "function") {
          // Defer one frame to ensure final positions are committed
          requestAnimationFrame(onDone);
        }
      });
    }
  } catch (_e) {}

  layout.run();
};

const debugBoundsEnabled = () => {
  try {
    if (window.__GRAPH_DEBUG_BOUNDS) return true;
    const v = window.localStorage && localStorage.getItem("graph_debug_bounds");
    return v === "1" || v === "true";
  } catch (_e) {
    return false;
  }
};

const drawDebugBounds = (
  container,
  rect,
  overlap,
  nodeRenderedX,
  nodeRenderedY,
) => {
  try {
    let box = container.querySelector(".graph-debug-bounds");
    if (!box) {
      box = document.createElement("div");
      box.className = "graph-debug-bounds";
      container.appendChild(box);
    }
    Object.assign(box.style, {
      position: "absolute",
      pointerEvents: "none",
      left: "0px",
      top: "0px",
      width: Math.max(0, rect.width - overlap) + "px",
      height: rect.height + "px",
      outline: "2px dashed rgba(255,0,0,0.6)",
      background: "rgba(255,0,0,0.05)",
      zIndex: "9999",
    });

    let edge = container.querySelector(".graph-debug-edge");
    if (!edge) {
      edge = document.createElement("div");
      edge.className = "graph-debug-edge";
      container.appendChild(edge);
    }
    Object.assign(edge.style, {
      position: "absolute",
      pointerEvents: "none",
      left: Math.max(0, rect.width - overlap) + "px",
      top: "0px",
      width: "0px",
      height: rect.height + "px",
      borderLeft: "2px solid rgba(255,0,0,0.6)",
      zIndex: "9999",
    });

    let dot = container.querySelector(".graph-debug-node");
    if (!dot) {
      dot = document.createElement("div");
      dot.className = "graph-debug-node";
      container.appendChild(dot);
    }
    Object.assign(dot.style, {
      position: "absolute",
      pointerEvents: "none",
      width: "8px",
      height: "8px",
      borderRadius: "50%",
      background: "rgba(0,0,255,0.8)",
      transform: "translate(-4px,-4px)",
      left: nodeRenderedX + "px",
      top: nodeRenderedY + "px",
      zIndex: "10000",
    });
  } catch (_e) {}
};

const ensureVisible = (cy, container, nodeId) => {
  try {
    // Defer visibility nudge until after any active layout to avoid pre-layout flicker
    if (cy && cy._ownerHook && cy._ownerHook._layoutRunning) {
      try {
        cy._ownerHook._pendingCenterId = nodeId;
      } catch (_e) {}
      return;
    }

    const n = cy.getElementById(nodeId);
    if (!n || n.length === 0) return;

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
    const getNum = (k, d) => {
      try {
        const v = localStorage.getItem(k);
        if (!v) return d;
        const n = parseFloat(v);
        return Number.isFinite(n) ? n : d;
      } catch (_e) {
        return d;
      }
    };
    const margin = getNum("graph_nudge_margin", 16); // outer margin from container edges
    const deadzone = getNum("graph_nudge_deadzone", 8); // hysteresis to avoid bounce
    const pad = getNum("graph_nudge_pad", 12); // ensure node box + padding is visible

    // Account for the bottom toolbar that overlays the graph canvas
    let bottomOverlap = 0;
    const bottomMenu = document.getElementById("bottom-menu");
    if (bottomMenu) {
      const bmRect = bottomMenu.getBoundingClientRect();
      // Only count it if it's visible (opacity > 0 and intersects the container)
      const isVisible =
        bmRect.height > 0 &&
        !bottomMenu.classList.contains("invisible") &&
        !bottomMenu.classList.contains("opacity-0");
      if (isVisible) {
        bottomOverlap = Math.max(0, rect.bottom - bmRect.top);
      }
    }

    const visLeft = margin;
    const visTop = margin;
    const visRight = Math.max(margin, rect.width - overlap - margin);
    const visBottom = Math.max(margin, rect.height - bottomOverlap - margin);

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

    // Debug dot at node center (rendered)
    const cx = ((bb.x1 + bb.x2) / 2) * zoom + pan.x;
    const cyR = ((bb.y1 + bb.y2) / 2) * zoom + pan.y;
    if (debugBoundsEnabled()) {
      drawDebugBounds(container, rect, overlap, cx, cyR);
    }

    // Minimal pan to bring padded box fully inside ok-bounds
    let dx = 0;
    let dy = 0;

    if (rbbLeft < okLeft) dx = okLeft - rbbLeft;
    else if (rbbRight > okRight) dx = okRight - rbbRight;

    if (rbbTop < okTop) dy = okTop - rbbTop;
    else if (rbbBottom > okBottom) dy = okBottom - rbbBottom;

    if (dx !== 0 || dy !== 0) {
      cy.stop();
      cy.animate({
        pan: { x: pan.x + dx, y: pan.y + dy },
        duration: 150,
        easing: "ease-in-out-quad",
      });
    }
  } catch (_e) {}
};

const graphHook = {
  mounted() {
    const { graph, node, div, graphId } = this.el.dataset;

    const container =
      this.el.querySelector(`#${div}`) || document.getElementById(div);

    // Get view mode from localStorage or default to "spaced"
    const viewMode = localStorage.getItem("graph_view_mode") || "spaced";
    const graphDirection = localStorage.getItem("graph_direction") || "TB";

    this.cy = draw_graph(
      container,
      this,
      JSON.parse(graph),
      node,
      viewMode,
      graphId,
    );

    // Track view mode and direction for detecting changes
    this._lastViewMode = viewMode;
    this._lastGraphDirection = graphDirection;

    // Store container reference for reinitializing
    this._container = container;

    // Link back so layoutGraph can update running state
    try {
      this.cy._ownerHook = this;
    } catch (_e) {}

    // Initial update
    this._updateExploredStatus();

    this.handleEvent("request_screenshot", () => {
      if (this.cy) {
        const stateSelected = this.cy.$(":selected");
        const classSelected = this.cy.$(".selected");

        stateSelected.unselect();
        classSelected.removeClass("selected");

        setTimeout(() => {
          if (!this.cy) return;
          const png = this.cy.png({
            output: "base64uri",
            full: true,
            scale: 1.5,
            bg: "white",
          });

          stateSelected.select();
          classSelected.addClass("selected");
          this.pushEvent("save_screenshot", { image: png });
        }, 200);
      }
    });

    // Handle view mode changes from client-side toggle via custom DOM event
    // Handle view mode changes via custom event
    this._onViewModeChange = (e) => {
      const currentViewMode = e.detail.view_mode || "spaced";

      if (this._lastViewMode === currentViewMode) return;

      const currentNode = this.el.dataset.node;
      const graph = this.el.dataset.graph;

      this._handleViewModeChange(currentViewMode, graph, currentNode);
    };

    this.el.addEventListener("viewModeChanged", this._onViewModeChange);

    // Handle graph direction changes via custom event
    this._onGraphDirectionChange = (e) => {
      const newDirection = e.detail.direction || "TB";

      if (this._lastGraphDirection === newDirection) return;

      const currentNode = this.el.dataset.node;
      const graph = this.el.dataset.graph;

      this._handleGraphDirectionChange(newDirection);
    };

    this.el.addEventListener(
      "graphDirectionChanged",
      this._onGraphDirectionChange,
    );

    // Layout/centering coordination state
    // The initial cy.layout().run() in draw_graph is already in flight by this
    // point, so start as true. A one-shot layoutstop listener flips it back
    // once the initial layout finishes. This ensures that deferred operations
    // (e.g. presentation_filter_graph from a shared link) wait correctly.
    this._layoutRunning = true;
    this.cy.one("layoutstop", () => {
      this._layoutRunning = false;
    });
    this._pendingCenterId = null;
    this._centerOnNodeVisible = (id) => {
      try {
        const n = this.cy.getElementById(id);
        if (!n || n.length === 0) return;

        // Keep structure stable: only pan if the node is off screen
        // Compute visible bounds (exclude right panel) with small margins
        requestAnimationFrame(() => ensureVisible(this.cy, container, id));
      } catch (_e) {}
    };

    // Prevent Enter shortcut from firing while typing in inputs/textareas/contenteditable
    this._enterStopper = (e) => {
      if (e.key === "Enter") {
        const t = e.target;
        const tag = (t && t.tagName) || "";
        const isEditable =
          tag === "INPUT" ||
          tag === "TEXTAREA" ||
          (t &&
            (t.isContentEditable ||
              t.closest('[contenteditable="true"], [contenteditable=""]')));
        if (isEditable) {
          // Allow default behavior (submit/newline) but stop bubbling to LiveView shortcut
          e.stopPropagation();
        }
      }
    };
    // Use capture phase to intercept before LiveView's phx-keydown on container
    this.el.addEventListener("keydown", this._enterStopper, true);

    // Window-level keydown filter: block Enter when typing (LiveView handles opening)
    this._windowKeydown = (e) => {
      if (e.key !== "Enter") return;

      const t = e.target;
      const tag = (t && t.tagName) || "";
      const isEditable =
        tag === "INPUT" ||
        tag === "TEXTAREA" ||
        (t &&
          (t.isContentEditable ||
            t.closest('[contenteditable="true"], [contenteditable=""]')));

      if (isEditable) {
        e.stopPropagation();
      }
    };
    window.addEventListener("keydown", this._windowKeydown, true);

    // Zoom controls (+ / − / Fit)
    // Debug: keep bounds overlay in sync with pan/zoom/render
    this._debugRedraw = () => {
      try {
        const currentId = this.el.dataset.node;
        if (!currentId) return;
        if (!debugBoundsEnabled()) return;

        const rect = this._container.getBoundingClientRect();
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

        const n = this.cy.getElementById(currentId);
        if (!n || n.length === 0) return;

        const zoom = this.cy.zoom();
        const pan = this.cy.pan();
        const m = n.position();
        const rx = m.x * zoom + pan.x;
        const ry = m.y * zoom + pan.y;

        drawDebugBounds(this._container, rect, overlap, rx, ry);
      } catch (_e) {}
    };
    if (this.cy && typeof this.cy.on === "function") {
      this.cy.on("pan zoom render", this._debugRedraw);
    }
    const clamp = (val, min, max) => Math.max(min, Math.min(max, val));
    this._zoomToast = this._zoomToast || null;
    this._zoomToastTimer = this._zoomToastTimer || null;

    const showZoom = () => {
      if (!this._zoomToast) {
        this._zoomToast = document.createElement("div");
        this._zoomToast.style.position = "absolute";
        this._zoomToast.style.right = "12px";
        this._zoomToast.style.bottom = "48px";
        this._zoomToast.style.padding = "2px 6px";
        this._zoomToast.style.background = "rgba(0,0,0,0.65)";
        this._zoomToast.style.color = "#fff";
        this._zoomToast.style.fontSize = "12px";
        this._zoomToast.style.borderRadius = "4px";
        this._zoomToast.style.pointerEvents = "none";
        this._zoomToast.style.transition = "opacity 150ms ease";
        container.appendChild(this._zoomToast);
      }
      this._zoomToast.textContent = Math.round(this.cy.zoom() * 100) + "%";
      this._zoomToast.style.opacity = "1";
      if (this._zoomToastTimer) clearTimeout(this._zoomToastTimer);
      this._zoomToastTimer = setTimeout(
        () => (this._zoomToast.style.opacity = "0"),
        900,
      );
    };

    const getRightPanelWidth = () => {
      const panels = ["right-panel", "highlights-drawer"];
      let maxWidth = 0;
      panels.forEach((id) => {
        const panel = document.getElementById(id);
        if (panel) {
          const rect = panel.getBoundingClientRect();
          if (rect && rect.width > 10 && rect.left < window.innerWidth) {
            if (rect.width > maxWidth) maxWidth = rect.width;
          }
        }
      });
      return maxWidth;
    };

    const centerPoint = () => {
      const rect = container.getBoundingClientRect();
      const rightPanelWidth = getRightPanelWidth();
      // Center within the visible area (container minus right panel width)
      return {
        x: Math.max(0, (rect.width - rightPanelWidth) / 2),
        y: rect.height / 2,
      };
    };

    const zoomBy = (factor) => {
      const current = this.cy.zoom();
      const next = clamp(
        current * factor,
        layoutConfig.zoomSettings.min || 0.05,
        layoutConfig.zoomSettings.max || 4.0,
      );
      this.cy.zoom({ level: next, renderedPosition: centerPoint() });
      showZoom();
    };

    const fitGraph = () => {
      // First center to all elements as before
      this.cy.animate({
        center: { eles: this.cy.elements() },
        duration: 150,
        easing: "ease-in-out-quad",
      });

      // Then offset horizontally so the centered content lands in the visible area, not under the right panel
      const rect = container.getBoundingClientRect();
      const rightPanelWidth = getRightPanelWidth();
      const deltaX = rightPanelWidth > 0 ? -(rightPanelWidth / 2) : 0;

      if (deltaX !== 0) {
        this.cy.animate({
          panBy: { x: deltaX, y: 0 },
          duration: 150,
          easing: "ease-in-out-quad",
        });
      }

      requestAnimationFrame(showZoom);
    };

    const btnPngs = Array.from(document.querySelectorAll(".download-png"));
    const btnIn = document.getElementById("zoom-in");
    const btnOut = document.getElementById("zoom-out");
    const btnFit = document.getElementById("zoom-fit");

    if (btnIn) {
      this._btnInEl = btnIn;
      this._btnInHandler = (e) => {
        e.preventDefault();
        e.stopPropagation();
        zoomBy(1.2);
      };
      btnIn.addEventListener("click", this._btnInHandler);
    }
    if (btnOut) {
      this._btnOutEl = btnOut;
      this._btnOutHandler = (e) => {
        e.preventDefault();
        e.stopPropagation();
        zoomBy(1 / 1.2);
      };
      btnOut.addEventListener("click", this._btnOutHandler);
    }
    if (btnFit) {
      this._btnFitEl = btnFit;
      this._btnFitHandler = (e) => {
        e.preventDefault();
        e.stopPropagation();
        fitGraph();
      };
      btnFit.addEventListener("click", this._btnFitHandler);
    }
    // Shared PNG export helpers and button binding
    if (!this._exportGraphPng) {
      this._exportGraphPng = () => {
        try {
          const dataUrl = this.cy.png({
            full: true,
            scale: window.devicePixelRatio || 2,
            bg: "#ffffff",
          });

          const ts = new Date().toISOString().replace(/[:.]/g, "-");
          const a = document.createElement("a");
          a.href = dataUrl;
          a.download = `graph-full-${ts}.png`;
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
        } catch (_e) {
          // no-op
        }
      };
    }

    if (!this._exportPngHandler) {
      this._exportPngHandler = (e) => {
        e.preventDefault();
        e.stopPropagation();
        this._exportGraphPng();
      };
    }

    // Bind PNG buttons explicitly (supports dynamic additions via updated())
    if (!this._bindPngButtons) {
      this._bindPngButtons = () => {
        const buttons = Array.from(document.querySelectorAll(".download-png"));
        if (!Array.isArray(this._btnPngHandlers)) this._btnPngHandlers = [];
        const bound = new Set(this._btnPngHandlers.map(([el]) => el));
        buttons.forEach((btn) => {
          if (bound.has(btn)) return;
          btn.addEventListener("click", this._exportPngHandler);
          this._btnPngHandlers.push([btn, this._exportPngHandler]);
        });
      };
    }
    this._bindPngButtons();

    this._viewportResizePending = false;
    this._onViewportResize = () => {
      if (this._viewportResizePending) return;

      this._viewportResizePending = true;
      requestAnimationFrame(() => {
        this._viewportResizePending = false;
        if (!this.cy) return;

        try {
          this.cy.resize();
        } catch (_e) {}

        if (typeof this.cy.scheduleViewportClamp === "function") {
          this.cy.scheduleViewportClamp({ immediate: true });
        }

        if (this._presentationIds && this._presentationIds.length > 0) {
          this._renderPresentationBadges();
        }
      });
    };
    window.addEventListener("resize", this._onViewportResize);
    this._onViewportResize();

    // Handle incremental label updates for streaming titles without full graph reloads
    this.handleEvent("update_node_label", ({ id, label }) => {
      try {
        if (!id) return;
        const n =
          this.cy && typeof this.cy.getElementById === "function"
            ? this.cy.getElementById(id)
            : null;
        if (!n || n.length === 0) return;

        // Update the underlying content data so size calculations are triggered
        const currentContent = n.data("content") || "";
        const lines = currentContent.split("\n");

        const newLabel = String(label || "");
        const newContent =
          lines.length > 0
            ? [newLabel, ...lines.slice(1)].join("\n")
            : newLabel;

        // Only update if content has actually changed to avoid unnecessary rerenders
        if (currentContent === newContent) return;

        // Check if this is the first time we're setting a meaningful title
        // (transition from empty/placeholder to actual content)
        const currentTitle = lines.length > 0 ? lines[0].trim() : "";
        const isFirstTitleSet = !currentTitle && newLabel.trim().length > 0;

        // Track if we've already reflowed for this node
        if (!this._reflowedNodes) this._reflowedNodes = new Set();
        const needsReflow = isFirstTitleSet && !this._reflowedNodes.has(id);

        // Batch updates to prevent multiple redraws
        if (this.cy && typeof this.cy.startBatch === "function") {
          this.cy.startBatch();
        }

        // Update content data (this triggers style function recalculation)
        n.data("content", newContent);

        // End batch to apply changes once
        if (this.cy && typeof this.cy.endBatch === "function") {
          this.cy.endBatch();
        }

        // Reflow the graph when title is first set to prevent node overlapping
        if (needsReflow) {
          this._reflowedNodes.add(id);

          // Use a small delay to ensure size calculations are complete
          setTimeout(() => {
            if (this.cy && typeof layoutGraph === "function") {
              layoutGraph(this.cy, { animate: true });
            }
          }, 50);
        }
      } catch (_e) {
        // no-op
      }
    });

    // Listen for the center_node event from LiveView
    this.handleEvent("center_node", ({ id }) => {
      try {
        // Update selected highlighting to reflect the newly selected node
        this.cy.elements().removeClass("selected");
        const nodeToCenter = this.cy.getElementById(id);
        if (nodeToCenter.length > 0) {
          // Track whether we need a full reflow
          let needsReflow = false;

          // If the node is inside a collapsed compound group, expand it
          if (
            nodeToCenter.hasClass("hidden") &&
            typeof this.cy.ensureGroupVisible === "function"
          ) {
            needsReflow = this.cy.ensureGroupVisible(id) || needsReflow;
          }
          // If the node is depth-hidden, expand its ancestors to make it visible
          if (
            nodeToCenter.hasClass("depth-hidden") &&
            typeof this.cy.ensureDepthVisible === "function"
          ) {
            this.cy.ensureDepthVisible(id);
            needsReflow = true;
          }
          nodeToCenter.addClass("selected");

          // Keep the dataset in sync so other consumers (and hooks) can rely on it
          this.el.dataset.node = id;
          if (this._debugRedraw) this._debugRedraw();

          // If we expanded a group or depth-hidden ancestors, run a full
          // reflow through layoutGraph so nodes don't overlap, then center.
          if (needsReflow) {
            this._pendingCenterId = id;
            this._layoutRunning = true;
            layoutGraph(this.cy, {}, () => {
              this._pendingCenterId = null;
              // Force Cytoscape to recalculate all styles and re-render
              // node textures so that text on newly-expanded parents
              // isn't blurry from stale cached label bitmaps.
              try {
                this.cy.style().update();
              } catch (_e) {}
              requestAnimationFrame(() =>
                ensureVisible(this.cy, container, id),
              );
              if (this._updateExploredStatus) this._updateExploredStatus();
            });
            return;
          }

          // If a layout is in progress, defer the visibility nudge until after layoutstop
          if (this._layoutRunning) {
            this._pendingCenterId = id;
            return;
          }

          // Only pan if the node is outside the visible area (preserve existing layout)
          requestAnimationFrame(() => ensureVisible(this.cy, container, id));

          if (this._updateExploredStatus) this._updateExploredStatus();
        }
      } catch (_e) {
        // no-op, avoid breaking on transient DOM/cy states
      }
    });

    // Ensure Explore button is bound on first mount
    (function bindExploreOnMount() {
      const btn = document.getElementById("explore-all-points");
      if (!btn) return;

      if (!this._exploreClickHandler) {
        this._exploreClickHandler = (e) => {
          e.preventDefault();
          e.stopPropagation();

          const currentNodeId = this.el.dataset.node;

          // Prefer detector dataset if present
          const detector = document.getElementById(
            `list-detector-${currentNodeId}`,
          );
          const items = extractListItems(detector);

          this.pushEvent("open_explore_modal", { items });
        };
      }

      if (this._exploreBtnEl !== btn) {
        if (this._exploreBtnEl && this._exploreClickHandler) {
          this._exploreBtnEl.removeEventListener(
            "click",
            this._exploreClickHandler,
          );
        }
        btn.addEventListener("click", this._exploreClickHandler);
        this._exploreBtnEl = btn;
      }
    }).call(this);

    // ── Search highlighting on graph ──
    // When the server pushes matching node IDs, highlight them on the
    // Cytoscape canvas and dim everything else so matches pop out.
    this.handleEvent("highlight_search_results", ({ ids }) => {
      if (!this.cy) return;
      try {
        // Remove any previous search highlighting
        this.cy.elements().removeClass("search-match search-dimmed");

        if (!ids || ids.length === 0) return;

        const idSet = new Set(ids);
        const allNodes = this.cy.nodes().filter((n) => !n.data("compound"));
        let needsReflow = false;

        allNodes.forEach((n) => {
          if (idSet.has(n.id())) {
            n.addClass("search-match");
            // If the node is depth-hidden or group-hidden, reveal it
            if (
              n.hasClass("depth-hidden") &&
              typeof this.cy.ensureDepthVisible === "function"
            ) {
              this.cy.ensureDepthVisible(n.id());
              needsReflow = true;
            }
            if (
              n.hasClass("hidden") &&
              typeof this.cy.ensureGroupVisible === "function"
            ) {
              if (this.cy.ensureGroupVisible(n.id())) {
                needsReflow = true;
              }
            }
          } else {
            n.addClass("search-dimmed");
          }
        });

        // Also dim edges that don't connect two matched nodes
        this.cy.edges().forEach((e) => {
          const srcMatch = idSet.has(e.source().id());
          const tgtMatch = idSet.has(e.target().id());
          if (srcMatch || tgtMatch) {
            e.addClass("search-match");
          } else {
            e.addClass("search-dimmed");
          }
        });

        // If we expanded any collapsed/depth-hidden nodes, run a full
        // reflow so they don't overlap, then refresh styles.
        if (needsReflow) {
          this._layoutRunning = true;
          layoutGraph(this.cy, {}, () => {
            this._layoutRunning = false;
            try {
              this.cy.style().update();
            } catch (_e) {}
            if (this._updateExploredStatus) this._updateExploredStatus();
          });
        }
      } catch (_e) {}
    });

    // Reposition presentation badges when the viewport changes
    if (this.cy) {
      if (!this._onCyPanZoom) {
        this._onCyPanZoom = () => {
          if (
            this._presentationIds &&
            this._presentationIds.length > 0 &&
            !this._panZoomPending
          ) {
            this._panZoomPending = true;
            requestAnimationFrame(() => {
              this._panZoomPending = false;
              this._renderPresentationBadges();
            });
          }
        };
      }
      // Avoid duplicate bindings if this code runs multiple times
      this.cy.off("pan zoom", this._onCyPanZoom);
      this.cy.on("pan zoom", this._onCyPanZoom);
    }

    this.handleEvent("clear_search_highlights", () => {
      if (!this.cy) return;
      try {
        this.cy.elements().removeClass("search-match search-dimmed");
      } catch (_e) {}
    });

    // ── Presentation mode: highlight nodes in the slide deck ──
    this.handleEvent("presentation_highlight_slides", ({ ids }) => {
      if (!this.cy) return;
      try {
        // Remove previous presentation markers
        this.cy.nodes().removeClass("presentation-slide");
        this.cy.nodes().forEach((n) => n.removeData("presIndex"));

        // Remove old badge overlays
        if (this._badgeElements) {
          this._badgeElements.forEach((el) => el.remove());
          this._badgeElements.clear();
        }

        if (!ids || ids.length === 0) return;

        // Store the ordered list so we can render badges after layout
        this._presentationIds = ids;

        ids.forEach((id, idx) => {
          const n = this.cy.getElementById(id);
          if (n && n.length > 0) {
            n.addClass("presentation-slide");
            n.data("presIndex", idx + 1);
          }
        });

        // Render numbered badge overlays positioned on each node
        this._renderPresentationBadges();
      } catch (_e) {}
    });

    this.handleEvent("presentation_clear_slides", () => {
      if (!this.cy) return;
      try {
        this.cy.nodes().removeClass("presentation-slide");
        this.cy.nodes().forEach((n) => n.removeData("presIndex"));
        this._presentationIds = null;
        if (this._badgeElements) {
          this._badgeElements.forEach((el) => el.remove());
          this._badgeElements.clear();
        }
      } catch (_e) {}
    });

    // ── Presentation filter: hide all nodes NOT in the selected set ──
    this.handleEvent("presentation_filter_graph", ({ ids }) => {
      if (!this.cy) return;

      const applyFilter = () => {
        try {
          this._presentationIds = ids;
          this._presentationFiltered = true;
          this._applyPresentationFilter();

          // Re-layout only the visible nodes so they spread out and fill the screen
          this._layoutRunning = true;
          layoutGraph(this.cy, {}, () => {
            this._layoutRunning = false;
            try {
              this.cy.style().update();
            } catch (_e) {}
            // After layout, fit viewport to the visible nodes
            const visibleNodes = this.cy
              .nodes()
              .not(".presentation-hidden")
              .not(".presentation-hidden-parent");
            if (visibleNodes.length > 0) {
              this.cy.animate({
                fit: { eles: visibleNodes, padding: 60 },
                duration: 400,
                easing: "ease-in-out-quad",
                complete: () => {
                  const { dx, dy } = this._getOverlayOffsets();
                  if (dx !== 0 || dy !== 0) {
                    this.cy.animate({
                      panBy: { x: dx, y: dy },
                      duration: 200,
                      easing: "ease-in-out-quad",
                    });
                  }
                },
              });
            }
          });
        } catch (_e) {}
      };

      // If the initial layout is still running (e.g. shared presentation link
      // where handle_params fires right after mount), defer the filter until
      // layout finishes so nodes are properly positioned first.
      if (this._layoutRunning) {
        this.cy.one("layoutstop", () => applyFilter());
      } else {
        applyFilter();
      }
    });

    // ── Presentation unfilter: restore all hidden nodes and edges ──
    this.handleEvent("presentation_unfilter_graph", () => {
      if (!this.cy) return;
      try {
        this.cy.startBatch();
        this.cy.elements().removeClass("presentation-hidden");
        this.cy.elements().removeClass("presentation-hidden-parent");
        this.cy.nodes().removeClass("presentation-slide");
        this.cy.nodes().forEach((n) => n.removeData("presIndex"));
        this.cy.endBatch();

        this._presentationFiltered = false;
        this._presentationIds = null;

        // Remove badge overlays
        if (this._badgeElements) {
          this._badgeElements.forEach((el) => el.remove());
          this._badgeElements.clear();
        }

        // Re-layout to restore original positions, then fit
        this._layoutRunning = true;
        layoutGraph(this.cy, {}, () => {
          this._layoutRunning = false;
          try {
            this.cy.style().update();
          } catch (_e) {}
          if (this.cy.nodes().length > 0) {
            this.cy.animate({
              fit: { eles: this.cy.nodes(), padding: 40 },
              duration: 400,
              easing: "ease-in-out-quad",
              complete: () => {
                const { dx, dy } = this._getOverlayOffsets();
                if (dx !== 0 || dy !== 0) {
                  this.cy.animate({
                    panBy: { x: dx, y: dy },
                    duration: 200,
                    easing: "ease-in-out-quad",
                  });
                }
              },
            });
          }
        });
      } catch (_e) {}
    });

    // ── Combine mode: highlight selected nodes ──
    this.handleEvent("combine_highlight_nodes", ({ ids }) => {
      if (!this.cy) return;
      try {
        // Remove previous combine markers
        this.cy.nodes().removeClass("combine-selected");

        if (!ids || ids.length === 0) return;

        ids.forEach((id) => {
          const n = this.cy.getElementById(id);
          if (n && n.length > 0) {
            n.addClass("combine-selected");
          }
        });
      } catch (_e) {}
    });

    this.handleEvent("combine_clear_highlights", () => {
      if (!this.cy) return;
      try {
        this.cy.nodes().removeClass("combine-selected");
      } catch (_e) {}
    });

    // ── Copy to clipboard: used by "Copy link" in presentation bar ──
    this.handleEvent("copy_to_clipboard", ({ text }) => {
      copyToClipboard(text).then(() => {
        showToast("Copied to clipboard!", { id: "graph-copied-toast" });
      });
    });
  },

  /**
   * Compute pan offsets to compensate for right-panel and bottom-menu overlays.
   * Returns { dx, dy } suitable for passing to cy.animate({ panBy: … }).
   */
  _getOverlayOffsets() {
    const container = this._container || this.el;
    const cRect = container.getBoundingClientRect();
    let dx = 0;
    let dy = 0;

    // Right panel compensation
    const panelIds = ["right-panel", "highlights-drawer"];
    let rightPanelWidth = 0;
    panelIds.forEach((id) => {
      const p = document.getElementById(id);
      if (p) {
        const pr = p.getBoundingClientRect();
        if (pr && pr.width > 10 && pr.left < window.innerWidth) {
          if (pr.width > rightPanelWidth) rightPanelWidth = pr.width;
        }
      }
    });
    if (rightPanelWidth > 0) dx = -(rightPanelWidth / 2);

    // Bottom menu compensation
    const bottomMenu = document.getElementById("bottom-menu");
    if (bottomMenu) {
      const bmRect = bottomMenu.getBoundingClientRect();
      const bmVisible =
        bmRect.height > 0 &&
        !bottomMenu.classList.contains("invisible") &&
        !bottomMenu.classList.contains("opacity-0");
      if (bmVisible) {
        const overlap = Math.max(0, cRect.bottom - bmRect.top);
        if (overlap > 0) dy = -(overlap / 2);
      }
    }

    return { dx, dy };
  },

  /**
   * Applies the presentation filter: hides nodes not in the selected set,
   * preserves compound parents of visible nodes, and hides orphaned edges.
   * Called both from the initial filter event and after cy.json() reloads.
   */
  _applyPresentationFilter() {
    if (!this.cy || !this._presentationIds) return;
    const ids = this._presentationIds;
    const idSet = new Set(ids);

    // First, ensure selected nodes are not stuck in depth-hidden or
    // collapsed-group states — otherwise they'll remain invisible even
    // after we remove presentation-hidden.
    let needsReflow = false;
    ids.forEach((id) => {
      const n = this.cy.getElementById(id);
      if (!n || n.length === 0) return;

      if (
        n.hasClass("depth-hidden") &&
        typeof this.cy.ensureDepthVisible === "function"
      ) {
        this.cy.ensureDepthVisible(id);
        needsReflow = true;
      }
      if (
        n.hasClass("hidden") &&
        typeof this.cy.ensureGroupVisible === "function"
      ) {
        if (this.cy.ensureGroupVisible(id)) {
          needsReflow = true;
        }
      }
    });

    // Collect compound parents of every selected node so we
    // don't accidentally hide a parent that contains visible children.
    const keepParentIds = new Set();
    ids.forEach((id) => {
      const n = this.cy.getElementById(id);
      if (n && n.length > 0) {
        let p = n.parent();
        while (p && p.length > 0) {
          keepParentIds.add(p.id());
          p = p.parent();
        }
      }
    });

    this.cy.startBatch();

    this.cy.nodes().forEach((n) => {
      if (idSet.has(n.id())) {
        n.removeClass("presentation-hidden");
        n.removeClass("presentation-hidden-parent");
        n.addClass("presentation-slide");
      } else if (n.data("compound") || keepParentIds.has(n.id())) {
        // Compound group that contains a visible child — keep it
        // structurally present (so children render) but visually hidden
        // (no border, no background, no label).
        n.removeClass("presentation-hidden");
        n.removeClass("presentation-slide");
        n.addClass("presentation-hidden-parent");
      } else {
        n.addClass("presentation-hidden");
        n.removeClass("presentation-slide");
        n.removeClass("presentation-hidden-parent");
      }
    });

    this.cy.edges().forEach((e) => {
      const srcVisible =
        idSet.has(e.source().id()) || keepParentIds.has(e.source().id());
      const tgtVisible =
        idSet.has(e.target().id()) || keepParentIds.has(e.target().id());
      if (srcVisible && tgtVisible) {
        e.removeClass("presentation-hidden");
      } else {
        e.addClass("presentation-hidden");
      }
    });

    this.cy.endBatch();

    this._renderPresentationBadges();

    // If we expanded any collapsed/depth-hidden nodes, run a reflow
    // so the revealed nodes get proper positions.
    if (needsReflow) {
      layoutGraph(this.cy, {}, () => {
        try {
          this.cy.style().update();
        } catch (_e) {}
      });
    }
  },

  _renderPresentationBadges() {
    if (!this.cy || !this._presentationIds) return;
    const container = this._container || this.el;

    if (!this._badgeElements) {
      this._badgeElements = new Map();
    }

    // Track which ids are currently active so we can remove stale ones
    const activeIds = new Set(this._presentationIds);

    // Remove stale badges (ids no longer in _presentationIds)
    for (const [id, el] of this._badgeElements) {
      if (!activeIds.has(id)) {
        el.remove();
        this._badgeElements.delete(id);
      }
    }

    this._presentationIds.forEach((id, idx) => {
      const n = this.cy.getElementById(id);
      if (!n || n.length === 0) return;

      const bb = n.renderedBoundingBox({ includeLabels: false });

      let badge = this._badgeElements.get(id);
      if (badge) {
        // Reuse existing badge – only update position and text
        badge.style.top = `${bb.y1 - 8}px`;
        badge.style.left = `${bb.x2 - 8}px`;
        badge.textContent = String(idx + 1);
      } else {
        // Create a new badge element
        badge = document.createElement("div");
        badge.className = "pres-badge-overlay";
        badge.textContent = String(idx + 1);
        badge.style.cssText = `
          position: absolute;
          top: ${bb.y1 - 8}px;
          left: ${bb.x2 - 8}px;
          width: 20px;
          height: 20px;
          border-radius: 50%;
          background: #a855f7;
          color: white;
          font-size: 10px;
          font-weight: 700;
          display: flex;
          align-items: center;
          justify-content: center;
          pointer-events: none;
          z-index: 10;
          box-shadow: 0 1px 3px rgba(0,0,0,0.3);
          line-height: 1;
        `;
        container.appendChild(badge);
        this._badgeElements.set(id, badge);
      }
    });
  },

  _handleViewModeChange(currentViewMode, graphStr, currentNode) {
    // Store the current zoom and pan
    const zoom = this.cy ? this.cy.zoom() : 1;
    const pan = this.cy ? this.cy.pan() : { x: 0, y: 0 };

    // Destroy the old instance
    if (this.cy) {
      try {
        this.cy.destroy();
      } catch (_e) {}
    }

    // Recreate with new view mode
    const graphId = this.el.dataset.graphId;
    this.cy = draw_graph(
      this._container,
      this,
      JSON.parse(graphStr),
      currentNode,
      currentViewMode,
      graphId,
    );

    // Restore zoom and pan
    if (this.cy) {
      try {
        this.cy.zoom(zoom);
        this.cy.pan(pan);
        this.cy._ownerHook = this;
        if (typeof this.cy.scheduleViewportClamp === "function") {
          this.cy.scheduleViewportClamp({ immediate: true });
        }
      } catch (_e) {}
    }

    // Update tracked view mode and direction
    this._lastViewMode = currentViewMode;
    this._lastGraphDirection = localStorage.getItem("graph_direction") || "TB";

    // Re-bind all event handlers and update state
    if (this._updateExploredStatus) this._updateExploredStatus();
    if (this._bindPngButtons) this._bindPngButtons();

    // Re-bind presentation badge tracking on the new cy instance
    if (this.cy && this._onCyPanZoom) {
      this.cy.off("pan zoom", this._onCyPanZoom);
      this.cy.on("pan zoom", this._onCyPanZoom);
    }

    // Re-apply presentation filter if it was active
    if (this._presentationFiltered && this._presentationIds) {
      try {
        this._applyPresentationFilter();
      } catch (_e) {}
    }

    // Highlight the selected node
    if (this.cy && currentNode) {
      this.cy.elements().removeClass("selected");
      this.cy.getElementById(currentNode).addClass("selected");
    }
  },

  _handleGraphDirectionChange(newDirection) {
    // Store the current zoom and pan
    const zoom = this.cy ? this.cy.zoom() : 1;
    const pan = this.cy ? this.cy.pan() : { x: 0, y: 0 };

    // Simply re-layout with the new direction
    if (this.cy) {
      // Re-evaluate style function mappers (e.g. compound label position)
      try {
        this.cy.style().update();
      } catch (_e) {}

      layoutGraph(this.cy, {}, () => {
        // Restore zoom and pan after layout
        try {
          this.cy.zoom(zoom);
          this.cy.pan(pan);
          if (typeof this.cy.scheduleViewportClamp === "function") {
            this.cy.scheduleViewportClamp({ immediate: true });
          }
        } catch (_e) {}

        // Update tracked direction AFTER layout completes successfully
        this._lastGraphDirection = newDirection;
      });
    }
  },

  _updateExploredStatus() {
    try {
      const graphId = this.el.dataset.graphId;
      if (!graphId) return;

      const storageKey = `dialectic_explored_${graphId}`;
      let explored = new Set();
      try {
        const stored = localStorage.getItem(storageKey);
        if (stored) {
          JSON.parse(stored).forEach((id) => explored.add(id));
        }
      } catch (e) {}

      // Mark current node as explored
      const currentNodeId = this.el.dataset.node;
      if (currentNodeId) {
        if (!explored.has(currentNodeId)) {
          explored.add(currentNodeId);
          localStorage.setItem(storageKey, JSON.stringify([...explored]));
        }
      }

      // Apply visual state & update progress
      if (this.cy) {
        // Styles simplified: removed 'explored' class application

        // Calculate progress (exclude compound parents)
        const realNodes = this.cy.nodes().filter((n) => !n.isParent());
        const total = realNodes.length;
        const exploredCount = realNodes.filter((n) =>
          explored.has(n.id()),
        ).length;

        // Only send progress update if values have changed (debounce)
        if (
          !this._lastProgress ||
          this._lastProgress.explored !== exploredCount ||
          this._lastProgress.total !== total
        ) {
          this.pushEvent("update_exploration_progress", {
            explored: exploredCount,
            total: total,
          });
          this._lastProgress = { explored: exploredCount, total: total };
        }
      }
    } catch (e) {
      // no-op
    }
  },

  updated() {
    const { graph, node, operation } = this.el.dataset;

    // Check if view mode has changed (read from localStorage)
    const currentViewMode = localStorage.getItem("graph_view_mode") || "spaced";
    const viewModeChanged = this._lastViewMode !== currentViewMode;

    if (viewModeChanged) {
      this._handleViewModeChange(currentViewMode, graph, node);
      this._lastGraphStr = graph;

      return;
    }

    // Avoid reloading Cytoscape if the graph JSON hasn't changed to reduce flicker
    const graphStr = graph;
    const sameGraph = this._lastGraphStr === graphStr;
    if (!sameGraph) this._lastGraphStr = graphStr;

    if (!sameGraph) {
      // Save depth-collapse state before replacing elements
      let savedDepthState = null;
      if (this.cy && typeof this.cy.saveDepthCollapseState === "function") {
        try {
          savedDepthState = this.cy.saveDepthCollapseState();
        } catch (_e) {}
      }

      if (this.cy && typeof this.cy.startBatch === "function")
        this.cy.startBatch();
      if (this.cy && typeof this.cy.scratch === "function") {
        try {
          this.cy.scratch("_bulkReload", true);
        } catch (_e) {}
      }
      this.cy.json({ elements: JSON.parse(graphStr) });
      if (this.cy && typeof this.cy.scratch === "function") {
        try {
          this.cy.scratch("_bulkReload", null);
        } catch (_e) {}
      }
      if (typeof this.cy.enforceCollapsedState === "function") {
        this.cy.enforceCollapsedState();
      }

      // Restore depth-collapse state after element reload
      if (
        savedDepthState &&
        Object.keys(savedDepthState).length > 0 &&
        typeof this.cy.restoreDepthCollapseState === "function"
      ) {
        try {
          this.cy.restoreDepthCollapseState(savedDepthState);
        } catch (_e) {}
      }
    }

    // Re-apply presentation filter after element reload so hidden nodes stay hidden
    if (!sameGraph && this._presentationFiltered && this._presentationIds) {
      try {
        this._applyPresentationFilter();
      } catch (_e) {}
    }

    if (this._updateExploredStatus) this._updateExploredStatus();

    // Defer endBatch until after layout starts or after the no-layout path below

    // Operations that should reflow without animation to reduce flicker
    const noAnimateOperations = new Set([
      "explain",
      "branch",
      "ideas",
      "deepdive",
      "comment",
      "answer",
      "combine",
    ]);
    let layoutScheduled = false;

    if (!sameGraph && operation === "start_stream") {
      // Reflow the graph and then ensure the newly created node is visible (deferred until layout completes)
      // Compute a safe pending center id (must be a non-empty string)
      const nextPendingId =
        (typeof node === "string" && node.length > 0 && node) ||
        (this.el &&
          this.el.dataset &&
          typeof this.el.dataset.node === "string" &&
          this.el.dataset.node.length > 0 &&
          this.el.dataset.node) ||
        this._pendingCenterId;
      this._pendingCenterId = nextPendingId;
      this._layoutRunning = true;
      layoutScheduled = true;
      // Keep animation for start_stream
      layoutGraph(this.cy, {}, () => {
        const targetId =
          (typeof this._pendingCenterId === "string" &&
            this._pendingCenterId.length > 0 &&
            this._pendingCenterId) ||
          (this.el &&
            this.el.dataset &&
            typeof this.el.dataset.node === "string" &&
            this.el.dataset.node.length > 0 &&
            this.el.dataset.node) ||
          null;
        this._pendingCenterId = null;
        if (targetId) {
          requestAnimationFrame(() =>
            ensureVisible(this.cy, this._container, targetId),
          );
        }
      });
    } else if (!sameGraph) {
      // Some operations reorder elements; defer ensureVisible until layout finishes
      this._pendingCenterId = this.el.dataset.node || this._pendingCenterId;
      this._layoutRunning = true;
      layoutScheduled = true;
      // Disable animation for certain operations to avoid flicker
      const opts = noAnimateOperations.has(operation) ? { animate: false } : {};
      layoutGraph(this.cy, opts, () => {
        const targetId =
          (typeof this._pendingCenterId === "string" &&
            this._pendingCenterId.length > 0 &&
            this._pendingCenterId) ||
          (this.el &&
            this.el.dataset &&
            typeof this.el.dataset.node === "string" &&
            this.el.dataset.node.length > 0 &&
            this.el.dataset.node) ||
          null;
        this._pendingCenterId = null;
        if (targetId) {
          requestAnimationFrame(() =>
            ensureVisible(this.cy, this._container, targetId),
          );
        }
      });
    }

    if (!layoutScheduled && this.cy && typeof this.cy.endBatch === "function")
      this.cy.endBatch();
    this.cy.elements().removeClass("selected");
    this.cy.getElementById(node).addClass("selected");

    // Bind Explore button to always open modal; gather items on demand
    const ensureExploreBound = () => {
      const btn = document.getElementById("explore-all-points");
      if (!btn) return;

      // Enable button visually and functionally

      if (!this._exploreClickHandler) {
        this._exploreClickHandler = (e) => {
          e.preventDefault();
          e.stopPropagation();

          const currentNodeId = this.el.dataset.node;

          const detector = document.getElementById(
            `list-detector-${currentNodeId}`,
          );
          const items = extractListItems(detector);

          this.pushEvent("open_explore_modal", { items });
        };
      }

      // Avoid duplicate binding
      if (this._exploreBtnEl !== btn) {
        if (this._exploreBtnEl && this._exploreClickHandler) {
          this._exploreBtnEl.removeEventListener(
            "click",
            this._exploreClickHandler,
          );
        }
        btn.addEventListener("click", this._exploreClickHandler);
        this._exploreBtnEl = btn;
      }
    };

    ensureExploreBound();

    if (this._bindPngButtons) {
      this._bindPngButtons();
    }

    // Debug redraw of bounds on update (no pan to avoid jitter)
    if (this._debugRedraw) this._debugRedraw();
  },
  destroyed() {
    if (this._onViewModeChange) {
      this.el.removeEventListener("viewModeChanged", this._onViewModeChange);
    }
    if (this._onGraphDirectionChange) {
      this.el.removeEventListener(
        "graphDirectionChanged",
        this._onGraphDirectionChange,
      );
    }
    // Debug overlay cleanup and listener removal
    if (
      this._debugRedraw &&
      this.cy &&
      typeof this.cy.removeListener === "function"
    ) {
      try {
        this.cy.removeListener("pan", null, this._debugRedraw);
        this.cy.removeListener("zoom", null, this._debugRedraw);
        this.cy.removeListener("render", null, this._debugRedraw);
      } catch (_e) {}
      this._debugRedraw = null;
    }
    try {
      [".graph-debug-bounds", ".graph-debug-edge", ".graph-debug-node"].forEach(
        (sel) => {
          const el = this._container && this._container.querySelector(sel);
          if (el && el.parentNode) el.parentNode.removeChild(el);
        },
      );
    } catch (_e) {}
    if (this._enterStopper) {
      this.el.removeEventListener("keydown", this._enterStopper, true);
      this._enterStopper = null;
    }
    if (this._windowKeydown) {
      window.removeEventListener("keydown", this._windowKeydown, true);
      this._windowKeydown = null;
    }
    if (this._onViewportResize) {
      window.removeEventListener("resize", this._onViewportResize);
      this._onViewportResize = null;
      this._viewportResizePending = false;
    }
    if (this._btnInEl && this._btnInHandler) {
      this._btnInEl.removeEventListener("click", this._btnInHandler);
      this._btnInEl = null;
      this._btnInHandler = null;
    }
    if (this._btnOutEl && this._btnOutHandler) {
      this._btnOutEl.removeEventListener("click", this._btnOutHandler);
      this._btnOutEl = null;
      this._btnOutHandler = null;
    }
    if (this._btnFitEl && this._btnFitHandler) {
      this._btnFitEl.removeEventListener("click", this._btnFitHandler);
      this._btnFitEl = null;
      this._btnFitHandler = null;
    }
    if (Array.isArray(this._btnPngHandlers)) {
      this._btnPngHandlers.forEach(([el, handler]) => {
        el.removeEventListener("click", handler);
      });
      this._btnPngHandlers = null;
    }
    if (this._exploreBtnEl && this._exploreClickHandler) {
      this._exploreBtnEl.removeEventListener(
        "click",
        this._exploreClickHandler,
      );
      this._exploreBtnEl = null;
      this._exploreClickHandler = null;
    }

    if (this._zoomToastTimer) {
      clearTimeout(this._zoomToastTimer);
      this._zoomToastTimer = null;
    }
    if (this._zoomToast && this._zoomToast.parentNode) {
      this._zoomToast.parentNode.removeChild(this._zoomToast);
      this._zoomToast = null;
    }
    // Clean up presentation badge overlays and pan/zoom listener
    if (this.cy && this._onCyPanZoom) {
      try {
        this.cy.off("pan zoom", this._onCyPanZoom);
      } catch (_e) {}
      this._onCyPanZoom = null;
    }
    try {
      if (this._badgeElements) {
        this._badgeElements.forEach((el) => el.remove());
        this._badgeElements.clear();
      }
    } catch (_e) {}
    this._presentationIds = null;
    this._presentationFiltered = false;

    // Clean up depth-toggle overlay buttons
    if (this.cy && typeof this.cy.cleanupDepthOverlay === "function") {
      try {
        this.cy.cleanupDepthOverlay();
      } catch (_e) {}
    }
    if (this.cy && typeof this.cy.destroy === "function") {
      try {
        this.cy.destroy();
      } catch (_e) {}
      this.cy = null;
    }
  },
};

export default graphHook;

import { draw_graph } from "./draw_graph";
import { layoutConfig } from "./layout_config.js";
import { extractListItems } from "./list_detection_hook.js";

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

  const layout = cy.layout({
    ...layoutConfig.baseLayout,
    ...(opts || {}),
  });

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
    const panel = document.getElementById("right-panel");
    const pr = panel ? panel.getBoundingClientRect() : null;

    // Only the overlap of the right panel over the graph container
    const overlap = pr
      ? Math.min(rect.width, Math.max(0, rect.right - pr.left))
      : 0;

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
      const now = performance.now ? performance.now() : Date.now();
      if (!cy.__evMeta) cy.__evMeta = { last: 0, animating: false };
      // Throttle and coalesce animations to avoid visible double renders/bounce
      if (cy.__evMeta.animating || now - cy.__evMeta.last < 120) {
        return;
      }
      cy.__evMeta.animating = true;
      cy.animate({
        pan: { x: pan.x + dx, y: pan.y + dy },
        duration: 120,
        easing: "ease-in-out-quad",
        complete: () => {
          cy.__evMeta.last = performance.now ? performance.now() : Date.now();
          cy.__evMeta.animating = false;
        },
      });
    }
  } catch (_e) {}
};

const graphHook = {
  mounted() {
    const { graph, node, div } = this.el.dataset;

    const container =
      this.el.querySelector(`#${div}`) || document.getElementById(div);

    this.cy = draw_graph(container, this, JSON.parse(graph), node);
    // Link back so layoutGraph can update running state
    try {
      this.cy._ownerHook = this;
    } catch (_e) {}
    // Layout/centering coordination state
    this._layoutRunning = false;
    this._pendingCenterId = null;

    // Expose container and a helper to center a node within the visible area (accounts for right panel)
    this._container = container;
    this._centerOnNodeVisible = (id) => {
      try {
        const n = this.cy.getElementById(id);
        if (!n || n.length === 0) return;

        const rect = this._container.getBoundingClientRect();
        const panel = document.getElementById("right-panel");
        const pr = panel ? panel.getBoundingClientRect() : null;
        const pw = pr && pr.width > 10 ? pr.width : 0;

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
        const panel = document.getElementById("right-panel");
        const pr = panel ? panel.getBoundingClientRect() : null;
        const overlap = pr
          ? Math.min(rect.width, Math.max(0, rect.right - pr.left))
          : 0;

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
      const panel = document.getElementById("right-panel");
      if (!panel) return 0;
      const rect = panel.getBoundingClientRect();
      return rect && rect.width > 10 ? rect.width : 0;
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

    // Handle incremental label updates for streaming titles without full graph reloads
    this.handleEvent("update_node_label", ({ id, label }) => {
      try {
        if (!id) return;
        const n =
          this.cy && typeof this.cy.getElementById === "function"
            ? this.cy.getElementById(id)
            : null;
        if (!n || n.length === 0) return;
        // Override label style for this node; does not mutate underlying data
        n.style("label", String(label || ""));
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
          nodeToCenter.addClass("selected");

          // Keep the dataset in sync so other consumers (and hooks) can rely on it
          this.el.dataset.node = id;
          if (this._debugRedraw) this._debugRedraw();

          // If a layout is in progress, defer the visibility nudge until after layoutstop
          if (this._layoutRunning) {
            this._pendingCenterId = id;
            return;
          }

          // Only pan if the node is outside the visible area (preserve existing layout)
          requestAnimationFrame(() => ensureVisible(this.cy, container, id));
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
  },
  updated() {
    const { graph, node, operation } = this.el.dataset;
    // Avoid reloading Cytoscape if the graph JSON hasn't changed to reduce flicker
    const graphStr = graph;
    const sameGraph = this._lastGraphStr === graphStr;
    if (!sameGraph) this._lastGraphStr = graphStr;

    if (!sameGraph) {
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
    }
    // Defer endBatch until after layout starts or after the no-layout path below

    const reorderOperations = new Set([
      "combine",
      "answer",
      "llm_request_complete",
      "comment",
      "other_user_change",
      "start_stream",
      "explain",
      "branch",
      "ideas",
      "deepdive",
    ]);
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
    } else if (!sameGraph && reorderOperations.has(operation)) {
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
    if (this.cy && typeof this.cy.destroy === "function") {
      try {
        this.cy.destroy();
      } catch (_e) {}
      this.cy = null;
    }
  },
};

export default graphHook;

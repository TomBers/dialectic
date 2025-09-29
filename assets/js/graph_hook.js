import { draw_graph } from "./draw_graph";
import { layoutConfig } from "./layout_config.js";

const layoutGraph = (cy) => {
  const layout = cy.layout({
    ...layoutConfig.baseLayout,
    // Add callback for when layout is done
  });

  // Run the layout
  layout.run();
};

const graphHook = {
  mounted() {
    const { graph, node, div } = this.el.dataset;

    const container =
      this.el.querySelector(`#${div}`) || document.getElementById(div);

    this.cy = draw_graph(container, this, JSON.parse(graph), node);

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

    const centerPoint = () => {
      const rect = container.getBoundingClientRect();
      return { x: rect.width / 2, y: rect.height / 2 };
    };

    const zoomBy = (factor) => {
      const current = this.cy.zoom();
      const next = clamp(current * factor, 0.05, 4);
      this.cy.zoom({ level: next, renderedPosition: centerPoint() });
      showZoom();
    };

    const fitGraph = () => {
      this.cy.fit(undefined, 25);
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
    if (btnPngs.length) {
      if (!Array.isArray(this._btnPngHandlers)) this._btnPngHandlers = [];
      btnPngs.forEach((btnPng) => {
        // Avoid duplicate binding
        const already = (this._btnPngHandlers || []).some(
          ([el]) => el === btnPng,
        );
        if (already) return;

        if (!this._exportPngHandler) {
          this._exportPngHandler = (e) => {
            e.preventDefault();
            e.stopPropagation();

            // Save current viewport
            const prevZoom = this.cy.zoom();
            const prevPan = this.cy.pan();

            // Fit the graph to canvas with padding, ignoring user zoom/pan
            this.cy.fit(undefined, 25);

            const doExport = () => {
              const dataUrl = this.cy.png({
                full: true, // ignore current viewport; export full graph
                scale: 2,
                bg: "#ffffff",
              });

              const ts = new Date().toISOString().replace(/[:.]/g, "-");
              const a = document.createElement("a");
              a.href = dataUrl;
              a.download = `graph-full-${ts}.png`;
              document.body.appendChild(a);
              a.click();
              document.body.removeChild(a);

              // Restore the previous viewport
              this.cy.zoom(prevZoom);
              this.cy.pan(prevPan);
            };

            // Wait 2 frames to ensure fit is rendered before snapshot
            requestAnimationFrame(() => {
              requestAnimationFrame(doExport);
            });
          };
        }

        btnPng.addEventListener("click", this._exportPngHandler);
        this._btnPngHandlers.push([btnPng, this._exportPngHandler]);
      });
    }

    // Listen for the center_node event from LiveView
    this.handleEvent("center_node", ({ id }) => {
      try {
        // Update selected highlighting to reflect the newly selected node
        this.cy.elements().removeClass("selected");
        const nodeToCenter = this.cy.$(`#${id}`);
        if (nodeToCenter.length > 0) {
          nodeToCenter.addClass("selected");

          // Keep the dataset in sync so other consumers (and hooks) can rely on it
          this.el.dataset.node = id;

          this.cy.animate({
            center: {
              eles: nodeToCenter,
            },
            zoom: 1.6,
            duration: 150,
            easing: "ease-in-out-quad",
          });
        }
      } catch (_e) {
        // no-op, avoid breaking on transient DOM/cy states
      }
    });
  },
  updated() {
    const { graph, node, operation } = this.el.dataset;

    this.cy.json({ elements: JSON.parse(graph) });

    const reorderOperations = new Set([
      "combine",
      "answer",
      "llm_request_complete",
      "comment",
      "other_user_change",
    ]);

    if (reorderOperations.has(operation)) {
      layoutGraph(this.cy);
    }

    this.cy.elements().removeClass("selected");
    this.cy.$(`#${node}`).addClass("selected");

    // Keep the Explore button in sync with current node content and children
    const updateExplore = (attempt = 0) => {
      const btn =
        document.getElementById(`explore-all-points-${node}`) ||
        document.getElementById("explore-all-points") ||
        document.querySelector(`[id^="explore-all-points-"][id$="-${node}"]`);
      if (!btn) {
        if (attempt < 10) setTimeout(() => updateExplore(attempt + 1), 100);
        return;
      }

      // The ListDetection hook decorates this element with dataset.listItems and data-children
      const detector = document.getElementById(`list-detector-${node}`);
      if (!detector) {
        if (attempt < 10) setTimeout(() => updateExplore(attempt + 1), 100);
        return;
      }

      const childrenCount = Number(detector.dataset.children || "0");
      let items = [];
      try {
        if (detector.dataset.listItems) {
          items = JSON.parse(detector.dataset.listItems) || [];
        }
      } catch (_e) {
        items = [];
      }

      const canExplore =
        childrenCount === 0 && Array.isArray(items) && items.length > 0;

      // Apply enabled/disabled state and classes
      if (canExplore) {
        btn.disabled = false;
        btn.className =
          "px-3 py-1 text-sm text-gray-700 rounded-full transition-colors hover:bg-indigo-500 hover:text-white";
        btn.onclick = (e) => {
          e.preventDefault();
          e.stopPropagation();
          this.pushEvent("open_explore_modal", { items });
        };
      } else {
        btn.disabled = true;
        btn.className =
          "px-3 py-1 text-sm text-gray-400 opacity-50 cursor-not-allowed rounded-full transition-colors";
        btn.onclick = null;
      }
    };

    // Initial sync (and retry if the detector element isn't mounted yet)
    updateExplore();

    // Robustly bind PNG buttons that might be added on LiveView updates
    const pngButtons = Array.from(document.querySelectorAll(".download-png"));
    if (!Array.isArray(this._btnPngHandlers)) this._btnPngHandlers = [];
    const bound = new Set(this._btnPngHandlers.map(([el]) => el));
    pngButtons.forEach((btn) => {
      if (bound.has(btn)) return;
      if (!this._exportPngHandler) {
        this._exportPngHandler = (e) => {
          e.preventDefault();
          e.stopPropagation();

          const prevZoom = this.cy.zoom();
          const prevPan = this.cy.pan();

          this.cy.fit(undefined, 25);

          const doExport = () => {
            const dataUrl = this.cy.png({
              full: true,
              scale: 2,
              bg: "#ffffff",
            });

            const ts = new Date().toISOString().replace(/[:.]/g, "-");
            const a = document.createElement("a");
            a.href = dataUrl;
            a.download = `graph-full-${ts}.png`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);

            this.cy.zoom(prevZoom);
            this.cy.pan(prevPan);
          };

          requestAnimationFrame(() => {
            requestAnimationFrame(doExport);
          });
        };
      }

      btn.addEventListener("click", this._exportPngHandler);
      this._btnPngHandlers.push([btn, this._exportPngHandler]);
    });
  },
  destroyed() {
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

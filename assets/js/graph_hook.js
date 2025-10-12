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
    // Shared PNG export helpers and button binding
    if (!this._exportGraphPng) {
      this._exportGraphPng = () => {
        // Save current viewport
        const prevZoom = this.cy.zoom();
        const prevPan = this.cy.pan();

        // Fit the graph to canvas with padding
        this.cy.fit(undefined, 25);

        const doExport = () => {
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
          } finally {
            // Restore the previous viewport
            this.cy.zoom(prevZoom);
            this.cy.pan(prevPan);
          }
        };

        // Wait 2 frames to ensure fit is rendered before snapshot
        requestAnimationFrame(() => {
          requestAnimationFrame(doExport);
        });
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
            zoom: this.cy.zoom(),
            duration: 150,
            easing: "ease-in-out-quad",
          });
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
          let items = [];
          if (detector && detector.dataset && detector.dataset.listItems) {
            try {
              const parsed = JSON.parse(detector.dataset.listItems);
              if (Array.isArray(parsed)) items = parsed;
            } catch (_e) {}
          }

          // Fallback extraction if needed
          if (!Array.isArray(items) || items.length === 0) {
            const clean = (s) => (s || "").replace(/\s+/g, " ").trim();
            const isHeadingLike = (txt) => {
              if (!txt) return true;
              if (/^short answer\s*:/i.test(txt)) return true;
              if (/:$/.test(txt)) return true;
              return false;
            };
            const textFromLi = (li) => {
              const clone = li.cloneNode(true);
              clone.querySelectorAll("ul, ol").forEach((n) => n.remove());
              return clean(clone.textContent || "");
            };
            if (detector) {
              // 1) Nested sub-bullets
              Array.from(detector.querySelectorAll("li")).forEach((li) => {
                const nestedLists = Array.from(li.children).filter(
                  (el) => el.tagName === "UL" || el.tagName === "OL",
                );
                nestedLists.forEach((list) => {
                  Array.from(list.children)
                    .filter((el) => el.tagName === "LI")
                    .forEach((nli) => {
                      const txt = textFromLi(nli);
                      if (!txt) return;
                      if (isHeadingLike(txt)) return;
                      items.push(txt);
                    });
                });
              });
              // 2) Top-level leaf bullets
              const topLists = Array.from(
                detector.querySelectorAll("ul, ol"),
              ).filter((list) => !list.closest("li"));
              topLists.forEach((list) => {
                Array.from(list.children)
                  .filter((el) => el.tagName === "LI")
                  .forEach((li) => {
                    const hasNested = Array.from(li.children).some(
                      (el) => el.tagName === "UL" || el.tagName === "OL",
                    );
                    if (hasNested) return;
                    const txt = textFromLi(li);
                    if (!txt) return;
                    if (isHeadingLike(txt)) return;
                    items.push(txt);
                  });
              });
              items = Array.from(new Set(items));
            }
          }

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

    // Bind Explore button to always open modal; gather items on demand
    const ensureExploreBound = () => {
      const btn = document.getElementById("explore-all-points");
      if (!btn) return;

      // Enable button visually and functionally

      if (!this._exploreClickHandler) {
        this._exploreClickHandler = (e) => {
          e.preventDefault();
          e.stopPropagation();

          const currentNodeId = node;

          // Extract items on demand
          const items = (() => {
            const detector = document.getElementById(
              `list-detector-${currentNodeId}`,
            );

            // Prefer items extracted by ListDetection, if present
            if (detector && detector.dataset && detector.dataset.listItems) {
              try {
                const parsed = JSON.parse(detector.dataset.listItems);
                if (Array.isArray(parsed)) return parsed;
              } catch (_e) {}
            }

            // Fallback: extract bullet points on demand (nested sub-bullets + top-level leaf bullets)
            const res = [];
            if (detector) {
              const clean = (s) => (s || "").replace(/\s+/g, " ").trim();
              const isHeadingLike = (txt) => {
                if (!txt) return true;
                if (/^short answer\s*:/i.test(txt)) return true;
                if (/:$/.test(txt)) return true;
                return false;
              };
              const textFromLi = (li) => {
                const clone = li.cloneNode(true);
                clone.querySelectorAll("ul, ol").forEach((n) => n.remove());
                return clean(clone.textContent || "");
              };

              // 1) Nested sub-bullets under parent LI
              Array.from(detector.querySelectorAll("li")).forEach((li) => {
                const nestedLists = Array.from(li.children).filter(
                  (el) => el.tagName === "UL" || el.tagName === "OL",
                );
                nestedLists.forEach((list) => {
                  Array.from(list.children)
                    .filter((el) => el.tagName === "LI")
                    .forEach((nli) => {
                      const txt = textFromLi(nli);
                      if (!txt) return;
                      if (isHeadingLike(txt)) return;
                      res.push(txt);
                    });
                });
              });

              // 2) Top-level leaf bullets (direct LI under root UL/OL with no nested lists)
              const topLists = Array.from(
                detector.querySelectorAll("ul, ol"),
              ).filter((list) => !list.closest("li"));
              topLists.forEach((list) => {
                Array.from(list.children)
                  .filter((el) => el.tagName === "LI")
                  .forEach((li) => {
                    const hasNested = Array.from(li.children).some(
                      (el) => el.tagName === "UL" || el.tagName === "OL",
                    );
                    if (hasNested) return;
                    const txt = textFromLi(li);
                    if (!txt) return;
                    if (isHeadingLike(txt)) return;
                    res.push(txt);
                  });
              });
            }
            return Array.from(new Set(res));
          })();

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

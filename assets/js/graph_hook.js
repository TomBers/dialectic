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

    this.cy = draw_graph(
      this.el.querySelector(`#${div}`) || document.getElementById(div),
      this,
      JSON.parse(graph),
      node,
    );
    const container = document.getElementById(div);

    // Zoom controls (+ / − / Fit)
    const clamp = (val, min, max) => Math.max(min, Math.min(max, val));
    let zoomToast = null;
    let zoomToastTimer = null;

    const showZoom = () => {
      if (!zoomToast) {
        zoomToast = document.createElement("div");
        zoomToast.style.position = "absolute";
        zoomToast.style.right = "12px";
        zoomToast.style.bottom = "48px";
        zoomToast.style.padding = "2px 6px";
        zoomToast.style.background = "rgba(0,0,0,0.65)";
        zoomToast.style.color = "#fff";
        zoomToast.style.fontSize = "12px";
        zoomToast.style.borderRadius = "4px";
        zoomToast.style.pointerEvents = "none";
        zoomToast.style.transition = "opacity 150ms ease";
        container.appendChild(zoomToast);
      }
      zoomToast.textContent = Math.round(this.cy.zoom() * 100) + "%";
      zoomToast.style.opacity = "1";
      if (zoomToastTimer) clearTimeout(zoomToastTimer);
      zoomToastTimer = setTimeout(() => (zoomToast.style.opacity = "0"), 900);
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

    const btnIn = container.querySelector("#zoom-in");
    const btnOut = container.querySelector("#zoom-out");
    const btnFit = container.querySelector("#zoom-fit");

    if (btnIn) {
      btnIn.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        zoomBy(1.2);
      });
    }
    if (btnOut) {
      btnOut.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        zoomBy(1 / 1.2);
      });
    }
    if (btnFit) {
      btnFit.addEventListener("click", (e) => {
        e.preventDefault();
        e.stopPropagation();
        fitGraph();
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
      const btn = document.querySelector(
        `[id^="explore-all-points-"][id$="-${node}"]`,
      );
      if (!btn) return;

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
  },
};

export default graphHook;

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
      document.getElementById(div),
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
      const nodeToCenter = this.cy.$(`#${id}`);
      if (nodeToCenter.length > 0) {
        this.cy.animate({
          center: {
            eles: nodeToCenter,
          },
          zoom: 1.6,
          duration: 150,
          easing: "ease-in-out-quad",
        });
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
  },
};

export default graphHook;

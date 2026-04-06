/**
 * NodeMenuHook - Positions the node action menu below the currently selected node
 */
const NodeMenuHook = {
  mounted() {
    this.positionMenu();
    this.setupListeners();
  },

  updated() {
    this.positionMenu();
  },

  setupListeners() {
    // Listen for graph pan/zoom events to reposition menu
    const graphContainer = document.getElementById("cy");
    if (graphContainer && graphContainer.__cy) {
      const cy = graphContainer.__cy;

      // Reposition on pan/zoom
      cy.on("pan zoom", () => {
        requestAnimationFrame(() => this.positionMenu());
      });

      // Reposition on viewport changes
      cy.on("viewport", () => {
        requestAnimationFrame(() => this.positionMenu());
      });

      // Reposition when layout completes
      cy.on("layoutstop", () => {
        requestAnimationFrame(() => this.positionMenu());
      });

      this._cy = cy;
    }

    // Reposition on window resize
    this._resizeHandler = () => {
      requestAnimationFrame(() => this.positionMenu());
    };
    window.addEventListener("resize", this._resizeHandler);

    // Reposition when panels open/close
    this._panelObserver = new MutationObserver(() => {
      requestAnimationFrame(() => this.positionMenu());
    });

    const rightPanel = document.getElementById("right-panel");
    const navDrawer = document.getElementById("graph-nav-drawer");
    const highlightsDrawer = document.getElementById("highlights-drawer");

    [rightPanel, navDrawer, highlightsDrawer].forEach((panel) => {
      if (panel) {
        this._panelObserver.observe(panel, {
          attributes: true,
          attributeFilter: ["class", "style"],
        });
      }
    });
  },

  positionMenu() {
    const graphContainer = document.getElementById("cy");
    if (!graphContainer) return;

    const cy = graphContainer.__cy || this._cy;
    if (!cy) return;

    // Find the selected node
    const selectedNode = cy.$(".selected").filter((n) => !n.isParent());
    if (!selectedNode || selectedNode.length === 0) {
      // No node selected, hide menu
      this.el.style.display = "none";
      return;
    }

    const node = selectedNode[0];
    const graphRect = graphContainer.getBoundingClientRect();

    // Get node's rendered position (accounting for zoom and pan)
    const pos = node.renderedPosition();
    const bb = node.renderedBoundingBox();

    // Calculate position below the node
    const nodeBottomY = bb.y2;
    const nodeCenterX = (bb.x1 + bb.x2) / 2;

    // Convert to viewport coordinates
    const menuX = graphRect.left + nodeCenterX;
    const menuY = graphRect.top + nodeBottomY + 12; // 12px gap below node

    // Check if menu would go off-screen
    const menuRect = this.el.querySelector("[data-role='node-menu']")?.getBoundingClientRect();
    const menuWidth = menuRect ? menuRect.width : 400; // fallback estimate
    const menuHeight = menuRect ? menuRect.height : 60; // fallback estimate

    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;

    let finalX = menuX;
    let finalY = menuY;

    // Keep menu within viewport horizontally
    const halfWidth = menuWidth / 2;
    if (finalX - halfWidth < 10) {
      finalX = halfWidth + 10;
    } else if (finalX + halfWidth > viewportWidth - 10) {
      finalX = viewportWidth - halfWidth - 10;
    }

    // If menu would go below viewport, position it above the node instead
    if (finalY + menuHeight > viewportHeight - 10) {
      finalY = graphRect.top + bb.y1 - menuHeight - 12;
    }

    // Ensure menu doesn't go above viewport
    if (finalY < 10) {
      finalY = 10;
    }

    // Apply positioning
    this.el.style.display = "block";
    this.el.style.left = `${finalX}px`;
    this.el.style.top = `${finalY}px`;
    this.el.style.transform = "translate(-50%, 0)";
  },

  destroyed() {
    // Clean up event listeners
    if (this._resizeHandler) {
      window.removeEventListener("resize", this._resizeHandler);
    }

    if (this._panelObserver) {
      this._panelObserver.disconnect();
    }

    if (this._cy) {
      this._cy.off("pan zoom viewport layoutstop");
    }
  },
};

export default NodeMenuHook;

/**
 * NodeMenuHook - Manages the node actions menu using Cytoscape Popper
 *
 * This hook uses Cytoscape's built-in popper extension to attach a floating menu
 * to the currently selected node. The popper automatically handles positioning,
 * viewport boundaries, and follows the node during pan/zoom.
 */

const NodeMenuHook = {
  mounted() {
    this.cy = null;
    this.currentPopper = null;
    this.currentNodeId = null;
    this.menuContainer = null;
    this.menuClickHandler = null;

    // Find the menu container
    this.menuContainer = this.el.querySelector(".node-actions-menu");
    if (!this.menuContainer) {
      return;
    }

    // Move menu to body for proper absolute positioning
    document.body.appendChild(this.menuContainer);

    // Initially hide the menu
    this.menuContainer.style.display = "none";
    this.menuContainer.style.opacity = "0";
    this.menuContainer.style.visibility = "hidden";
    this.menuContainer.style.pointerEvents = "none";

    // Add click handler to prevent menu clicks from closing it
    this.menuClickHandler = (e) => {
      e.stopPropagation();
    };
    this.menuContainer.addEventListener("click", this.menuClickHandler);

    // Wait for Cytoscape to be ready
    this.waitForCytoscape();

    // Listen for manual show/hide events from LiveView
    this.handleEvent("show_node_menu", (payload) => {
      this.showMenuForNode(payload.nodeId);
    });

    this.handleEvent("hide_node_menu", () => {
      this.destroyPopper();
    });
  },

  updated() {
    // Menu is only shown when explicitly clicking a node
    // Don't auto-show on LiveView updates
  },

  waitForCytoscape() {
    // Poll for the Cytoscape instance
    this.cyCheckInterval = setInterval(() => {
      const graphEl = document.querySelector('[phx-hook="Graph"]');
      if (graphEl && graphEl.__graphHook && graphEl.__graphHook.cy) {
        this.cy = graphEl.__graphHook.cy;
        this.setupListeners();
        clearInterval(this.cyCheckInterval);
      }
    }, 100);

    // Stop polling after 5 seconds
    setTimeout(() => {
      if (this.cyCheckInterval) {
        clearInterval(this.cyCheckInterval);
      }
    }, 5000);
  },

  setupListeners() {
    if (!this.cy) return;

    // Hide menu when clicking background (fires first, before node tap)
    this.cy.on("tap", (event) => {
      // Only hide if we're clicking on the background (not a node or edge)
      if (event.target === this.cy) {
        this.destroyPopper();
      }
    });

    // Update popper when a new node is selected (fires after background tap for nodes)
    this.cy.on("tap", "node", (event) => {
      const node = event.target;
      // Skip compound/group nodes
      if (node.isParent && node.isParent()) return;

      const nodeId = node.id();
      this.showMenuForNode(nodeId);
    });
  },

  showMenuForNode(nodeId) {
    if (!this.cy || !this.menuContainer) {
      return;
    }

    const node = this.cy.getElementById(nodeId);
    if (!node || node.length === 0) {
      this.destroyPopper();
      return;
    }

    // Skip compound/group nodes
    if (node.isParent && node.isParent()) {
      this.destroyPopper();
      return;
    }

    // Destroy existing popper if any
    this.destroyPopper();

    // Show the menu
    this.menuContainer.style.display = "block";
    this.menuContainer.style.opacity = "1";
    this.menuContainer.style.visibility = "visible";
    this.menuContainer.style.pointerEvents = "auto";

    // Check if popper function exists
    if (typeof node.popper !== "function") {
      this.hideMenu();
      return;
    }

    // Create popper instance using Cytoscape's popper extension (v4 API)
    const popperInstance = node.popper({
      content: () => {
        return this.menuContainer;
      },
      placement: "bottom",
      modifiers: [
        {
          name: "flip",
          enabled: true,
          options: {
            fallbackPlacements: ["top", "bottom", "left", "right"],
          },
        },
        {
          name: "preventOverflow",
          enabled: true,
          options: {
            boundary: "viewport",
            padding: 8,
          },
        },
        {
          name: "offset",
          enabled: true,
          options: {
            offset: [0, 8],
          },
        },
      ],
    });

    // Store references
    this.currentPopper = popperInstance;
    this.currentNodeId = nodeId;

    // Update popper on pan/zoom
    const updatePopper = () => {
      if (this.currentPopper && this.currentPopper.update) {
        this.currentPopper.update();
      }
    };

    this.cy.on("pan zoom resize", updatePopper);
    this.currentPopper._updateListener = updatePopper;
  },

  destroyPopper() {
    if (this.currentPopper) {
      // Remove pan/zoom listener
      if (this.currentPopper._updateListener && this.cy) {
        this.cy.off("pan zoom resize", this.currentPopper._updateListener);
      }

      // Destroy popper instance
      if (this.currentPopper.destroy) {
        this.currentPopper.destroy();
      }

      this.currentPopper = null;
    }

    this.currentNodeId = null;
    this.hideMenu();
  },

  hideMenu() {
    if (!this.menuContainer) return;

    this.menuContainer.style.display = "none";
    this.menuContainer.style.opacity = "0";
    this.menuContainer.style.visibility = "hidden";
    this.menuContainer.style.pointerEvents = "none";
  },

  destroyed() {
    // Clean up interval
    if (this.cyCheckInterval) {
      clearInterval(this.cyCheckInterval);
    }

    // Destroy popper
    this.destroyPopper();

    // Clean up Cytoscape listeners
    if (this.cy) {
      this.cy.off("tap");
    }

    // Remove menu click handler
    if (this.menuContainer && this.menuClickHandler) {
      this.menuContainer.removeEventListener("click", this.menuClickHandler);
    }

    // Remove menu from body
    if (this.menuContainer && this.menuContainer.parentNode) {
      this.menuContainer.parentNode.removeChild(this.menuContainer);
    }

    this.cy = null;
    this.menuContainer = null;
    this.menuClickHandler = null;
  },
};

export default NodeMenuHook;

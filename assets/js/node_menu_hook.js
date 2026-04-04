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
    this.menuButtonClickHandler = null;
    this.backgroundTapHandler = null;
    this.nodeTapHandler = null;

    // Find the menu container
    this.menuContainer = this.el.querySelector(".node-actions-menu");
    if (!this.menuContainer) {
      return;
    }

    // Move menu to body for proper positioning, but forward events to LiveView
    document.body.appendChild(this.menuContainer);

    // Initially hide the menu
    this.menuContainer.style.display = "none";
    this.menuContainer.style.opacity = "0";
    this.menuContainer.style.visibility = "hidden";
    this.menuContainer.style.pointerEvents = "none";

    // Note: We don't stop propagation on menu clicks because we need
    // phx-click events to reach the LiveView server. The background
    // click handler already checks event.target === cy to avoid closing
    // the menu when clicking menu items.

    // Forward phx-click events to LiveView and close menu after button clicks
    this.menuButtonClickHandler = (e) => {
      const button = e.target.closest("button");
      if (button) {
        // Prevent default behavior and stop propagation to avoid double-firing
        e.preventDefault();
        e.stopPropagation();

        // Forward phx-click to the LiveView by dispatching the event on the original element
        const phxClick = button.getAttribute("phx-click");
        if (phxClick) {
          // Check for confirmation dialog
          const confirmMessage = button.getAttribute("data-confirm");
          if (confirmMessage) {
            // Show confirmation dialog
            if (!confirm(confirmMessage)) {
              // User cancelled, just close the menu
              this.destroyPopper();
              return;
            }
          }

          // Get the phx-value attributes
          const phxValues = {};
          Array.from(button.attributes).forEach((attr) => {
            if (attr.name.startsWith("phx-value-")) {
              const key = attr.name.replace("phx-value-", "");
              phxValues[key] = attr.value;
            }
          });

          // Push event to LiveView
          this.pushEvent(phxClick, phxValues);
        }

        // Close menu after event is sent
        setTimeout(() => {
          this.destroyPopper();
        }, 50);
      }
    };
    this.menuContainer.addEventListener("click", this.menuButtonClickHandler);

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
    this.backgroundTapHandler = (event) => {
      // Only hide if we're clicking on the background (not a node or edge)
      if (event.target === this.cy) {
        this.destroyPopper();
      }
    };
    this.cy.on("tap", this.backgroundTapHandler);

    // Update popper when a new node is selected (fires after background tap for nodes)
    this.nodeTapHandler = (event) => {
      const node = event.target;
      // Skip compound/group nodes
      if (node.isParent && node.isParent()) return;

      const nodeId = node.id();
      this.showMenuForNode(nodeId);
    };
    this.cy.on("tap", "node", this.nodeTapHandler);
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
      strategy: "fixed",
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

    // Clean up Cytoscape listeners - only remove our specific handlers
    if (this.cy) {
      if (this.backgroundTapHandler) {
        this.cy.off("tap", this.backgroundTapHandler);
      }
      if (this.nodeTapHandler) {
        this.cy.off("tap", "node", this.nodeTapHandler);
      }
    }

    // Remove menu button click handler
    if (this.menuContainer && this.menuButtonClickHandler) {
      this.menuContainer.removeEventListener(
        "click",
        this.menuButtonClickHandler,
      );
    }

    // Remove menu from body
    if (this.menuContainer && this.menuContainer.parentNode) {
      this.menuContainer.parentNode.removeChild(this.menuContainer);
    }

    this.cy = null;
    this.menuContainer = null;
    this.menuButtonClickHandler = null;
    this.backgroundTapHandler = null;
    this.nodeTapHandler = null;
  },
};

export default NodeMenuHook;

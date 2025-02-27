// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
import "./user_socket.js";

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { draw_graph } from "./draw_graph";
import topbar from "../vendor/topbar";

let numNodes = null;
let nodeId = null;

let hooks = {};

// Hook - handles all positioning logic
hooks.NodeMenuHook = {
  mounted() {
    // Initially hide the tooltip
    this.el.style.opacity = "0";
    this.el.style.transition = "opacity 0.2s ease-out";

    // Setup debounce function
    this.debouncedHandlePositioning = this.debounce(() => {
      this.calculateAndApplyPosition();
    }, 100);

    // Run initial positioning with slight delay to ensure DOM is ready
    setTimeout(() => {
      this.calculateAndApplyPosition();
    }, 20);

    // Setup resize handler
    this.resizeListener = () => this.debouncedHandlePositioning();
    window.addEventListener("resize", this.resizeListener);
  },

  calculateAndApplyPosition() {
    // Get node position from data attribute
    const nodePosition = this.el.dataset.nodePosition
      ? JSON.parse(this.el.dataset.nodePosition)
      : null;

    if (!nodePosition) return;

    // Get tooltip dimensions
    const tooltipWidth = this.el.offsetWidth;
    const tooltipHeight = this.el.offsetHeight;

    // Get viewport dimensions
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;

    // Node center and dimensions
    const nodeCenter = {
      x: nodePosition.center_x,
      y: nodePosition.center_y,
    };
    const nodeWidth = nodePosition.width;
    const nodeHeight = nodePosition.height;

    // Calculate best position (default is below the node)
    let tooltipX = nodeCenter.x - tooltipWidth / 2;
    let tooltipY = nodePosition.bb_y2 + 10; // 10px below the node
    let placement = "bottom";

    // Check if tooltip would go below viewport bottom
    if (tooltipY + tooltipHeight > viewportHeight) {
      // Try to place above the node instead
      if (nodePosition.bb_y1 - tooltipHeight - 10 >= 0) {
        tooltipY = nodePosition.bb_y1 - tooltipHeight - 10;
        placement = "top";
      } else {
        // If can't place above, place at side if there's room
        if (nodeCenter.x + nodeWidth / 2 + tooltipWidth <= viewportWidth) {
          tooltipX = nodePosition.bb_x2 + 10;
          tooltipY = nodeCenter.y - tooltipHeight / 2;
          placement = "right";
        } else if (nodeCenter.x - nodeWidth / 2 - tooltipWidth >= 0) {
          tooltipX = nodePosition.bb_x1 - tooltipWidth - 10;
          tooltipY = nodeCenter.y - tooltipHeight / 2;
          placement = "left";
        } else {
          // Last resort: place at bottom but constrain to viewport
          tooltipY = viewportHeight - tooltipHeight - 10;
          placement = "bottom-constrained";
        }
      }
    }

    // Check if tooltip would go beyond right edge
    if (tooltipX + tooltipWidth > viewportWidth) {
      tooltipX = viewportWidth - tooltipWidth - 10;
    }

    // Check if tooltip would go beyond left edge
    if (tooltipX < 0) {
      tooltipX = 10;
    }

    // Apply position to the element
    this.el.style.left = `${tooltipX}px`;
    this.el.style.top = `${tooltipY}px`;

    // Make tooltip visible now that it's positioned
    this.el.style.opacity = "1";

    // Also send to server for any server-side needs
    const updatedPosition = {
      x: tooltipX,
      y: tooltipY,
      viewport_width: viewportWidth,
      viewport_height: viewportHeight,
      width: tooltipWidth,
      height: tooltipHeight,
      placement: placement,
    };

    this.pushEvent("update_tooltip_position", { position: updatedPosition });
  },

  debounce(func, wait) {
    let timeout;
    return function () {
      const context = this;
      const args = arguments;
      clearTimeout(timeout);
      timeout = setTimeout(() => func.apply(context, args), wait);
    };
  },

  destroyed() {
    window.removeEventListener("resize", this.resizeListener);
  },
};

hooks.TextSelectionHook = {
  mounted() {
    this.handleSelection = this.handleSelection.bind(this);
    this.hideSelectionActions = this.hideSelectionActions.bind(this);

    // Get node ID from data attribute
    this.nodeId = this.el.dataset.nodeId;

    // Store element ID to prevent duplicate events
    this.elId = this.el.id;

    // Add event listeners for this specific container
    this.el.addEventListener("mouseup", this.handleSelection);
    this.el.addEventListener("touchend", this.handleSelection);

    // Handle clicks outside the selection
    document.addEventListener("mousedown", (e) => {
      if (!this.el.contains(e.target)) {
        this.hideSelectionActions();
      }
    });

    // Handle selection clearing
    document.addEventListener("selectionchange", () => {
      const selection = window.getSelection();
      if (selection.isCollapsed) {
        this.hideSelectionActions();
      }
    });
  },

  destroyed() {
    this.el.removeEventListener("mouseup", this.handleSelection);
    this.el.removeEventListener("touchend", this.handleSelection);
  },

  handleSelection(event) {
    // Prevent double handling of the same selection
    const selection = window.getSelection();
    const selectionActionsEl = this.el.querySelector(".selection-actions");

    if (!selectionActionsEl) return;

    // Check if selection is empty or not within this component
    if (selection.isCollapsed || !this.isSelectionInComponent(selection)) {
      this.hideSelectionActions();
      return;
    }

    const selectedText = selection.toString().trim();
    if (selectedText.length === 0) {
      this.hideSelectionActions();
      return;
    }

    // If we're not the closest container to the selection, don't show our button
    if (!this.isClosestSelectionContainer()) {
      this.hideSelectionActions();
      return;
    }

    // Get the range and its bounding rectangle
    const range = selection.getRangeAt(0);
    const rect = range.getBoundingClientRect();

    // Get the container's bounding rectangle
    const containerRect = this.el.getBoundingClientRect();

    // Check if we're in a modal to adjust positioning
    const isInModal = this.el.id.includes("modal-content");
    const containerScrollTop = isInModal ? this.el.scrollTop : 0;

    // Make the button visible so we can measure its width
    selectionActionsEl.classList.remove("hidden");

    // Get button dimensions after making it visible
    const buttonWidth = selectionActionsEl.offsetWidth;
    const buttonHeight = selectionActionsEl.offsetHeight;

    // Calculate vertical position (below the selection)
    const top =
      rect.bottom - containerRect.top + window.scrollY - containerScrollTop;

    // Calculate initial horizontal position (centered on selection end)
    let leftPos = rect.right - containerRect.left - buttonWidth / 2;

    // Ensure button stays within container bounds
    // First, make sure it doesn't go off the left edge
    leftPos = Math.max(5, leftPos);

    // Then, make sure it doesn't go off the right edge
    // We need to consider the container's width minus button width
    const maxLeftPos = containerRect.width - buttonWidth - 5;
    leftPos = Math.min(maxLeftPos, leftPos);

    // Apply the calculated positions
    selectionActionsEl.style.top = `${top}px`;
    selectionActionsEl.style.left = `${leftPos}px`;

    // Set up the button to send the selected text to the server
    const actionButton = selectionActionsEl.querySelector("button");
    actionButton.onclick = () => {
      // Match the parameter names expected by your existing handler
      this.pushEvent("handle_selection", {
        node: this.nodeId,
        value: selectedText,
      });

      // Hide the action button after clicking
      this.hideSelectionActions();
    };
  },

  isSelectionInComponent(selection) {
    if (selection.rangeCount === 0) return false;

    const range = selection.getRangeAt(0);
    const selectionContainer = range.commonAncestorContainer;

    // Check if the selection is within this component
    return this.el.contains(selectionContainer);
  },

  isClosestSelectionContainer() {
    const selection = window.getSelection();
    if (selection.rangeCount === 0) return false;

    const range = selection.getRangeAt(0);
    let container = range.commonAncestorContainer;

    // If the container is a text node, get its parent
    if (container.nodeType === 3) {
      container = container.parentNode;
    }

    // Find all potential selection containers that contain this selection
    const allContainers = document.querySelectorAll(
      '[phx-hook="TextSelectionHook"]',
    );
    let closestContainer = null;
    let minDepth = Infinity;

    // For each potential container, check if it contains the selection
    // and calculate its depth in the DOM
    allContainers.forEach((el) => {
      if (el.contains(container)) {
        // Calculate DOM depth (fewer is closer)
        let depth = 0;
        let parent = container;
        while (parent && parent !== el) {
          depth++;
          parent = parent.parentNode;
        }

        if (depth < minDepth) {
          minDepth = depth;
          closestContainer = el;
        }
      }
    });

    // Return true if this hook's element is the closest container
    return closestContainer === this.el;
  },

  hideSelectionActions() {
    const selectionActionsEl = this.el.querySelector(".selection-actions");
    if (selectionActionsEl) {
      selectionActionsEl.classList.add("hidden");
    }
  },
};

hooks.Graph = {
  mounted() {
    // Hide the user header
    document.getElementById("userHeader").style.display = "none";

    const { graph, node, cols, div } = this.el.dataset;
    const div_id = document.getElementById(div);
    const elements = JSON.parse(graph);

    numNodes = elements;
    nodeId = node;
    this.cy = draw_graph(div_id, this, elements, cols, node);
  },
  updated() {
    const { graph, node, updateview } = this.el.dataset;
    const newElements = JSON.parse(graph);

    if (newElements.length != numNodes.length) {
      this.cy.json({ elements: newElements });
      this.cy
        .layout({ name: "dagre", nodeSep: 20, edgeSep: 15, rankSep: 30 })
        .run();
    }
    if (node != nodeId && updateview == "true") {
      this.cy.animate({
        center: {
          eles: `#${node}`,
        },
        zoom: 2,
        duration: 500, // duration in milliseconds for the animation
      });
    }

    this.cy.elements().removeClass("selected");
    this.cy.$(`#${node}`).addClass("selected");

    nodeId = node;
    numNodes = newElements;
  },
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: hooks,
  params: { _csrf_token: csrfToken },
  metadata: {
    keydown: (e, el) => {
      // console.log(e);
      // console.log(el);
      return {
        key: e.key,
        cmdKey: e.ctrlKey,
        metaKey: e.metaKey,
        repeat: e.repeat,
      };
    },
  },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

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

hooks.TextSelectionHook = {
  mounted() {
    this.handleSelection = this.handleSelection.bind(this);
    this.hideSelectionActions = this.hideSelectionActions.bind(this);

    // Get node ID from data attribute
    this.nodeId = this.el.dataset.nodeId;

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

    // Display the action button near the selection
    const range = selection.getRangeAt(0);
    const rect = range.getBoundingClientRect();

    selectionActionsEl.classList.remove("hidden");

    // Get the position of the element with the selection
    const elRect = this.el.getBoundingClientRect();

    // Check if we're in a modal to adjust positioning
    const isInModal = this.el.id.includes("modal-content");

    // Calculate position relative to the container
    // For modal content, we need to account for modal scroll position
    const containerScrollTop = isInModal ? this.el.scrollTop : 0;

    const top = rect.bottom - elRect.top + window.scrollY - containerScrollTop;
    const left = rect.right - elRect.left + window.scrollX;

    // Position the button below and at the end of the selection
    selectionActionsEl.style.top = `${top}px`;
    selectionActionsEl.style.left = `${Math.max(0, left - selectionActionsEl.offsetWidth / 2)}px`;

    // Set up the button to send the selected text to the server
    const actionButton = selectionActionsEl.querySelector("button");
    actionButton.onclick = () => {
      if (selectedText != "") {
        this.pushEvent("handle_selection", {
          node_id: this.nodeId,
          selected_text: selectedText,
          is_modal: isInModal,
        });
      } else {
        alert("No text selected");
      }

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

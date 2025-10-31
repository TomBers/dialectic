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

import topbar from "../vendor/topbar";
import textSelectionHook from "./text_selection_hook.js";
import graphHook from "./graph_hook.js";
import highlightNodeHook from "./highlight_node_hook.js";
import printConversationHook from "./print_conversation_hook.js";
import storyReadabilityHook from "./story_readability_hook.js";
import listDetectionHook from "./list_detection_hook.js";

let hooks = {};

// Hook - handles all positioning logic
hooks.TextSelectionHook = textSelectionHook;
hooks.Graph = graphHook;
hooks.HighlightNode = highlightNodeHook;
hooks.PrintConversation = printConversationHook;
hooks.StoryReadability = storyReadabilityHook;
hooks.ListDetection = listDetectionHook;

// Chat scroll management hook
hooks.ChatScroll = {
  mounted() {
    // Cache elements and bind listeners
    this.buttonEl = this.el.querySelector("#scroll-to-latest");
    this.onScroll = () => this.updateButtonVisibility();
    this.el.addEventListener("scroll", this.onScroll);

    if (this.buttonEl) {
      this.buttonEl.addEventListener("click", () => this.scrollToBottom());
    }

    // Handle external requests to scroll to a node's message
    this.handleEvent("scroll_chat_to_node", ({ id }) =>
      this.scrollToMessage(id),
    );

    // If starting near the bottom, keep it pinned; otherwise show the button
    if (this.isNearBottom()) this.scrollToBottom();
    this.updateButtonVisibility();
  },

  updated() {
    // Only auto-scroll if the user is already near the bottom
    if (this.isNearBottom()) this.scrollToBottom();
    this.updateButtonVisibility();
  },

  destroyed() {
    if (this.onScroll) this.el.removeEventListener("scroll", this.onScroll);
    this.onScroll = null;
  },

  isNearBottom() {
    const threshold = 32; // px
    const { scrollTop, scrollHeight, clientHeight } = this.el || {};
    if (scrollTop == null) return true;
    return scrollTop + clientHeight >= scrollHeight - threshold;
  },

  updateButtonVisibility() {
    if (!this.buttonEl) return;
    if (this.isNearBottom()) {
      this.buttonEl.classList.add("hidden");
    } else {
      this.buttonEl.classList.remove("hidden");
    }
  },

  scrollToBottom() {
    requestAnimationFrame(() => {
      if (!this.el) return;
      this.el.scrollTop = this.el.scrollHeight;
      this.updateButtonVisibility();
    });
  },

  scrollToMessage(id) {
    requestAnimationFrame(() => {
      const el =
        document.getElementById(`conv-end-${id}`) ||
        document.getElementById(`conv-com-${id}`);
      if (el && typeof el.scrollIntoView === "function") {
        el.scrollIntoView({ behavior: "smooth", block: "end" });
      } else {
        // Fallback: just scroll to bottom if element not found
        this.scrollToBottom();
      }
      this.updateButtonVisibility();
    });
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

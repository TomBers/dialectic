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
import keepFocusHook from "./keep_focus_hook.js";

let hooks = {};

// Hook - handles all positioning logic
hooks.TextSelectionHook = textSelectionHook;
hooks.Graph = graphHook;
hooks.HighlightNode = highlightNodeHook;
hooks.PrintConversation = printConversationHook;
hooks.StoryReadability = storyReadabilityHook;
hooks.ListDetection = listDetectionHook;
hooks.KeepFocus = keepFocusHook;

// Chat scroll & scroll-sync hook
// - Auto-pins to bottom only if the user is near it (within threshold)
// - Debounces scrolls and uses Resize/Mutation observers to avoid jumpiness
// - Clears the chat input on submit to prevent text lingering after patch
hooks.ChatScroll = {
  mounted() {
    // Pin-to-bottom threshold (px)
    this.threshold = 120;
    this.autoPin = true;

    // Debounce state
    this._rafId = null;
    this._pendingBehavior = null;

    // Track user scroll to toggle auto pin
    this._onScroll = () => {
      this.autoPin = this.shouldAutoPin();
    };
    this.el.addEventListener("scroll", this._onScroll, { passive: true });

    // Observe size changes (fonts/images/streaming)
    if ("ResizeObserver" in window) {
      this._resizeObserver = new ResizeObserver(() => {
        if (this.autoPin) this.scheduleScroll("resize", "auto");
      });
      this._resizeObserver.observe(this.el);
    }

    // Observe DOM mutations (new messages, edits)
    if ("MutationObserver" in window) {
      this._mutationObserver = new MutationObserver(() => {
        if (this.autoPin) this.scheduleScroll("mutation", "auto");
      });
      this._mutationObserver.observe(this.el, {
        childList: true,
        subtree: true,
      });
    }

    // Clear the chat input as soon as the form is submitted (prevents lingering)
    this._formEl = document.getElementById("content-panel-chat-form");
    this._inputEl = document.getElementById("content-panel-chat-input");
    if (this._formEl) {
      this._onFormSubmit = () => {
        if (this._inputEl) this._inputEl.value = "";
        // Stay pinned and make sure we’re at the bottom as the AI starts streaming
        this.autoPin = true;
        this.scheduleScroll("submit", "auto");
      };
      this._formEl.addEventListener("submit", this._onFormSubmit, true);
    }

    // Initial alignment if we’re already near the bottom
    if (this.autoPin) this.scheduleScroll("mounted", "auto");
  },

  updated() {
    // After LV patches, only scroll if still pinned
    if (this.autoPin) this.scheduleScroll("lv-updated", "smooth");
  },

  destroyed() {
    if (this._onScroll) {
      try {
        this.el.removeEventListener("scroll", this._onScroll);
      } catch (_) {}
    }
    if (this._resizeObserver) {
      try {
        this._resizeObserver.disconnect();
      } catch (_) {}
    }
    if (this._mutationObserver) {
      try {
        this._mutationObserver.disconnect();
      } catch (_) {}
    }
    if (this._formEl && this._onFormSubmit) {
      try {
        this._formEl.removeEventListener("submit", this._onFormSubmit, true);
      } catch (_) {}
    }
  },

  // --- Helpers ---

  shouldAutoPin() {
    const el = this.el;
    const distanceFromBottom = el.scrollHeight - el.scrollTop - el.clientHeight;
    return distanceFromBottom <= this.threshold;
  },

  scheduleScroll(_reason, behavior = "auto") {
    // Coalesce multiple triggers into one rAF
    this._pendingBehavior = behavior;
    if (this._rafId != null) return;

    this._rafId = requestAnimationFrame(() => {
      const b = this._pendingBehavior || "auto";
      this._rafId = null;
      this._pendingBehavior = null;
      this.performScroll(b);
    });
  },

  performScroll(behavior = "auto") {
    const el = this.el;

    // Temporarily override CSS scroll-behavior to ensure programmatic control
    const prevBehavior = el.style.scrollBehavior;
    try {
      el.style.scrollBehavior = "auto";

      // Two-phase scroll to capture any height growth between frames
      const scrollOnce = (b) => {
        const top = el.scrollHeight;
        if (typeof el.scrollTo === "function") {
          el.scrollTo({ top, behavior: b });
        } else {
          el.scrollTop = top;
        }
      };

      // First pass
      scrollOnce(behavior);

      // Second pass in next frame to catch any additional growth
      requestAnimationFrame(() => {
        scrollOnce(behavior);
      });
    } finally {
      // Restore previous inline behavior (class-based styles remain in effect)
      el.style.scrollBehavior = prevBehavior || "";
    }
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

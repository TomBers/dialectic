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
import SelectionActionsHook from "./selection_actions_hook.js";
import graphHook from "./graph_hook.js";
import highlightNodeHook from "./highlight_node_hook.js";
import printConversationHook from "./print_conversation_hook.js";
import storyReadabilityHook from "./story_readability_hook.js";
import listDetectionHook from "./list_detection_hook.js";
import translatePopoverHook from "./translate_popover_hook.js";
import MarkdownHook from "./markdown_hook.js";
import InterfaceHighlightHook from "./how/interface_highlight_hook.js";
import { ViewModeHook } from "./view_mode_hook.js";
import AutoExpandTextareaHook from "./auto_expand_textarea_hook.js";

let hooks = {};

// Hook - handles all positioning logic
hooks.TextSelectionHook = textSelectionHook;
hooks.SelectionActions = SelectionActionsHook;
hooks.Graph = graphHook;
hooks.HighlightNode = highlightNodeHook;
hooks.PrintConversation = printConversationHook;
hooks.StoryReadability = storyReadabilityHook;
hooks.ListDetection = listDetectionHook;

hooks.TranslatePopover = translatePopoverHook;
hooks.Markdown = MarkdownHook;
hooks.InterfaceHighlight = InterfaceHighlightHook;
hooks.ViewMode = ViewModeHook;
hooks.AutoExpandTextarea = AutoExpandTextareaHook;

hooks.GraphLayout = {
  mounted() {
    this.el.addEventListener("toggle-panel", (e) => {
      const { id } = e.detail;
      const panels = ["right-panel", "graph-nav-drawer", "highlights-drawer"];
      const targetPanel = document.getElementById(id);

      if (!targetPanel) return;

      const isClosed = targetPanel.classList.contains("translate-x-full");

      // Close all panels first
      panels.forEach((pId) => {
        const p = document.getElementById(pId);
        if (p) {
          p.classList.add("translate-x-full", "opacity-0", "w-0");
          p.classList.remove(
            "translate-x-0",
            "opacity-100",
            "w-full",
            "sm:w-96",
          );
        }

        const btn = document.querySelector(`[data-panel-toggle="${pId}"]`);
        if (btn) {
          btn.classList.remove("bg-indigo-50", "text-indigo-600");
          btn.classList.add(
            "text-gray-500",
            "hover:bg-gray-100",
            "hover:text-gray-900",
          );
        }
      });

      const elementsToShift = document.querySelectorAll(".shift-with-panel");

      if (isClosed) {
        // Open the target
        targetPanel.classList.remove("translate-x-full", "opacity-0", "w-0");
        targetPanel.classList.add(
          "translate-x-0",
          "opacity-100",
          "w-full",
          "sm:w-96",
        );

        elementsToShift.forEach((el) => {
          el.classList.add("right-80", "sm:right-96");
        });

        const btn = document.querySelector(`[data-panel-toggle="${id}"]`);
        if (btn) {
          btn.classList.add("bg-indigo-50", "text-indigo-600");
          btn.classList.remove(
            "text-gray-500",
            "hover:bg-gray-100",
            "hover:text-gray-900",
          );
        }
      } else {
        // Everything is closed now
        elementsToShift.forEach((el) => {
          el.classList.remove("right-80", "sm:right-96");
        });
      }
    });

    this.el.addEventListener("toggle-side-drawer", (e) => {
      const drawer = document.getElementById("side-drawer");
      const graphContainer = document.getElementById("graph-main-container");
      const toggleBtn = document.getElementById("drawer-toggle");
      const bottomElements = document.querySelectorAll(".shift-with-panel");

      if (!drawer) return;

      const isClosed = drawer.classList.contains("-translate-x-full");
      let shouldOpen = isClosed;

      if (e.detail && e.detail.force) {
        if (e.detail.force === "open") shouldOpen = true;
        if (e.detail.force === "close") shouldOpen = false;
      }

      if (shouldOpen) {
        // OPENING
        drawer.classList.remove(
          "-translate-x-full",
          "opacity-0",
          "w-0",
          "md:w-0",
          "overflow-hidden",
        );
        drawer.classList.add(
          "translate-x-0",
          "opacity-100",
          "w-full",
          "md:w-2/5",
          "p-4",
        );

        if (graphContainer) {
          graphContainer.classList.remove("w-full");
          graphContainer.classList.add("md:w-3/5");
        }

        if (toggleBtn) {
          toggleBtn.classList.remove("left-2");
          toggleBtn.classList.add(
            "right-2",
            "md:left-[40%]",
            "md:ml-2",
            "md:right-auto",
          );
          const path = toggleBtn.querySelector("path");
          if (path) path.setAttribute("d", "M11 19l-7-7 7-7");
          toggleBtn.setAttribute("aria-expanded", "true");
          toggleBtn.setAttribute("aria-label", "Hide menu");
        }

        bottomElements.forEach((el) => {
          el.classList.add("md:left-[40%]");
        });
      } else {
        // CLOSING
        drawer.classList.remove(
          "translate-x-0",
          "opacity-100",
          "w-full",
          "md:w-2/5",
          "p-4",
        );
        drawer.classList.add(
          "-translate-x-full",
          "opacity-0",
          "w-0",
          "md:w-0",
          "overflow-hidden",
        );

        if (graphContainer) {
          graphContainer.classList.remove("md:w-3/5");
          graphContainer.classList.add("w-full");
        }

        if (toggleBtn) {
          toggleBtn.classList.remove(
            "right-2",
            "md:left-[40%]",
            "md:ml-2",
            "md:right-auto",
          );
          toggleBtn.classList.add("left-2");
          const path = toggleBtn.querySelector("path");
          if (path) path.setAttribute("d", "M13 5l7 7-7 7");
          toggleBtn.setAttribute("aria-expanded", "false");
          toggleBtn.setAttribute("aria-label", "Show menu");
        }

        bottomElements.forEach((el) => {
          el.classList.remove("md:left-[40%]");
        });
      }

      window.dispatchEvent(new Event("resize"));
    });

    this.el.addEventListener("toggle-bottom-menu", () => {
      const menu = document.getElementById("bottom-menu");
      const handle = document.getElementById("bottom-menu-handle");

      if (!menu) return;

      const isVisible = menu.classList.contains("visible");

      if (isVisible) {
        menu.classList.remove("scale-100", "opacity-100", "visible");
        menu.classList.add("scale-90", "opacity-0", "invisible");
        if (handle) handle.classList.remove("hidden");
      } else {
        menu.classList.remove("scale-90", "opacity-0", "invisible");
        menu.classList.add("scale-100", "opacity-100", "visible");
        if (handle) handle.classList.add("hidden");
      }
    });
  },
};

hooks.LinearView = {
  mounted() {
    this.handleEvent("scroll_to_node", ({ id }) => {
      const el = document.getElementById(`node-${id}`);
      if (el) {
        el.scrollIntoView({ behavior: "smooth", block: "start" });
      }
    });
  },
};

hooks.MobileMinimap = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      const button = e.target.closest("button[id^='map-node-']");
      if (button && window.innerWidth < 1024) {
        this.pushEvent("close_minimap", {});
      }
    });
  },
};

hooks.ExplorationStats = {
  mounted() {
    this.updateStats();
  },
  updated() {
    this.updateStats();
  },
  updateStats() {
    const graphId = this.el.dataset.graphId;
    if (!graphId) return;

    const total = parseInt(this.el.dataset.total || "0");
    const storageKey = `dialectic_explored_${graphId}`;

    try {
      const stored = localStorage.getItem(storageKey);
      let exploredCount = 0;
      if (stored) {
        const exploredList = JSON.parse(stored);
        exploredCount = exploredList.length;
      }

      this.el.textContent = `${exploredCount} / ${total} explored`;
      this.el.classList.remove("hidden");
    } catch (e) {
      this.el.textContent = `0 / ${total} explored`;
      this.el.classList.remove("hidden");
    }
  },
};

// Chat scroll management hook
hooks.ChatScroll = {
  mounted() {
    this.scrollToBottom();
  },

  updated() {
    this.scrollToBottom();
  },

  scrollToBottom() {
    requestAnimationFrame(() => {
      this.el.scrollTop = this.el.scrollHeight;
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

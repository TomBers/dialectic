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
import toolTipHook from "./tool_tip_hook.js";
import textSelectionHook from "./text_selection_hook.js";
import graphHook from "./graph_hook.js";

let hooks = {};

// Hook - handles all positioning logic
hooks.NodeMenuHook = toolTipHook;
hooks.TextSelectionHook = textSelectionHook;
hooks.Graph = graphHook;
hooks.InfiniteScroll = {
  mounted() {
    const container = this.el;
    let loading = false;

    // Save initial scroll position to maintain it when new messages come in
    const saveScrollPosition = () => {
      this.scrollTop = container.scrollTop;
      this.scrollHeight = container.scrollHeight;
    };

    // Restore scroll position after new content is loaded
    const restoreScrollPosition = () => {
      if (this.scrollTop) {
        const newScrollTop =
          container.scrollHeight - this.scrollHeight + this.scrollTop;
        container.scrollTop = newScrollTop;
      }
    };

    // Auto-scroll to bottom when the user is already at the bottom
    const autoScrollToBottom = () => {
      const isAtBottom =
        container.scrollHeight - container.scrollTop - container.clientHeight <
        30;
      if (isAtBottom) {
        setTimeout(() => {
          container.scrollTop = container.scrollHeight;
        }, 50);
      }
    };

    // Event handler for scrolling
    container.addEventListener("scroll", () => {
      if (loading) return;

      // When user scrolls to top, load more messages
      if (container.scrollTop < 50) {
        saveScrollPosition();
        loading = true;

        this.pushEvent("load_more", {}, (reply) => {
          loading = false;
          // If there are no more messages, don't try to load more
          if (!reply || !reply.has_more) {
            container.removeEventListener("scroll", this);
          }

          setTimeout(() => {
            restoreScrollPosition();
          }, 100);
        });
      }
    });

    // Scroll to the bottom initially when component is mounted
    setTimeout(() => {
      container.scrollTop = container.scrollHeight;
    }, 100);

    // Handle scrolling when new messages come in
    this.handleEvent("chat_updated", () => {
      autoScrollToBottom();
    });
  },
};

hooks.ChatScroll = {
  mounted() {
    this.scrollToBottom();

    // Listen for chat updates
    this.handleEvent("chat_updated", () => {
      this.scrollToBottom();
    });
  },
  updated() {
    this.scrollToBottom();
  },
  scrollToBottom() {
    // Only auto-scroll if the user is already near the bottom
    // const isNearBottom =
    //   this.el.scrollHeight - this.el.clientHeight - this.el.scrollTop < 100;

    // if (isNearBottom) {
    this.el.scrollTop = this.el.scrollHeight;
    // }
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

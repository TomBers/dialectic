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
import ScrollResetHook from "./scroll_reset_hook.js";

import MarkdownHook from "./markdown_hook.js";

import { ViewModeHook } from "./view_mode_hook.js";
import AutoExpandTextareaHook from "./auto_expand_textarea_hook.js";
import SearchNav from "./search_nav_hook.js";
import PresentationHook, {
  PresentationSetupHook,
} from "./presentation_hook.js";
import ShareHook from "./share_hook.js";

let hooks = {};

// Hook - handles all positioning logic
hooks.TextSelectionHook = textSelectionHook;
hooks.SelectionActions = SelectionActionsHook;
hooks.Graph = graphHook;
hooks.HighlightNode = highlightNodeHook;
hooks.PrintConversation = printConversationHook;
hooks.StoryReadability = storyReadabilityHook;
hooks.ListDetection = listDetectionHook;
hooks.ScrollReset = ScrollResetHook;

hooks.Markdown = MarkdownHook;

hooks.ViewMode = ViewModeHook;
hooks.AutoExpandTextarea = AutoExpandTextareaHook;
hooks.SearchNav = SearchNav;
hooks.Presentation = PresentationHook;
hooks.PresentationSetup = PresentationSetupHook;
hooks.Share = ShareHook;
hooks.PersistCollapse = {
  mounted() {
    this.restore();
  },
  updated() {
    this.restore();
  },
  restore() {
    const storageKey = this.el.dataset.collapseKey;
    if (!storageKey) return;

    let collapsed = false;
    try {
      collapsed = localStorage.getItem(storageKey) === "collapsed";
    } catch (_e) {
      collapsed = false;
    }

    const body = this.el.querySelector("[data-collapse-body]");
    const icon = this.el.querySelector("[data-collapse-icon]");
    if (!body || !icon) return;

    body.classList.toggle("hidden", collapsed);
    icon.classList.toggle("rotate-180", collapsed);
  },
};

hooks.PasswordToggle = {
  mounted() {
    this.el.addEventListener("click", () => {
      const wrapper = this.el.closest("[data-password-wrapper]");
      if (!wrapper) return;
      const input = wrapper.querySelector("input");
      if (!input) return;
      const isPassword = input.type === "password";
      input.type = isPassword ? "text" : "password";
      const eyeOpen = this.el.querySelector("[data-eye-open]");
      const eyeSlash = this.el.querySelector("[data-eye-slash]");
      if (eyeOpen && eyeSlash) {
        eyeOpen.classList.toggle("hidden", !isPassword);
        eyeSlash.classList.toggle("hidden", isPassword);
      }
      this.el.setAttribute("aria-pressed", isPassword ? "true" : "false");
      this.el.setAttribute(
        "aria-label",
        isPassword ? "Hide password" : "Show password",
      );
    });
  },
};

hooks.MobileRedirect = {
  mounted() {
    // Only redirect on small screens (matches lg:hidden breakpoint)
    if (window.innerWidth < 1024) {
      const url = this.el.dataset.linearUrl;
      if (url) {
        window.location.href = url;
      }
    }
  },
};

hooks.GraphLayout = {
  mounted() {
    this.activePanelId = null;
    const graphId = this.el.dataset.graphId || "global";
    const validReadingDensities = ["compact", "comfortable", "large"];
    const validReadingFonts = ["sans", "serif"];
    this._drawerStorageKey = `rg:drawer:${graphId}`;
    this._bottomMenuStorageKey = `rg:bottom-menu:${graphId}`;
    this._readingDensityStorageKey = `rg:reading-density:${graphId}`;
    this._readingFontStorageKey = `rg:reading-font:${graphId}`;

    const readStoredBool = (key) => {
      try {
        const raw = localStorage.getItem(key);
        if (raw === "true") return true;
        if (raw === "false") return false;
      } catch (_e) {}
      return null;
    };

    const storedDrawer = readStoredBool(this._drawerStorageKey);
    const storedBottomMenu = readStoredBool(this._bottomMenuStorageKey);
    const storedReadingDensity = (() => {
      try {
        return localStorage.getItem(this._readingDensityStorageKey);
      } catch (_e) {
        return null;
      }
    })();
    const storedReadingFont = (() => {
      try {
        return localStorage.getItem(this._readingFontStorageKey);
      } catch (_e) {
        return null;
      }
    })();

    this.sideDrawerOpen = storedDrawer !== null ? storedDrawer : true;
    this.bottomMenuOpen = storedBottomMenu !== null ? storedBottomMenu : true;
    this.readingDensity = validReadingDensities.includes(storedReadingDensity)
      ? storedReadingDensity
      : "comfortable";
    this.readingFont = validReadingFonts.includes(storedReadingFont)
      ? storedReadingFont
      : "serif";
    this._applyReadingDensity(this.readingDensity);
    this._applyReadingFont(this.readingFont);

    this.el.addEventListener("set-reading-density", (e) => {
      const nextDensity = e?.detail?.value;
      if (!validReadingDensities.includes(nextDensity)) return;

      this.readingDensity = nextDensity;
      this._applyReadingDensity(this.readingDensity);

      try {
        localStorage.setItem(this._readingDensityStorageKey, nextDensity);
      } catch (_e) {}
    });

    this.el.addEventListener("set-reading-font", (e) => {
      const nextFont = e?.detail?.value;
      if (!validReadingFonts.includes(nextFont)) return;

      this.readingFont = nextFont;
      this._applyReadingFont(this.readingFont);

      try {
        localStorage.setItem(this._readingFontStorageKey, nextFont);
      } catch (_e) {}
    });

    this.el.addEventListener("toggle-panel", (e) => {
      const { id } = e.detail;
      const panels = [
        "right-panel",
        "highlights-drawer",
        "presentation-drawer",
        "combine-drawer",
      ];
      const targetPanel = document.getElementById(id);

      if (!targetPanel) return;

      const isClosed = targetPanel.classList.contains("translate-x-full");

      // Track whether the presentation drawer was open before we close everything
      const presDrawer = document.getElementById("presentation-drawer");
      const presWasOpen =
        presDrawer && !presDrawer.classList.contains("translate-x-full");

      // Track whether the combine drawer was open before we close everything
      const combineDrawer = document.getElementById("combine-drawer");
      const combineWasOpen =
        combineDrawer && !combineDrawer.classList.contains("translate-x-full");

      // Close all panels first
      panels.forEach((pId) => {
        const p = document.getElementById(pId);
        if (p) {
          p.classList.add(
            "translate-x-full",
            "opacity-0",
            "w-0",
            "overflow-hidden",
          );
          p.classList.remove(
            "translate-x-0",
            "opacity-100",
            "w-full",
            "sm:w-96",
            "overflow-y-auto",
          );
        }

        const btn = document.querySelector(`[data-panel-toggle="${pId}"]`);
        if (btn) {
          btn.classList.remove(
            "ring-2",
            "ring-offset-1",
            "ring-white",
            "scale-110",
          );
        }
      });

      // If a *different* panel is opening and the presentation drawer was open,
      // notify the server so it can leave setup mode.
      // We skip this when the presentation button itself is toggled — that
      // button already pushes its own "enter_presentation_setup" server event.
      if (presWasOpen && id !== "presentation-drawer") {
        this.pushEvent("close_presentation_setup", {});
      }

      // If a *different* panel is opening and the combine drawer was open,
      // notify the server so it can leave combine setup mode.
      if (combineWasOpen && id !== "combine-drawer") {
        this.pushEvent("close_combine_setup", {});
      }

      const elementsToShift = document.querySelectorAll(".shift-with-panel");
      const bottomMenu = document.getElementById("bottom-menu");

      if (isClosed) {
        this.activePanelId = id;
        // Open the target
        targetPanel.classList.remove(
          "translate-x-full",
          "opacity-0",
          "w-0",
          "overflow-hidden",
        );
        targetPanel.classList.add(
          "translate-x-0",
          "opacity-100",
          "w-full",
          "sm:w-96",
          "overflow-y-auto",
        );

        elementsToShift.forEach((el) => {
          el.classList.add("right-80", "sm:right-96");
        });

        if (bottomMenu) bottomMenu.classList.add("panel-open");

        const btn = document.querySelector(`[data-panel-toggle="${id}"]`);
        if (btn) {
          btn.classList.add(
            "ring-2",
            "ring-offset-1",
            "ring-white",
            "scale-110",
          );
        }
      } else {
        this.activePanelId = null;
        // Everything is closed now
        elementsToShift.forEach((el) => {
          el.classList.remove("right-80", "sm:right-96");
        });

        if (bottomMenu) bottomMenu.classList.remove("panel-open");
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

      this.sideDrawerOpen = shouldOpen;
      try {
        localStorage.setItem(
          this._drawerStorageKey,
          String(this.sideDrawerOpen),
        );
      } catch (_e) {}

      if (shouldOpen) {
        this.sideDrawerOpen = true;
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
          "md:w-[44%]",
          "p-4",
        );

        if (graphContainer) {
          graphContainer.classList.remove("w-full");
          graphContainer.classList.add("md:w-[56%]");
        }

        if (toggleBtn) {
          toggleBtn.classList.remove("left-2");
          toggleBtn.classList.add(
            "right-2",
            "md:left-[44%]",
            "md:ml-2",
            "md:right-auto",
          );
          const path = toggleBtn.querySelector("path");
          if (path) path.setAttribute("d", "M11 19l-7-7 7-7");
          toggleBtn.setAttribute("aria-expanded", "true");
          toggleBtn.setAttribute("aria-label", "Hide menu");
        }

        bottomElements.forEach((el) => {
          el.classList.add("md:left-[44%]");
        });
      } else {
        this.sideDrawerOpen = false;
        // CLOSING
        drawer.classList.remove(
          "translate-x-0",
          "opacity-100",
          "w-full",
          "md:w-[44%]",
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
          graphContainer.classList.remove("md:w-[56%]");
          graphContainer.classList.add("w-full");
        }

        if (toggleBtn) {
          toggleBtn.classList.remove(
            "right-2",
            "md:left-[44%]",
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
          el.classList.remove("md:left-[44%]");
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
        this.bottomMenuOpen = false;
        menu.classList.remove("scale-100", "opacity-100", "visible");
        menu.classList.add("scale-90", "opacity-0", "invisible");
        if (handle) handle.classList.remove("hidden");
      } else {
        this.bottomMenuOpen = true;
        menu.classList.remove("scale-90", "opacity-0", "invisible");
        menu.classList.add("scale-100", "opacity-100", "visible");
        if (handle) handle.classList.add("hidden");
      }

      try {
        localStorage.setItem(
          this._bottomMenuStorageKey,
          String(this.bottomMenuOpen),
        );
      } catch (_e) {}
    });

    this.restoreState();

    // ── Presentation localStorage persistence ──────────────────────
    this.handleEvent(
      "presentation_persist",
      ({ graph_id, slide_ids, title }) => {
        if (!graph_id) return;
        const key = `rg:pres:${graph_id}`;
        try {
          const hasSlides = slide_ids && slide_ids.length > 0;
          const hasTitle = title && title.length > 0;
          if (!hasSlides && !hasTitle) {
            localStorage.removeItem(key);
          } else {
            localStorage.setItem(
              key,
              JSON.stringify({
                slide_ids: slide_ids || [],
                title: title || "",
                ts: Date.now(),
              }),
            );
          }
        } catch (_e) {
          // localStorage may be unavailable (private browsing, quota, etc.)
        }
      },
    );

    // On mount, check for a saved presentation for this graph and restore it
    if (graphId) {
      try {
        const raw = localStorage.getItem(`rg:pres:${graphId}`);
        if (raw) {
          const saved = JSON.parse(raw);
          if (saved) {
            const hasSlides =
              Array.isArray(saved.slide_ids) && saved.slide_ids.length > 0;
            const hasTitle = saved.title && saved.title.length > 0;
            if (hasSlides || hasTitle) {
              this.pushEvent("restore_presentation", {
                slide_ids: Array.isArray(saved.slide_ids)
                  ? saved.slide_ids
                  : [],
                title: saved.title || "",
              });
            }
          }
        }
      } catch (_e) {
        // Ignore parse errors or missing storage
      }
    }
  },
  updated() {
    this.restoreState();
  },
  reconnected() {
    this.restoreState();
  },
  restoreState() {
    if (this.readingDensity) {
      this._applyReadingDensity(this.readingDensity);
    }
    if (this.readingFont) {
      this._applyReadingFont(this.readingFont);
    }

    // Restore side drawer state
    const drawer = document.getElementById("side-drawer");
    if (drawer && this.sideDrawerOpen !== undefined) {
      const isClosed = drawer.classList.contains("-translate-x-full");
      if (this.sideDrawerOpen && isClosed) {
        this.el.dispatchEvent(
          new CustomEvent("toggle-side-drawer", { detail: { force: "open" } }),
        );
      } else if (!this.sideDrawerOpen && !isClosed) {
        this.el.dispatchEvent(
          new CustomEvent("toggle-side-drawer", { detail: { force: "close" } }),
        );
      }
    }

    // Restore bottom menu state
    const bottomMenu = document.getElementById("bottom-menu");
    if (bottomMenu && this.bottomMenuOpen !== undefined) {
      const isVisible = bottomMenu.classList.contains("visible");
      if (this.bottomMenuOpen && !isVisible) {
        this.el.dispatchEvent(new Event("toggle-bottom-menu"));
      } else if (!this.bottomMenuOpen && isVisible) {
        this.el.dispatchEvent(new Event("toggle-bottom-menu"));
      }
    }

    if (!this.activePanelId) return;
    const panel = document.getElementById(this.activePanelId);
    if (!panel) return;

    // Check if it got closed by server update
    if (panel.classList.contains("translate-x-full")) {
      // Re-open it
      panel.classList.remove(
        "translate-x-full",
        "opacity-0",
        "w-0",
        "overflow-hidden",
      );
      panel.classList.add(
        "translate-x-0",
        "opacity-100",
        "w-full",
        "sm:w-96",
        "overflow-y-auto",
      );

      // Re-apply shift
      const elementsToShift = document.querySelectorAll(".shift-with-panel");
      elementsToShift.forEach((el) => {
        el.classList.add("right-80", "sm:right-96");
      });

      const bottomMenu = document.getElementById("bottom-menu");
      if (bottomMenu) bottomMenu.classList.add("panel-open");

      // Re-activate button
      const btn = document.querySelector(
        `[data-panel-toggle="${this.activePanelId}"]`,
      );
      if (btn) {
        btn.classList.add("ring-2", "ring-offset-1", "ring-white", "scale-110");
      }
    }
  },
  _applyReadingDensity(value) {
    const validReadingDensities = ["compact", "comfortable", "large"];
    const nextDensity = validReadingDensities.includes(value)
      ? value
      : "comfortable";

    this.readingDensity = nextDensity;
    this.el.setAttribute("data-reading-density", nextDensity);
    this._syncReadingDensityButtons();
  },
  _syncReadingDensityButtons() {
    const buttons = this.el.querySelectorAll("[data-reading-density-option]");
    buttons.forEach((btn) => {
      const selected = btn.dataset.readingDensityOption === this.readingDensity;
      btn.setAttribute("aria-pressed", selected ? "true" : "false");
    });
  },
  _applyReadingFont(value) {
    const validReadingFonts = ["sans", "serif"];
    const nextFont = validReadingFonts.includes(value) ? value : "serif";

    this.readingFont = nextFont;
    this.el.setAttribute("data-reading-font", nextFont);
    this._syncReadingFontButtons();
  },
  _syncReadingFontButtons() {
    const buttons = this.el.querySelectorAll("[data-reading-font-option]");
    buttons.forEach((btn) => {
      const selected = btn.dataset.readingFontOption === this.readingFont;
      btn.setAttribute("aria-pressed", selected ? "true" : "false");
    });
  },
};

hooks.LinearView = {
  mounted() {
    // Scroll both the main content and the minimap to a given node.
    // `block` defaults to "nearest" so already-visible nodes don't jump.
    // Callers that need the node pinned to the top can pass "start".
    //
    // Uses a short polling loop to wait for LiveView to finish patching
    // the DOM before measuring positions — the target element may not
    // exist yet when the event fires (e.g. after a branch switch).
    const scrollToNode = (
      id,
      { behavior = "smooth", block = "nearest" } = {},
    ) => {
      let attempts = 0;
      const maxAttempts = 10;

      const tryScroll = () => {
        const el = document.getElementById(`node-${id}`);
        if (el) {
          requestAnimationFrame(() => {
            el.scrollIntoView({ behavior, block });

            // Also scroll the minimap entry into view
            const mapEntry = document.getElementById(`map-node-${id}`);
            if (mapEntry) {
              mapEntry.scrollIntoView({ behavior, block: "nearest" });
            }
          });
        } else if (attempts < maxAttempts) {
          attempts++;
          // Retry after a short delay to let LiveView finish patching
          setTimeout(tryScroll, 50);
        }
      };

      tryScroll();
    };

    this.handleEvent("scroll_to_node", ({ id, block }) => {
      scrollToNode(id, { block: block || "nearest" });
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
  ?.getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  hooks: hooks,
  params: { _csrf_token: csrfToken },
  metadata: {
    keydown: (e, el) => {
      // console.log(e);
      // console.log(el);
      const target = e.target;
      const tag = (target && target.tagName) || "";
      const isEditable =
        tag === "INPUT" ||
        tag === "TEXTAREA" ||
        (target &&
          (target.isContentEditable ||
            target.closest('[contenteditable="true"], [contenteditable=""]')));
      return {
        key: e.key,
        cmdKey: e.ctrlKey,
        metaKey: e.metaKey,
        repeat: e.repeat,
        isEditable: !!isEditable,
      };
    },
  },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// Focus input element when requested by the server
window.addEventListener("phx:focus_input", (e) => {
  const id = e.detail?.id;
  if (id) {
    const el = document.getElementById(id);
    if (el) {
      // Small delay to ensure DOM is ready after LiveView updates
      requestAnimationFrame(() => {
        el.focus();
      });
    }
  }
});

// Allow Escape key to blur focused inputs and restore keyboard shortcuts
window.addEventListener("keydown", (e) => {
  if (e.key === "Escape") {
    const target = e.target;
    const tag = target?.tagName || "";
    if (tag === "INPUT" || tag === "TEXTAREA") {
      target.blur();
    }
  }
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

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
import storyReadabilityHook from "./story_readability_hook.js";
import listDetectionHook from "./list_detection_hook.js";
import ScrollResetHook from "./scroll_reset_hook.js";
import OutlineNavHook from "./outline_nav_hook.js";

import MarkdownHook from "./markdown_hook.js";

import { ViewModeHook } from "./view_mode_hook.js";
import AutoExpandTextareaHook from "./auto_expand_textarea_hook.js";
import SearchNav from "./search_nav_hook.js";
import PresentationHook, {
  PresentationSetupHook,
} from "./presentation_hook.js";
import ShareHook from "./share_hook.js";
import GridChatFormHook from "./grid_chat_form_hook.js";

let hooks = {};

// Hook - handles all positioning logic
hooks.TextSelectionHook = textSelectionHook;
hooks.SelectionActions = SelectionActionsHook;
hooks.Graph = graphHook;
hooks.HighlightNode = highlightNodeHook;
hooks.StoryReadability = storyReadabilityHook;
hooks.ListDetection = listDetectionHook;
hooks.ScrollReset = ScrollResetHook;
hooks.OutlineNav = OutlineNavHook;

hooks.Markdown = MarkdownHook;

hooks.ViewMode = ViewModeHook;
hooks.AutoExpandTextarea = AutoExpandTextareaHook;
hooks.SearchNav = SearchNav;
hooks.Presentation = PresentationHook;
hooks.PresentationSetup = PresentationSetupHook;
hooks.Share = ShareHook;
hooks.GridChatForm = GridChatFormHook;
hooks.GlobalModalLayer = {
  mounted() {
    const header = document.getElementById("userHeader");
    if (!header) return;

    const currentCount = Number(document.body.dataset.globalModalCount || "0");
    const nextCount = currentCount + 1;
    document.body.dataset.globalModalCount = String(nextCount);

    if (currentCount === 0) {
      document.documentElement.classList.add("global-modal-open");
      header.dataset.prevOpacity = header.style.opacity || "";
      header.dataset.prevPointerEvents = header.style.pointerEvents || "";
      header.style.opacity = "0";
      header.style.pointerEvents = "none";
    }
  },

  destroyed() {
    const header = document.getElementById("userHeader");
    if (!header) return;

    const currentCount = Number(document.body.dataset.globalModalCount || "1");
    const nextCount = Math.max(0, currentCount - 1);

    if (nextCount === 0) {
      document.documentElement.classList.remove("global-modal-open");
      header.style.opacity = header.dataset.prevOpacity || "";
      header.style.pointerEvents = header.dataset.prevPointerEvents || "";
      delete header.dataset.prevOpacity;
      delete header.dataset.prevPointerEvents;
      delete document.body.dataset.globalModalCount;
    } else {
      document.body.dataset.globalModalCount = String(nextCount);
    }
  },
};

const MODE_SWITCH_TRANSITION_KEY = "mode-switch";
let modeSwitchCleanupTimer = null;

const clearModeSwitchClasses = () => {
  document.documentElement.classList.remove(
    "mode-switch-leave",
    "mode-switch-enter",
  );
  delete document.documentElement.dataset.viewTransitionDirection;
};

const scheduleModeSwitchCleanup = (delay = 320) => {
  window.clearTimeout(modeSwitchCleanupTimer);
  modeSwitchCleanupTimer = window.setTimeout(() => {
    clearModeSwitchClasses();
    delete document.documentElement.dataset.viewTransition;
  }, delay);
};

document.addEventListener(
  "click",
  (event) => {
    const link = event.target.closest('a[data-view-transition="mode-switch"]');
    if (!link) return;
    if (
      event.defaultPrevented ||
      event.button !== 0 ||
      event.metaKey ||
      event.ctrlKey ||
      event.shiftKey ||
      event.altKey
    ) {
      return;
    }

    document.documentElement.dataset.viewTransition = MODE_SWITCH_TRANSITION_KEY;
    document.documentElement.dataset.viewTransitionDirection =
      link.dataset.viewTransitionDirection || "";
    document.documentElement.classList.remove("mode-switch-enter");
    document.documentElement.classList.add("mode-switch-leave");
    scheduleModeSwitchCleanup(900);
  },
  true,
);

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

    const defaultState = this.el.dataset.collapseDefault;
    let collapsed = defaultState === "collapsed";
    try {
      const stored = localStorage.getItem(storageKey);
      if (stored === "collapsed") {
        collapsed = true;
      } else if (stored === "expanded") {
        collapsed = false;
      }
    } catch (_e) {
      collapsed = defaultState === "collapsed";
    }

    const body = this.el.querySelector("[data-collapse-body]");
    if (!body) return;

    const icon = this.el.querySelector("[data-collapse-icon]");
    const openState = this.el.querySelector("[data-collapse-open-state]");
    const closeState = this.el.querySelector("[data-collapse-close-state]");

    body.classList.toggle("hidden", collapsed);
    if (icon) icon.classList.toggle("rotate-180", collapsed);
    if (openState && closeState) {
      openState.classList.toggle("hidden", !collapsed);
      closeState.classList.toggle("hidden", collapsed);
    }
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

hooks.GraphLayout = {
  mounted() {
    this.activePanelId = null;
    this._reopenSideDrawerAfterPresentation = false;
    this._reopenSideDrawerAfterCombine = false;
    this._mobileOutlineCloseTimer = null;
    this._handleMobileGraphResize = () => {
      this._redirectMobileGraphToReader();
      this._syncOutlineDetailForPanel(this.activePanelId);
    };
    const graphId = this.el.dataset.graphId || "global";
    const validReadingDensities = ["compact", "comfortable", "large"];
    const validReadingFonts = ["sans", "serif"];
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

    this.sideDrawerOpen = true;
    this.bottomMenuOpen = storedBottomMenu !== null ? storedBottomMenu : true;
    this.readingDensity = validReadingDensities.includes(storedReadingDensity)
      ? storedReadingDensity
      : "comfortable";
    this.readingFont = validReadingFonts.includes(storedReadingFont)
      ? storedReadingFont
      : "serif";
    this._redirectMobileGraphToReader();
    this._applyReadingDensity(this.readingDensity);
    this._applyReadingFont(this.readingFont);
    this._closeAllPanels();
    this._syncOutlineDetailForPanel(null);
    window.addEventListener("resize", this._handleMobileGraphResize);

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
      const targetPanel = document.getElementById(id);

      if (!targetPanel) return;

      const isClosed = targetPanel.classList.contains("translate-x-full");

      if (id === "chat-drawer" && isClosed) {
        this.pushEvent("open_grid_chat", {});
      }

      const sideDrawer = document.getElementById("side-drawer");
      const sideDrawerIsOpen =
        sideDrawer && !sideDrawer.classList.contains("-translate-x-full");

      // Track whether the presentation drawer was open before we close everything
      const presDrawer = document.getElementById("presentation-drawer");
      const presWasOpen =
        presDrawer && !presDrawer.classList.contains("translate-x-full");

      // Track whether the combine drawer was open before we close everything
      const combineDrawer = document.getElementById("combine-drawer");
      const combineWasOpen =
        combineDrawer && !combineDrawer.classList.contains("translate-x-full");

      if (id === "presentation-drawer" && isClosed) {
        this._reopenSideDrawerAfterPresentation = true;
        if (sideDrawerIsOpen) {
          this._applySideDrawerState(false, {
            dispatchResize: false,
          });
        }
      }

      if (id === "combine-drawer" && isClosed) {
        this._reopenSideDrawerAfterCombine = true;
        if (sideDrawerIsOpen) {
          this._applySideDrawerState(false, {
            dispatchResize: false,
          });
        }
      }

      this._closeAllPanels();

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
        this._syncOutlineDetailForPanel(id);

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
        this._syncOutlineDetailForPanel(null);
      }

      const shouldRestoreSideDrawer =
        (this._reopenSideDrawerAfterPresentation &&
          ((presWasOpen && id !== "presentation-drawer") ||
            (id === "presentation-drawer" && !isClosed))) ||
        (this._reopenSideDrawerAfterCombine &&
          ((combineWasOpen && id !== "combine-drawer") ||
            (id === "combine-drawer" && !isClosed)));

      if (shouldRestoreSideDrawer) {
        this._applySideDrawerState(true, {
          dispatchResize: false,
        });
        this._reopenSideDrawerAfterPresentation = false;
        this._reopenSideDrawerAfterCombine = false;
      }

      window.dispatchEvent(new Event("resize"));
    });

    this.el.addEventListener("close-panel-on-mobile", (e) => {
      if (!window.matchMedia("(max-width: 639px)").matches) return;

      const { id } = e.detail || {};
      if (!id) return;

      const targetPanel = document.getElementById(id);
      if (!targetPanel) return;

      if (targetPanel.classList.contains("translate-x-full")) return;

      this._closeAllPanels();
      window.dispatchEvent(new Event("resize"));
    });

    this.el.addEventListener("toggle-side-drawer", (e) => {
      const drawer = document.getElementById("side-drawer");
      if (!drawer) return;

      const isClosed = drawer.classList.contains("-translate-x-full");
      let shouldOpen = isClosed;

      if (e.detail && e.detail.force) {
        if (e.detail.force === "open") shouldOpen = true;
        if (e.detail.force === "close") shouldOpen = false;
      }

      this._applySideDrawerState(shouldOpen);
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

      window.dispatchEvent(new Event("resize"));
    });

    this.el.addEventListener("toggle-mobile-outline", () => {
      const panel = document.getElementById("outline-mobile-nav-panel");
      if (!panel) return;

      this._applyMobileOutlineState(panel.classList.contains("hidden"));
    });

    this.el.addEventListener("close-mobile-outline", () => {
      this._applyMobileOutlineState(false);
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

    // On mount, check for a saved presentation for this graph and restore it.
    // Shared presentation URLs should win over any stale local draft.
    if (graphId) {
      try {
        const url = new URL(window.location.href);
        const hasSharedPresentation =
          url.searchParams.get("present") === "true" &&
          (url.searchParams.get("slides") || "").trim() !== "";

        if (hasSharedPresentation) {
          return;
        }

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
  _panelIds() {
    return [
      "right-panel",
      "highlights-drawer",
      "presentation-drawer",
      "combine-drawer",
      "chat-drawer",
    ];
  },
  _closeAllPanels() {
    this._panelIds().forEach((panelId) => {
      const panel = document.getElementById(panelId);
      if (panel) {
        panel.classList.add(
          "translate-x-full",
          "opacity-0",
          "w-0",
          "overflow-hidden",
        );
        panel.classList.remove(
          "translate-x-0",
          "opacity-100",
          "w-full",
          "sm:w-96",
          "overflow-y-auto",
        );
      }

      const btn = document.querySelector(`[data-panel-toggle="${panelId}"]`);
      if (btn) {
        btn.classList.remove(
          "ring-2",
          "ring-offset-1",
          "ring-white",
          "scale-110",
        );
      }
    });

    const elementsToShift = document.querySelectorAll(".shift-with-panel");
    elementsToShift.forEach((el) => {
      el.classList.remove("right-80", "sm:right-96");
    });

    const bottomMenu = document.getElementById("bottom-menu");
    if (bottomMenu) bottomMenu.classList.remove("panel-open");
    this._syncOutlineDetailForPanel(null);

    this.activePanelId = null;
  },
  _syncOutlineDetailForPanel(activePanelId) {
    const outlineDetail = document.getElementById("outline-detail");
    if (!outlineDetail) return;

    const reserveDrawerSpace =
      activePanelId === "highlights-drawer" &&
      window.matchMedia("(min-width: 1024px)").matches;

    outlineDetail.classList.toggle("lg:pr-96", reserveDrawerSpace);
  },
  _applySideDrawerState(shouldOpen, { dispatchResize = true } = {}) {
    const drawer = document.getElementById("side-drawer");
    const toggleBtn = document.getElementById("drawer-toggle");
    const bottomElements = document.querySelectorAll(".shift-with-panel");

    if (!drawer) return;

    this.sideDrawerOpen = shouldOpen;

    if (shouldOpen) {
      drawer.classList.remove(
        "-translate-x-full",
        "opacity-0",
        "w-0",
        "md:w-0",
        "overflow-hidden",
        "p-0",
      );
      drawer.classList.add(
        "translate-x-0",
        "opacity-100",
        "w-full",
        "p-4",
        "md:w-[var(--desktop-side-drawer-width)]",
        "md:p-0",
      );

      if (toggleBtn) {
        toggleBtn.classList.remove("left-2");
        toggleBtn.classList.add(
          "right-2",
          "md:left-[var(--desktop-side-drawer-width)]",
          "md:ml-2",
          "md:right-auto",
        );
        const path = toggleBtn.querySelector("path");
        if (path) path.setAttribute("d", "M11 19l-7-7 7-7");
        toggleBtn.setAttribute("aria-expanded", "true");
        toggleBtn.setAttribute("aria-label", "Hide menu");
      }

      bottomElements.forEach((el) => {
        el.classList.add("md:left-[var(--desktop-side-drawer-width)]");
      });
    } else {
      drawer.classList.remove(
        "translate-x-0",
        "opacity-100",
        "w-full",
        "p-4",
        "md:w-[var(--desktop-side-drawer-width)]",
        "md:p-0",
      );
      drawer.classList.add(
        "-translate-x-full",
        "opacity-0",
        "w-0",
        "md:w-0",
        "overflow-hidden",
        "p-0",
      );

      if (toggleBtn) {
        toggleBtn.classList.remove(
          "right-2",
          "md:left-[var(--desktop-side-drawer-width)]",
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
        el.classList.remove("md:left-[var(--desktop-side-drawer-width)]");
      });
    }

    if (dispatchResize) {
      window.dispatchEvent(new Event("resize"));
    }
  },
  updated() {
    this._redirectMobileGraphToReader();
    this.restoreState();
  },
  reconnected() {
    this._redirectMobileGraphToReader();
    this.restoreState();
  },
  destroyed() {
    if (this._mobileOutlineCloseTimer) {
      clearTimeout(this._mobileOutlineCloseTimer);
      this._mobileOutlineCloseTimer = null;
    }

    if (this._handleMobileGraphResize) {
      window.removeEventListener("resize", this._handleMobileGraphResize);
    }
  },
  _redirectMobileGraphToReader() {
    const mobileReaderPath = this.el.dataset.mobileReaderPath;
    const isGraphLayout = this.el.id === "graph-layout";
    const isPresenting = this.el.dataset.presenting === "true";

    if (!isGraphLayout || !mobileReaderPath || isPresenting) return;
    if (!window.matchMedia("(max-width: 767px)").matches) return;

    const currentPath = `${window.location.pathname}${window.location.search}`;
    if (currentPath === mobileReaderPath) return;

    window.location.replace(mobileReaderPath);
  },
  _applyMobileOutlineState(shouldOpen) {
    const panel = document.getElementById("outline-mobile-nav-panel");
    const button = document.getElementById("reader-workspace-bar-outline");

    if (!panel || !button) return;

    if (this._mobileOutlineCloseTimer) {
      clearTimeout(this._mobileOutlineCloseTimer);
      this._mobileOutlineCloseTimer = null;
    }

    if (shouldOpen) {
      panel.classList.remove("hidden", "pointer-events-none", "opacity-0", "translate-x-8");

      requestAnimationFrame(() => {
        panel.classList.remove("opacity-0", "translate-x-8");
        panel.classList.add("opacity-100", "translate-x-0");
      });
    } else {
      panel.classList.remove("opacity-100", "translate-x-0");
      panel.classList.add("opacity-0", "translate-x-8", "pointer-events-none");

      this._mobileOutlineCloseTimer = setTimeout(() => {
        panel.classList.add("hidden");
        this._mobileOutlineCloseTimer = null;
      }, 500);
    }

    button.setAttribute("aria-expanded", String(shouldOpen));

    const label = shouldOpen
      ? "Hide conversation outline"
      : "Show conversation outline";

    button.setAttribute("aria-label", label);
    button.setAttribute("title", label);

    button.classList.toggle("border-slate-300", shouldOpen);
    button.classList.toggle("bg-slate-100", shouldOpen);
    button.classList.toggle("text-slate-950", shouldOpen);
  },
  restoreState() {
    this._applyMobileOutlineState(false);

    if (this.readingDensity) {
      this._applyReadingDensity(this.readingDensity);
    }
    if (this.readingFont) {
      this._applyReadingFont(this.readingFont);
    }

    const presentationDrawer = document.getElementById("presentation-drawer");
    const combineDrawer = document.getElementById("combine-drawer");
    const shouldReopenAfterPresentation =
      this._reopenSideDrawerAfterPresentation &&
      this.activePanelId !== "presentation-drawer" &&
      (!presentationDrawer ||
        presentationDrawer.classList.contains("translate-x-full"));
    const shouldReopenAfterCombine =
      this._reopenSideDrawerAfterCombine &&
      this.activePanelId !== "combine-drawer" &&
      (!combineDrawer || combineDrawer.classList.contains("translate-x-full"));

    if (shouldReopenAfterPresentation || shouldReopenAfterCombine) {
      this.sideDrawerOpen = true;
      this._reopenSideDrawerAfterPresentation = false;
      this._reopenSideDrawerAfterCombine = false;
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

    if (!this.activePanelId) {
      this._closeAllPanels();
      return;
    }

    this._syncOutlineDetailForPanel(this.activePanelId);

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
window.addEventListener("phx:page-loading-stop", (_info) => {
  topbar.hide();

  if (document.documentElement.dataset.viewTransition !== MODE_SWITCH_TRANSITION_KEY) {
    return;
  }

  document.documentElement.classList.remove("mode-switch-leave");
  requestAnimationFrame(() => {
    document.documentElement.classList.add("mode-switch-enter");
    scheduleModeSwitchCleanup();
  });
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

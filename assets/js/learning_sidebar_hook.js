import { containModalFocus } from "./modal_focus.js";

const LearningSidebar = {
  mounted() {
    this.sidebar = document.getElementById("learning-sidebar");
    this.toggle = document.getElementById("learning-browse-toggle");
    this.closeButton = document.getElementById("learning-browse-close");
    this.backdrop = document.getElementById("learning-sidebar-backdrop");
    this.desktop = window.matchMedia("(min-width: 1024px)");
    this.open = false;
    this.js().ignoreAttributes(this.sidebar, [
      "data-open", "inert", "aria-hidden", "role", "aria-modal",
    ]);
    this.js().ignoreAttributes(this.toggle, ["aria-expanded"]);
    this.js().ignoreAttributes(this.backdrop, ["data-open"]);

    this.onOpen = () => this.openSidebar();
    this.onClose = () => this.closeSidebar();
    this.onNavigation = (event) => {
      if (["patch", "redirect"].includes(event.detail?.kind)) this.closeSidebar();
    };
    this.onPatch = () => this.modalFocus?.refresh();
    this.onSidebarClick = (event) => {
      if (
        event.target.closest("a[href]") && !event.defaultPrevented &&
        event.button === 0 && !event.metaKey && !event.ctrlKey &&
        !event.shiftKey && !event.altKey
      ) this.closeSidebar();
    };
    this.onBreakpoint = () => {
      const focusWasInside = this.sidebar.contains(document.activeElement);
      this.closeSidebar(false);
      this.syncState();
      if (!this.desktop.matches && focusWasInside) this.toggle.focus({ preventScroll: true });
    };

    this.toggle.addEventListener("click", this.onOpen);
    this.closeButton.addEventListener("click", this.onClose);
    this.backdrop.addEventListener("click", this.onClose);
    this.sidebar.addEventListener("click", this.onSidebarClick);
    this.desktop.addEventListener("change", this.onBreakpoint);
    window.addEventListener("phx:page-loading-start", this.onNavigation);
    document.addEventListener("phx:update", this.onPatch);
    this.syncState();
  },

  syncState() {
    const hidden = !this.desktop.matches && !this.open;
    this.sidebar.inert = hidden;
    if (hidden) this.sidebar.setAttribute("aria-hidden", "true");
    else this.sidebar.removeAttribute("aria-hidden");
    this.toggle.setAttribute("aria-expanded", String(this.open));
    this.sidebar.dataset.open = String(this.open);
    this.backdrop.dataset.open = String(this.open);
  },

  openSidebar() {
    if (this.desktop.matches || this.open) return;
    this.open = true;
    this.syncState();
    this.sidebar.setAttribute("role", "dialog");
    this.sidebar.setAttribute("aria-modal", "true");
    document.documentElement.classList.add("learning-sidebar-open");
    this.modalFocus = containModalFocus(this.sidebar, { onEscape: this.onClose });
    this.closeButton.focus({ preventScroll: true });
  },

  closeSidebar(restoreFocus = true) {
    if (!this.open) return;
    this.open = false;
    this.modalFocus?.destroy();
    this.modalFocus = null;
    document.documentElement.classList.remove("learning-sidebar-open");
    this.sidebar.removeAttribute("role");
    this.sidebar.removeAttribute("aria-modal");
    this.syncState();
    if (restoreFocus && this.toggle.isConnected) this.toggle.focus({ preventScroll: true });
  },

  destroyed() {
    this.closeSidebar(false);
    this.toggle.removeEventListener("click", this.onOpen);
    this.closeButton.removeEventListener("click", this.onClose);
    this.backdrop.removeEventListener("click", this.onClose);
    this.sidebar.removeEventListener("click", this.onSidebarClick);
    this.desktop.removeEventListener("change", this.onBreakpoint);
    window.removeEventListener("phx:page-loading-start", this.onNavigation);
    document.removeEventListener("phx:update", this.onPatch);
  },
};

export default LearningSidebar;

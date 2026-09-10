export class ToolsMenuController {
  constructor(el, trigger, onClose = () => {}) {
    this.el = el;
    this.trigger = trigger;
    this.onClose = onClose;
    this.opened = false;
    this.onKeydown = (event) => {
      if (event.key !== "Escape" || event.defaultPrevented || event.isComposing) return;
      event.preventDefault();
      event.stopPropagation();
      this.close(true);
    };
    this.onClick = (event) => {
      const closeButton = event.target.closest("button[data-tools-close]");
      if (closeButton && this.el.contains(closeButton)) {
        this.close(true);
      }
    };
  }

  setTriggerState(open) {
    this.trigger?.setAttribute("aria-expanded", String(open));
    if (this.trigger) this.trigger.dataset.toolsOpen = String(open);
    this.trigger?.querySelector("[data-tools-open]")?.classList.toggle("hidden", !open);
    this.trigger?.querySelector("[data-tools-closed]")?.classList.toggle("hidden", open);
  }

  open() {
    if (this.opened) return;
    this.opened = true;
    this.el.hidden = false;
    this.setTriggerState(true);
    this.el.addEventListener("keydown", this.onKeydown);
    this.trigger?.addEventListener("keydown", this.onKeydown);
    this.el.addEventListener("click", this.onClick);
  }

  close(restoreFocus = false) {
    if (!this.opened) return;
    const focusInside = this.el.contains(document.activeElement);
    this.destroy();
    this.onClose();
    if (restoreFocus || focusInside) this.trigger?.focus({ preventScroll: true });
    if (restoreFocus) this.trigger?.scrollIntoView({ block: "nearest", behavior: "instant" });
  }

  destroy() {
    this.el.hidden = true;
    this.opened = false;
    this.setTriggerState(false);
    this.el.removeEventListener("keydown", this.onKeydown);
    this.trigger?.removeEventListener("keydown", this.onKeydown);
    this.el.removeEventListener("click", this.onClick);
  }
}

export default {
  mounted() {
    const target = Number(this.el.getAttribute("phx-target"));
    this.menu = new ToolsMenuController(
      this.el,
      document.getElementById(this.el.dataset.triggerId),
      () => this.pushEventTo(target, "close_advanced_tools", {}),
    );
    this.syncOpenState();
  },
  syncOpenState() {
    if (this.el.dataset.open === "true") this.menu.open();
    else this.menu.destroy();
  },
  updated() { this.syncOpenState(); },
  destroyed() { this.menu.destroy(); },
};

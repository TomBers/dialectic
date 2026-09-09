export class ToolsMenuController {
  constructor(el, trigger, onClose = () => {}) {
    this.el = el;
    this.trigger = trigger;
    this.onClose = onClose;
    this.opened = false;
    this.onKeydown = (event) => {
      if (event.key !== "Escape") return;
      event.preventDefault();
      event.stopPropagation();
      this.close(true);
    };
    this.onClick = (event) => {
      const button = event.target.closest("button[phx-click], button[data-selection-action]");
      if (button && this.el.contains(button) && !button.disabled) this.close(false);
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
    window.addEventListener("keydown", this.onKeydown, true);
    window.addEventListener("click", this.onClick);
  }

  close(restoreFocus = false) {
    if (!this.opened) return;
    this.destroy();
    this.onClose();
    if (restoreFocus) this.trigger?.focus({ preventScroll: true });
  }

  destroy() {
    this.el.hidden = true;
    this.opened = false;
    this.setTriggerState(false);
    window.removeEventListener("keydown", this.onKeydown, true);
    window.removeEventListener("click", this.onClick);
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

export function toolsMenuPlacement(anchor, viewport, layoutHeight) {
  const gap = 8;
  const width = Math.min(420, viewport.width - gap * 2);
  const above = Math.max(0, anchor.top - viewport.top - gap);
  const below = Math.max(0, viewport.top + viewport.height - anchor.bottom - gap);
  const openAbove = above >= Math.min(240, below);
  const room = openAbove ? above : below;
  const cramped = room < 180;

  return {
    width: `${width}px`,
    left: `${Math.max(viewport.left + gap, Math.min(anchor.left, viewport.left + viewport.width - width - gap))}px`,
    maxHeight: `${Math.min(480, cramped ? viewport.height - gap * 2 : room)}px`,
    top: cramped ? `${viewport.top + gap}px` : openAbove ? "auto" : `${anchor.bottom + gap}px`,
    bottom: cramped || !openAbove ? "auto" : `${layoutHeight - anchor.top + gap}px`,
  };
}

export class ToolsMenuController {
  constructor(el, trigger, onClose = () => {}) {
    this.el = el;
    this.trigger = trigger;
    this.onClose = onClose;
    this.opened = false;
    this.scroller = el.querySelector("[data-tools-scroll]");
    this.scrollHint = el.querySelector("[data-tools-scroll-hint]");
    this.positionMenu = () => {
      if (!this.opened || !this.trigger?.isConnected) return;
      const viewport = window.visualViewport;
      Object.assign(this.el.style, toolsMenuPlacement(
        this.trigger.getBoundingClientRect(),
        {
          top: viewport?.offsetTop || 0,
          left: viewport?.offsetLeft || 0,
          width: viewport?.width || window.innerWidth,
          height: viewport?.height || window.innerHeight,
        },
        window.innerHeight,
      ));
      this.updateScrollHint();
    };
    this.onOutsidePointer = (event) => {
      if (!this.el.contains(event.target) && !this.trigger?.contains(event.target)) this.close();
    };
    this.onPageScroll = (event) => {
      if (this.el.contains(event.target)) return;
      const anchor = this.trigger?.getBoundingClientRect();
      const viewport = window.visualViewport;
      const top = viewport?.offsetTop || 0;
      const bottom = top + (viewport?.height || window.innerHeight);
      if (anchor && (anchor.bottom <= top || anchor.top >= bottom)) this.close();
      else this.positionMenu();
    };
    this.updateScrollHint = () => {
      if (!this.scroller || !this.scrollHint) return;
      this.scrollHint.hidden = !this.opened ||
        this.scroller.scrollHeight - this.scroller.clientHeight - this.scroller.scrollTop <= 2;
    };
    this.onKeydown = (event) => {
      if (event.key !== "Escape") return;
      event.preventDefault();
      event.stopPropagation();
      this.close(true);
    };
    this.onClick = (event) => {
      const closeButton = event.target.closest("button[data-tools-close]");
      if (closeButton && this.el.contains(closeButton)) {
        this.close(true);
        return;
      }
      const button = event.target.closest("button[phx-click], button[data-selection-action]");
      if (button && this.el.contains(button) && !button.disabled) this.close(true);
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
    if (this.el.showPopover) this.el.showPopover();
    else this.el.dataset.toolsFloatingOpen = "true";
    this.setTriggerState(true);
    if (this.scroller) this.scroller.scrollTop = 0;
    this.positionMenu();
    this.el.querySelector("button[phx-click]:not(:disabled), button[data-selection-action]:not(:disabled)")?.focus({ preventScroll: true });
    this.scroller?.addEventListener("scroll", this.updateScrollHint, { passive: true });
    window.addEventListener("resize", this.positionMenu);
    window.addEventListener("scroll", this.onPageScroll, true);
    window.addEventListener("pointerdown", this.onOutsidePointer);
    window.visualViewport?.addEventListener("resize", this.positionMenu);
    window.visualViewport?.addEventListener("scroll", this.positionMenu);
    if (this.scroller && typeof ResizeObserver !== "undefined") {
      this.resizeObserver = new ResizeObserver(this.updateScrollHint);
      this.resizeObserver.observe(this.scroller);
      Array.from(this.scroller.children).forEach((child) => this.resizeObserver.observe(child));
    }
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
    if (this.opened) this.el.hidePopover?.();
    delete this.el.dataset.toolsFloatingOpen;
    this.el.hidden = true;
    this.opened = false;
    this.scroller?.removeEventListener("scroll", this.updateScrollHint);
    window.removeEventListener("resize", this.positionMenu);
    window.removeEventListener("scroll", this.onPageScroll, true);
    window.removeEventListener("pointerdown", this.onOutsidePointer);
    window.visualViewport?.removeEventListener("resize", this.positionMenu);
    window.visualViewport?.removeEventListener("scroll", this.positionMenu);
    this.resizeObserver?.disconnect();
    this.updateScrollHint();
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

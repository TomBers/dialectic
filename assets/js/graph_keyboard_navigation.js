const GraphKeyboardNavigation = {
  mounted() {
    this.updateShortcutLabels();
    this.grid = () => this.el.querySelector("#cy-inner");
    this.reader = () => this.el.querySelector("#side-drawer-scroll");
    this.focusRegion = (region) => {
      if (region && region.getClientRects().length) region.focus({ preventScroll: true });
    };
    this.toggle = () => {
      const inReader = this.reader()?.contains(document.activeElement);
      this.focusRegion(inReader ? this.grid() : this.reader());
    };
    this.onKeydown = (event) => {
      if (event.isComposing || event.repeat || event.altKey) return;
      const target = event.target;
      if (target.closest('[role="dialog"], [aria-modal="true"]')) return;
      if (!event.metaKey && !event.ctrlKey && (event.key === "F6" || (event.key === "Tab" && this.el.contains(target))) && this.reader() && this.grid()) {
        event.preventDefault();
        event.stopPropagation();
        this.toggle();
        return;
      }
      if (!this.el.contains(target)) return;
      const reader = this.reader();
      const inReader = reader?.contains(target);
      const editable = target.matches('input, textarea, select') || target.isContentEditable;
      if ((event.metaKey || event.ctrlKey) && inReader && !editable && !event.shiftKey && ["a", "c", "r"].includes(event.key.toLowerCase())) {
        const button = reader.querySelector(`[data-reader-shortcut="${event.key.toLowerCase()}"]`);
        if (button && !button.disabled) {
          event.preventDefault();
          event.stopPropagation();
          this.focusRegion(button);
          button.scrollIntoView({ block: "nearest" });
          button.click();
        }
        return;
      }
      if (event.metaKey || event.ctrlKey) return;
      if (target === reader && !event.shiftKey) {
        const scroller = reader.querySelector('[id^="tt-node-"]');
        const distance = scroller?.clientHeight * 0.9;
        const offsets = { ArrowDown: 48, ArrowUp: -48, PageDown: distance, PageUp: -distance, " ": distance };
        if (scroller && (event.key in offsets || event.key === "Home" || event.key === "End")) {
          event.preventDefault();
          event.stopPropagation();
          if (event.key === "Home" || event.key === "End") {
            scroller.scrollTo({ top: event.key === "Home" ? 0 : scroller.scrollHeight, behavior: "instant" });
          } else {
            scroller.scrollBy({ top: offsets[event.key], behavior: "instant" });
          }
          return;
        }
      }
      let destination;
      if (event.key === "Escape") {
        destination = inReader && target !== reader ? reader : this.grid();
      } else if (!editable && !event.shiftKey && event.key === "/" && inReader) {
        destination = reader.querySelector('form[phx-hook="AskFormShortcuts"] textarea:not(:disabled)');
      } else if (event.key === "Enter" && target === this.grid()) {
        destination = reader;
      }
      if (destination) {
        event.preventDefault();
        event.stopPropagation();
        this.focusRegion(destination);
        if (destination.tagName === "TEXTAREA") {
          const composer = destination.closest("[data-keyboard-composer]") || destination;
          composer.scrollIntoView({ block: "center", behavior: "instant" });
        }
      }
    };
    this.onPointerDown = (event) => {
      if (this.grid()?.contains(event.target)) this.focusRegion(this.grid());
    };
    this.onClick = (event) => {
      if (event.target.closest("[data-keyboard-toggle]")) this.toggle();
    };
    window.addEventListener("keydown", this.onKeydown, true);
    this.el.addEventListener("pointerdown", this.onPointerDown);
    this.el.addEventListener("click", this.onClick);
  },
  updated() {
    this.updateShortcutLabels();
  },
  updateShortcutLabels() {
    const mac = /Mac|iPhone|iPad|iPod/i.test(navigator.userAgentData?.platform || navigator.platform);
    this.el.dataset.shortcutPlatform = mac ? "mac" : "windows";
    this.el.querySelectorAll("[data-reader-shortcut]").forEach((button) => {
      const key = button.dataset.readerShortcut.toUpperCase();
      button.setAttribute("aria-keyshortcuts", `${mac ? "Meta" : "Control"}+${key}`);
      button.title = `${mac ? "⌘" : "Ctrl"}+${key} (when not typing)`;
    });
  },
  destroyed() {
    window.removeEventListener("keydown", this.onKeydown, true);
    this.el.removeEventListener("pointerdown", this.onPointerDown);
    this.el.removeEventListener("click", this.onClick);
  },
};
export default GraphKeyboardNavigation;

const AskFormShortcuts = {
  mounted() {
    this.updateShortcutLabels();
    this.onSubmit = (event) => {
      const input = this.el.querySelector("textarea");
      if (input && !input.value.trim()) {
        event.preventDefault();
        event.stopImmediatePropagation();
        input.setCustomValidity("Write a comment or question first.");
        input.reportValidity();
      }
    };
    this.onInput = (event) => event.target.setCustomValidity?.("");
    this.el.addEventListener("submit", this.onSubmit);
    this.el.addEventListener("input", this.onInput);
    this.onKeydown = (event) => {
      if (event.target.tagName === "TEXTAREA" && event.key === "Enter") {
        event.stopPropagation();
      }
      if (
        event.target.tagName !== "TEXTAREA" ||
        event.key !== "Enter" ||
        !(event.metaKey || event.ctrlKey) ||
        event.altKey ||
        event.isComposing ||
        event.repeat ||
        event.defaultPrevented
      ) return;

      const action = event.shiftKey ? "comment" : "ask";
      const button = this.el.querySelector(`[data-shortcut-action="${action}"]`);
      if (
        event.target.disabled ||
        !event.target.value.trim() ||
        !button ||
        button.disabled ||
        this.el.getAttribute("aria-disabled") === "true"
      ) return;

      event.preventDefault();
      this.el.requestSubmit(button);
    };
    this.el.addEventListener("keydown", this.onKeydown);
  },

  updated() {
    this.updateShortcutLabels();
  },

  updateShortcutLabels() {
    const platform = navigator.userAgentData?.platform || navigator.platform;
    const mac = /Mac|iPhone|iPad|iPod/i.test(platform);
    this.el.dataset.shortcutPlatform = mac ? "mac" : "windows";
    const modifier = mac ? "Meta" : "Control";
    const label = mac ? "⌘" : "Ctrl";
    this.el.querySelectorAll("[data-shortcut-action]").forEach((button) => {
      const comment = button.dataset.shortcutAction === "comment";
      button.setAttribute("aria-keyshortcuts", `${modifier}+${comment ? "Shift+" : ""}Enter`);
      if (!button.disabled) {
        button.title = `${comment ? "Post thought" : "Ask AI"} (${label}+${comment ? "Shift+" : ""}Enter)`;
      }
    });
  },

  destroyed() {
    this.el.removeEventListener("keydown", this.onKeydown);
    this.el.removeEventListener("submit", this.onSubmit);
    this.el.removeEventListener("input", this.onInput);
  },
};

export default AskFormShortcuts;

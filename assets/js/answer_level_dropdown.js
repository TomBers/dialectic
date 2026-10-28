const labels = { high_school: "Simple", university: "Expanded", expert: "In-depth" };

export default {
  mounted() {
    this.trigger = this.el.querySelector("[data-answer-level-toggle]");
    this.panel = this.el.querySelector("[data-answer-level-options]");
    this.input = this.el.querySelector("[data-answer-level-input]");
    this.options = Array.from(this.el.querySelectorAll("[data-answer-level-choice]"));
    this.setOpen = (open, restoreFocus = false) => {
      this.panel.hidden = !open;
      this.trigger.setAttribute("aria-expanded", String(open));
      if (open) {
        const selected = this.options.find(option => option.getAttribute("aria-selected") === "true");
        (selected || this.options[0])?.focus({ preventScroll: true });
        this.panel.scrollIntoView({ block: "nearest" });
      } else if (restoreFocus) this.trigger.focus({ preventScroll: true });
    };
    this.onClick = (event) => {
      if (this.trigger.contains(event.target)) this.setOpen(this.panel.hidden);
      else {
        const choice = event.target.closest("[data-answer-level-choice]");
        if (!choice) return;
        if (this.input) {
          this.syncLevel(choice.dataset.answerLevelChoice);
          this.input.dispatchEvent(new Event("change", { bubbles: true }));
        }
        this.setOpen(false, true);
      }
    };
    this.onKeydown = (event) => {
      if (event.isComposing || event.altKey || event.metaKey || event.ctrlKey) return;
      if (event.key === "Escape" && !this.panel.hidden) {
        event.preventDefault();
        event.stopPropagation();
        this.setOpen(false, true);
        return;
      }
      if (!["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)) return;
      event.preventDefault();
      event.stopPropagation();
      if (this.panel.hidden) {
        this.setOpen(true);
        return;
      }
      const index = this.options.indexOf(document.activeElement);
      const next = event.key === "Home" ? 0 : event.key === "End" ? this.options.length - 1 :
        (index + (event.key === "ArrowDown" ? 1 : -1) + this.options.length) % this.options.length;
      this.options[next]?.focus({ preventScroll: true });
    };
    this.el.addEventListener("click", this.onClick);
    this.el.addEventListener("keydown", this.onKeydown);
    this.handleEvent("answer_level_changed", ({ mode }) => this.syncLevel(mode));
    this.syncLevel(this.el.dataset.promptMode);
  },
  syncLevel(mode) {
    mode = mode === "simple" ? "high_school" : mode;
    if (!labels[mode]) return;
    this.el.dataset.promptMode = mode;
    if (this.input) this.input.value = mode;
    this.el.querySelector("[data-answer-level-label]").textContent = labels[mode];
    this.trigger.setAttribute("aria-label", `Change AI answer level. Current level: ${labels[mode]}`);
    this.el.querySelectorAll("[data-answer-level-icon]").forEach(icon => {
      icon.hidden = icon.dataset.answerLevelIcon !== mode;
    });
    this.options.forEach(option => {
      const selected = option.dataset.answerLevelChoice === mode;
      option.setAttribute("aria-selected", String(selected));
      option.tabIndex = selected ? 0 : -1;
      option.querySelector("[data-answer-level-check]").hidden = !selected;
    });
  },
  updated() { this.syncLevel(this.el.dataset.promptMode); },
  destroyed() {
    this.el.removeEventListener("click", this.onClick);
    this.el.removeEventListener("keydown", this.onKeydown);
  },
};

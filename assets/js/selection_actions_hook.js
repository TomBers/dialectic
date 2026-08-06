const ASK_MODE = "ask_question";
const COMMENT_MODE = "comment";

const SelectionActionsHook = {
  mounted() {
    this.handleSelectionShow = this.handleSelectionShow.bind(this);
    this.handleKeydown = this.handleKeydown.bind(this);
    this.handleClick = this.handleClick.bind(this);
    this.handleSubmit = this.handleSubmit.bind(this);

    this.refreshElements();
    this.selectionData = null;
    this.inputMode = ASK_MODE;

    window.addEventListener("selection:show", this.handleSelectionShow);
    window.addEventListener("keydown", this.handleKeydown);
    this.el.addEventListener("click", this.handleClick);
    this.el.addEventListener("submit", this.handleSubmit);
  },

  destroyed() {
    window.removeEventListener("selection:show", this.handleSelectionShow);
    window.removeEventListener("keydown", this.handleKeydown);
    this.el.removeEventListener("click", this.handleClick);
    this.el.removeEventListener("submit", this.handleSubmit);
  },

  handleSelectionShow(event) {
    const { selectedText, nodeId, offsets } = event.detail || {};

    if (
      !selectedText ||
      !nodeId ||
      !offsets ||
      !Number.isInteger(offsets.start) ||
      !Number.isInteger(offsets.end) ||
      offsets.start >= offsets.end
    ) {
      return;
    }

    this.refreshElements();
    this.selectionData = { selectedText, nodeId, offsets };
    this.populateSelectedText(selectedText);
    this.resetClientControls();
    this.syncCanEditState();
    this.syncExistingHighlightState();
    this.showModal();
  },

  refreshElements() {
    this.componentEl = this.el.firstElementChild;
    this.modalEl = this.componentEl?.querySelector(
      '[id^="selection-actions-modal-"]',
    );
  },

  canEdit() {
    return this.componentEl?.dataset.canEdit === "true";
  },

  syncCanEditState() {
    const disabled = !this.canEdit();

    this.modalEl
      ?.querySelectorAll(
        "[data-selection-input], [data-selection-input-submit], [data-selection-mode]",
      )
      .forEach((control) => {
        control.disabled = disabled;
      });
  },

  populateSelectedText(selectedText) {
    const selectedTextEl = this.modalEl?.querySelector("[data-selection-text]");
    if (selectedTextEl) selectedTextEl.textContent = `“${selectedText}”`;
  },

  exactHighlightForSelection() {
    if (!this.selectionData) return null;

    const { nodeId, offsets } = this.selectionData;

    return (window.__highlightsCache || []).find(
      (highlight) =>
        highlight.node_id?.toString() === nodeId.toString() &&
        highlight.selection_start === offsets.start &&
        highlight.selection_end === offsets.end,
    );
  },

  syncExistingHighlightState() {
    const highlight = this.exactHighlightForSelection();
    const links = highlight?.links || [];
    const linkTypes = new Set(links.map((link) => link.link_type));

    this.modalEl
      ?.querySelectorAll("[data-selection-action]")
      .forEach((button) => {
        const blockedLinks = (button.dataset.disableIfLinks || "")
          .split(",")
          .filter(Boolean);
        const blockedByHighlight =
          button.dataset.disableIfHighlight === "true" && !!highlight;
        const blockedByLink = blockedLinks.some((type) => linkTypes.has(type));

        button.disabled = !this.canEdit() || blockedByHighlight || blockedByLink;
      });

    this.syncLinkCount("question", links);
    this.syncLinkCount("comment", links);
  },

  syncLinkCount(type, links) {
    const count = links.filter((link) => link.link_type === type).length;
    const countEl = this.modalEl?.querySelector(
      `[data-selection-${type}-count]`,
    );

    if (!countEl) return;

    countEl.classList.toggle("hidden", count === 0);
    countEl.textContent =
      count === 0 ? "" : `${count} ${type}${count === 1 ? "" : "s"}`;
  },

  resetClientControls() {
    const advancedTools = this.modalEl?.querySelector(
      "[data-selection-advanced-tools]",
    );
    const advancedToggle = this.modalEl?.querySelector(
      "[data-selection-advanced-toggle]",
    );
    const input = this.modalEl?.querySelector("[data-selection-input]");

    advancedTools?.classList.add("hidden");
    advancedToggle?.setAttribute("aria-expanded", "false");
    advancedToggle?.querySelector("[class*='hero-chevron-down']")?.classList.remove(
      "rotate-180",
    );
    if (input) input.value = "";
    this.setInputMode(ASK_MODE);
  },

  showModal() {
    if (!this.modalEl) return;

    this.modalEl.classList.remove("hidden");
    this.modalEl.setAttribute("aria-hidden", "false");
  },

  closeModal() {
    if (!this.modalEl) return;

    this.modalEl.classList.add("hidden");
    this.modalEl.setAttribute("aria-hidden", "true");
    this.selectionData = null;
    this.clearBrowserSelection();
  },

  clearBrowserSelection() {
    const selection = window.getSelection();
    if (selection && selection.rangeCount > 0) selection.removeAllRanges();
  },

  handleClick(event) {
    const closeEl = event.target.closest("[data-selection-close]");
    if (closeEl && this.el.contains(closeEl)) {
      this.closeModal();
      return;
    }

    const advancedToggle = event.target.closest(
      "[data-selection-advanced-toggle]",
    );
    if (advancedToggle && this.el.contains(advancedToggle)) {
      this.toggleAdvancedTools(advancedToggle);
      return;
    }

    const modeEl = event.target.closest("[data-selection-mode]");
    if (modeEl && this.el.contains(modeEl)) {
      this.setInputMode(modeEl.dataset.selectionMode);
      return;
    }

    const actionEl = event.target.closest("[data-selection-action]");
    if (
      !actionEl ||
      !this.el.contains(actionEl) ||
      actionEl.disabled ||
      !this.selectionData
    ) {
      return;
    }

    this.submitAction(actionEl.dataset.selectionAction);
  },

  toggleAdvancedTools(toggle) {
    const tools = this.modalEl?.querySelector("[data-selection-advanced-tools]");
    if (!tools) return;

    const expanded = tools.classList.contains("hidden");
    tools.classList.toggle("hidden", !expanded);
    toggle.setAttribute("aria-expanded", expanded.toString());
    toggle
      .querySelector("[class*='hero-chevron-down']")
      ?.classList.toggle("rotate-180", expanded);
  },

  setInputMode(mode) {
    if (![ASK_MODE, COMMENT_MODE].includes(mode)) return;

    this.inputMode = mode;
    const askButton = this.modalEl?.querySelector(
      `[data-selection-mode="${ASK_MODE}"]`,
    );
    const commentButton = this.modalEl?.querySelector(
      `[data-selection-mode="${COMMENT_MODE}"]`,
    );
    const input = this.modalEl?.querySelector("[data-selection-input]");
    const label = this.modalEl?.querySelector("[data-selection-input-label]");
    const description = this.modalEl?.querySelector(
      "[data-selection-input-description]",
    );
    const submit = this.modalEl?.querySelector("[data-selection-input-submit]");

    this.syncModeButton(askButton, mode === ASK_MODE, "indigo");
    this.syncModeButton(commentButton, mode === COMMENT_MODE, "emerald");

    if (label) {
      label.textContent =
        mode === ASK_MODE ? "Ask a custom question" : "Add a comment";
    }
    if (description) {
      description.textContent =
        mode === ASK_MODE
          ? "Use the selected text as the context for a more specific answer."
          : "Save your own interpretation directly against this excerpt.";
    }
    if (input) {
      input.placeholder =
        mode === ASK_MODE
          ? "What do you want to know about this exact wording?"
          : "Add your thought about this selection...";
    }
    if (submit) {
      submit.textContent = mode === ASK_MODE ? "Ask" : "Post";
      submit.classList.toggle("from-indigo-500", mode === ASK_MODE);
      submit.classList.toggle("to-sky-500", mode === ASK_MODE);
      submit.classList.toggle("from-emerald-500", mode === COMMENT_MODE);
      submit.classList.toggle("to-teal-500", mode === COMMENT_MODE);
    }
  },

  syncModeButton(button, active, color) {
    if (!button) return;

    button.classList.toggle(`bg-${color}-500`, active);
    button.classList.toggle("text-white", active);
    button.classList.toggle("shadow-sm", active);
    button.classList.toggle("text-slate-600", !active);
    button.classList.toggle("hover:text-slate-900", !active);
  },

  handleSubmit(event) {
    const form = event.target.closest("[data-selection-input-form]");
    if (!form || !this.el.contains(form) || !this.selectionData) return;

    event.preventDefault();
    const input = form.querySelector('[name="question"]');
    this.submitAction(this.inputMode, { input: input?.value || "" });
  },

  submitAction(action, extra = {}) {
    if (!this.selectionData || !this.componentEl) return;

    this.pushEventTo(this.componentEl, "action", {
      ...this.selectionData,
      action,
      ...extra,
    });
    this.closeModal();
  },

  handleKeydown(event) {
    if (event.key !== "Escape" || this.modalEl?.classList.contains("hidden")) {
      return;
    }

    event.preventDefault();
    this.closeModal();
  },
};

export default SelectionActionsHook;

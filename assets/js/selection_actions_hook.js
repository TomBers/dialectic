import { copyToClipboard, showToast } from "./toast.js";

const ASK_MODE = "ask_question";

const SelectionActionsHook = {
  mounted() {
    this.handleSelectionShow = this.handleSelectionShow.bind(this);
    this.handleKeydown = this.handleKeydown.bind(this);
    this.handleClick = this.handleClick.bind(this);
    this.handleSubmit = this.handleSubmit.bind(this);

    this.refreshElements();
    this.selectionData = null;

    window.addEventListener("selection:show", this.handleSelectionShow);
    window.addEventListener("keydown", this.handleKeydown);
    this.el.addEventListener("click", this.handleClick);
    this.el.addEventListener("submit", this.handleSubmit);
  },

  destroyed() {
    window.clearTimeout(this.copyFeedbackTimer);
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
        "[data-selection-input], [data-selection-input-submit]",
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
    const dialog = this.modalEl?.querySelector("[data-selection-dialog]");
    const input = this.modalEl?.querySelector("[data-selection-input]");

    advancedTools?.classList.add("hidden");
    advancedToggle?.setAttribute("aria-expanded", "false");
    dialog?.classList.remove("max-w-[760px]");
    dialog?.classList.add("max-w-[620px]");
    advancedToggle?.querySelector("[class*='hero-chevron-down']")?.classList.remove(
      "rotate-180",
    );
    if (input) input.value = "";
    this.resetCopyFeedback();
  },

  resetCopyFeedback() {
    window.clearTimeout(this.copyFeedbackTimer);
    this.copyFeedbackTimer = null;

    const label = this.modalEl?.querySelector("[data-selection-copy-label]");
    const icon = this.modalEl?.querySelector("[data-selection-copy-icon]");
    const check = this.modalEl?.querySelector("[data-selection-copy-check]");

    if (label) label.textContent = "Copy text";
    icon?.classList.remove("hidden");
    check?.classList.add("hidden");
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
    const copyEl = event.target.closest("[data-selection-copy]");
    if (copyEl && this.el.contains(copyEl)) {
      event.preventDefault();
      this.copySelectedText(copyEl);
      return;
    }

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

  copySelectedText(copyEl) {
    const copiedSelection = this.selectionData;
    if (!copiedSelection?.selectedText) return;

    copyToClipboard(copiedSelection.selectedText).then(() => {
      showToast("Selected text copied.", { id: "selection-copy-toast" });

      if (this.selectionData !== copiedSelection) return;

      const label = copyEl.querySelector("[data-selection-copy-label]");
      const icon = copyEl.querySelector("[data-selection-copy-icon]");
      const check = copyEl.querySelector("[data-selection-copy-check]");

      if (label) label.textContent = "Copied";
      icon?.classList.add("hidden");
      check?.classList.remove("hidden");

      window.clearTimeout(this.copyFeedbackTimer);
      this.copyFeedbackTimer = window.setTimeout(
        () => this.resetCopyFeedback(),
        2000,
      );
    });
  },

  toggleAdvancedTools(toggle) {
    const tools = this.modalEl?.querySelector("[data-selection-advanced-tools]");
    const dialog = this.modalEl?.querySelector("[data-selection-dialog]");
    if (!tools) return;

    const expanded = tools.classList.contains("hidden");
    tools.classList.toggle("hidden", !expanded);
    toggle.setAttribute("aria-expanded", expanded.toString());
    dialog?.classList.toggle("max-w-[760px]", expanded);
    dialog?.classList.toggle("max-w-[620px]", !expanded);
    toggle
      .querySelector("[class*='hero-chevron-down']")
      ?.classList.toggle("rotate-180", expanded);
  },

  handleSubmit(event) {
    const form = event.target.closest("[data-selection-input-form]");
    if (!form || !this.el.contains(form) || !this.selectionData) return;

    event.preventDefault();
    const input = form.querySelector('[name="question"]');
    const action = event.submitter?.dataset.selectionSubmitAction || ASK_MODE;
    this.submitAction(action, { input: input?.value || "" });
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

import { ToolsMenuController } from "./tools_menu_hook.js";
import { handleInquiryShortcut, syncInquiryShortcutLabels } from "./inquiry_shortcuts.js";

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
    this.pendingRequest = null;
    this.drafts = this.readDrafts();
    this.onDraftInput = () => this.saveDraft();
    this.el.addEventListener("input", this.onDraftInput);
    this.handleEvent("selection:result", (result) => this.handleResult(result));
    syncInquiryShortcutLabels(this.el);

    this.showEventName = this.answerContext() ? "answer:show" : "selection:show";
    window.addEventListener(this.showEventName, this.handleSelectionShow);
    window.addEventListener("keydown", this.handleKeydown);
    this.el.addEventListener("click", this.handleClick);
    this.el.addEventListener("submit", this.handleSubmit);
  },

  destroyed() {
    this.saveDraft();
    this.toolsMenu?.destroy();
    this.el.removeEventListener("input", this.onDraftInput);
    window.clearTimeout(this.copyFeedbackTimer);
    window.removeEventListener(this.showEventName, this.handleSelectionShow);
    window.removeEventListener("keydown", this.handleKeydown);
    this.el.removeEventListener("click", this.handleClick);
    this.el.removeEventListener("submit", this.handleSubmit);
  },

  answerContext() {
    return this.componentEl?.dataset.actionContext === "answer";
  },

  handleSelectionShow(event) {
    if (this.answerContext()) {
      const { nodeId, title, bookmarked } = event.detail || {};
      if (!nodeId || !title || this.pendingRequest) return;
      this.saveDraft();
      this.refreshElements();
      this.selectionData = { nodeId };
      const heading = this.modalEl?.querySelector("[data-selection-text]");
      if (heading) heading.textContent = title;
      this.resetClientControls();
      this.syncCanEditState();
      this.syncExistingHighlightState();
      this.syncBookmarkState(bookmarked === true);
      this.showModal();
      return;
    }
    const { selectedText, nodeId, offsets } = event.detail || {};

    if (
      !selectedText ||
      !nodeId ||
      !offsets ||
      !Number.isInteger(offsets.start) ||
      offsets.start < 0 ||
      !Number.isInteger(offsets.end) ||
      offsets.start >= offsets.end
    ) {
      return;
    }

    if (this.pendingRequest) return;
    this.saveDraft();
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
    if (!this.selectionData || this.answerContext()) return null;

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

        button.disabled = button.dataset.selectionAction === "bookmark" ? false : !this.canEdit() || blockedByHighlight || blockedByLink;
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
    const advancedTools = this.modalEl?.querySelector("[data-selection-advanced-tools]");
    const advancedToggle = this.modalEl?.querySelector("[data-selection-advanced-toggle]");
    const input = this.modalEl?.querySelector("[data-selection-input]");
    this.toolsMenu?.destroy();
    this.toolsMenu = advancedTools && advancedToggle
      ? new ToolsMenuController(advancedTools, advancedToggle)
      : null;
    const draft = this.drafts[this.draftKey()];
    if (input) input.value = typeof draft === "string" ? draft : draft?.input || "";
    const learning = this.modalEl?.querySelector('input[type="checkbox"][name="guided_learning"]');
    if (learning) learning.checked = draft?.guidedLearning === true;
    input?.dispatchEvent(new Event("input", { bubbles: true }));
    this.setStatus("");
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

    this.previousFocus = document.activeElement;
    syncInquiryShortcutLabels(this.el);
    this.modalEl.classList.remove("hidden");
    this.modalEl.setAttribute("aria-hidden", "false");
    this.modalEl.querySelector("[data-selection-dialog]")?.focus({ preventScroll: true });
  },

  closeModal() {
    if (!this.modalEl) return;

    this.modalEl.classList.add("hidden");
    this.modalEl.setAttribute("aria-hidden", "true");
    this.saveDraft();
    this.toolsMenu?.close();
    this.clearBrowserSelection();
    if (this.previousFocus?.isConnected) this.previousFocus.focus({ preventScroll: true });
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

  toggleAdvancedTools() {
    if (this.toolsMenu?.opened) this.toolsMenu.close();
    else this.toolsMenu?.open();
  },

  handleSubmit(event) {
    const form = event.target.closest("[data-selection-input-form]");
    if (!form || !this.el.contains(form) || !this.selectionData) return;

    event.preventDefault();
    const input = form.querySelector("[data-selection-input]");
    const action = event.submitter?.dataset.selectionSubmitAction || ASK_MODE;
    const extra = { input: input?.value || "" };
    if (this.answerContext()) extra.guided_learning = form.querySelector('input[type="checkbox"][name="guided_learning"]')?.checked || false;
    this.submitAction(action, extra);
  },

  submitAction(action, extra = {}) {
    if (!this.selectionData || !this.componentEl) return;

    if (this.pendingRequest) return;
    if (["comment", ASK_MODE].includes(action) && !extra.input?.trim()) {
      this.setStatus("Write a comment or question first.");
      this.modalEl.querySelector("[data-selection-input]")?.focus();
      return;
    }
    this.toolsMenu?.close();
    this.saveDraft();
    const requestId = crypto.randomUUID();
    this.pendingRequest = { id: requestId, action, draftKey: this.draftKey() };
    this.setPending(true);
    this.setStatus(action === "comment" ? "Posting…" : ["highlight_only", "bookmark"].includes(action) ? "Saving…" : "Starting AI response…");
    this.pushEventTo(this.componentEl, "action", {
      ...this.selectionData,
      action,
      ...extra,
      request_id: requestId,
    });
  },

  handleResult(result) {
    const request = this.pendingRequest;
    if (!request || result.request_id !== request.id) return;
    this.pendingRequest = null;
    this.setPending(false);
    if (result.status === "ok") {
      if (request.action === "bookmark") {
        this.syncBookmarkState(result.bookmarked);
        this.setStatus(result.bookmarked ? "Answer bookmarked." : "Bookmark removed.");
        return;
      }
      if (["comment", ASK_MODE].includes(request.action)) {
        const input = this.modalEl?.querySelector("[data-selection-input]");
        if (input) input.value = "";
        const learning = this.modalEl?.querySelector('input[type="checkbox"][name="guided_learning"]');
        if (learning) learning.checked = false;
        delete this.drafts[request.draftKey];
        this.persistDrafts();
      }
      this.closeModal();
    } else {
      this.setStatus(result.message || "Could not save. Your draft is still here.");
    }
  },

  syncBookmarkState(bookmarked) {
    const button = this.modalEl?.querySelector("[data-answer-bookmark]");
    if (!button) return;
    button.setAttribute("aria-pressed", String(bookmarked));
    button.setAttribute("aria-label", bookmarked ? "Remove bookmark" : "Bookmark this answer");
    const label = button.querySelector("[data-tool-label]");
    if (label) label.textContent = bookmarked ? "Bookmarked" : "Bookmark";
    const icon = button.querySelector(".hero-bookmark, .hero-bookmark-solid");
    icon?.classList.toggle("hero-bookmark", !bookmarked);
    icon?.classList.toggle("hero-bookmark-solid", bookmarked);
  },

  setStatus(message) {
    const status = this.modalEl?.querySelector("[data-selection-status]");
    if (status) status.textContent = message;
  },

  setPending(pending) {
    const form = this.modalEl?.querySelector("[data-selection-input-form]");
    form?.setAttribute("aria-busy", String(pending));
    const input = form?.querySelector("textarea");
    if (input) input.readOnly = pending;
    if (pending) {
      this.modalEl?.querySelectorAll("[data-selection-action], [data-selection-input-submit]")
        .forEach((button) => { button.disabled = true; });
    } else {
      this.syncCanEditState();
      this.syncExistingHighlightState();
    }
  },

  draftKey() {
    const selection = this.selectionData;
    if (selection && this.answerContext()) return JSON.stringify(["answer", selection.nodeId]);
    return selection && JSON.stringify([selection.nodeId, selection.offsets.start, selection.offsets.end, selection.selectedText]);
  },

  readDrafts() {
    try {
      const key = this.componentEl?.dataset.draftKey;
      const guestKey = this.componentEl?.dataset.guestDraftKey;
      const guest = guestKey ? JSON.parse(sessionStorage.getItem(guestKey) || "{}") : {};
      const saved = JSON.parse(sessionStorage.getItem(key) || "{}");
      const drafts = Object.fromEntries(Object.entries({...guest, ...saved}).filter(([, draft]) => typeof draft === "string" || (draft && typeof draft.input === "string" && typeof draft.guidedLearning === "boolean")).slice(-20));
      if (guestKey && key) {
        sessionStorage.setItem(key, JSON.stringify(drafts));
        sessionStorage.removeItem(guestKey);
      }
      return drafts;
    } catch { return {}; }
  },

  saveDraft() {
    const key = this.draftKey();
    const input = this.modalEl?.querySelector("[data-selection-input]");
    if (!key || !input) return;
    delete this.drafts[key];
    const guidedLearning = this.modalEl?.querySelector('input[type="checkbox"][name="guided_learning"]')?.checked || false;
    if (input.value || guidedLearning) this.drafts[key] = this.answerContext() ? { input: input.value, guidedLearning } : input.value;
    this.persistDrafts();
  },

  persistDrafts() {
    this.drafts = Object.fromEntries(Object.entries(this.drafts).slice(-20));
    try {
      if (this.componentEl?.dataset.draftKey) {
        sessionStorage.setItem(this.componentEl.dataset.draftKey, JSON.stringify(this.drafts));
      }
    } catch { /* Keep the in-memory draft if browser storage is unavailable. */ }
  },

  handleKeydown(event) {
    if (!this.modalEl || this.modalEl.classList.contains("hidden") || event.isComposing || event.repeat) return;
    if (handleInquiryShortcut(event, this.modalEl)) return;
    if (event.altKey || event.metaKey || event.ctrlKey || event.shiftKey) return;

    const target = event.target;
    const editable = target.matches("input, textarea, select") || target.isContentEditable;
    if (event.key === "/" && !editable) {
      const input = this.modalEl.querySelector("[data-selection-input]:not(:disabled)");
      if (!input) return;
      event.preventDefault();
      input.focus({ preventScroll: true });
      (input.closest("[data-keyboard-composer]") || input.form).scrollIntoView({ block: "center", behavior: "instant" });
    } else if (event.key === "Escape") {
      event.preventDefault();
      if (editable && this.modalEl.contains(target)) {
        this.modalEl.querySelector("[data-selection-dialog]")?.focus({ preventScroll: true });
      } else {
        this.closeModal();
      }
    }
  },
};

export default SelectionActionsHook;

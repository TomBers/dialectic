const SelectionActionsHook = {
  // Delay to allow modal CSS transitions to complete before focusing input
  FOCUS_DELAY_MS: 100,

  mounted() {
    this.selectedText = "";
    this.nodeId = null;
    this.offsets = null;

    // Bind methods
    this.show = this.show.bind(this);
    this.hide = this.hide.bind(this);
    this.handleExplain = this.handleExplain.bind(this);
    this.handleHighlight = this.handleHighlight.bind(this);
    this.handleSubmitQuestion = this.handleSubmitQuestion.bind(this);
    this.handleKeydown = this.handleKeydown.bind(this);

    // Set up event listeners
    this.el
      .querySelector('[data-action="close"]')
      ?.addEventListener("click", this.hide);
    this.el
      .querySelector('[data-action="explain"]')
      ?.addEventListener("click", this.handleExplain);
    this.el
      .querySelector('[data-action="highlight"]')
      ?.addEventListener("click", this.handleHighlight);

    const form = this.el.querySelector("form");
    if (form) {
      form.addEventListener("submit", this.handleSubmitQuestion);
    }

    // Backdrop click to close
    this.el
      .querySelector("[data-backdrop]")
      ?.addEventListener("click", this.hide);

    // Window keydown for escape
    window.addEventListener("keydown", this.handleKeydown);

    // Listen for custom event to show modal
    window.addEventListener("selection:show", this.show);
  },

  destroyed() {
    this.el
      .querySelector('[data-action="close"]')
      ?.removeEventListener("click", this.hide);
    this.el
      .querySelector('[data-action="explain"]')
      ?.removeEventListener("click", this.handleExplain);
    this.el
      .querySelector('[data-action="highlight"]')
      ?.removeEventListener("click", this.handleHighlight);

    const form = this.el.querySelector("form");
    if (form) {
      form.removeEventListener("submit", this.handleSubmitQuestion);
    }

    this.el
      .querySelector("[data-backdrop]")
      ?.removeEventListener("click", this.hide);
    window.removeEventListener("keydown", this.handleKeydown);
    window.removeEventListener("selection:show", this.show);
  },

  show(event) {
    const { selectedText, nodeId, offsets } = event.detail;

    this.selectedText = selectedText;
    this.nodeId = nodeId;
    this.offsets = offsets;

    // Update the displayed text
    const textDisplay = this.el.querySelector("[data-selected-text]");
    if (textDisplay) {
      textDisplay.textContent = selectedText;
    }

    // Clear any previous question textarea
    const textarea = this.el.querySelector('textarea[name="question"]');
    if (textarea) {
      textarea.value = "";
      // Reset height for auto-expand textarea
      textarea.style.height = "";
    }

    // Show the modal
    this.el.classList.remove("hidden");

    // Focus the textarea after CSS transitions complete to prevent visual jumps
    setTimeout(() => {
      if (textarea) {
        textarea.focus();
      }
    }, this.FOCUS_DELAY_MS);
  },

  hide() {
    this.el.classList.add("hidden");
    this.selectedText = "";
    this.nodeId = null;
    this.offsets = null;

    // Clear selection
    window.getSelection().removeAllRanges();
  },

  handleKeydown(e) {
    if (e.key === "Escape" && !this.el.classList.contains("hidden")) {
      e.preventDefault();
      this.hide();
    }
  },

  handleExplain(e) {
    e.preventDefault();
    e.stopPropagation();

    if (!this.selectedText) return;

    // Send event to server
    this.pushEvent("selection_explain", {
      selected_text: this.selectedText,
      node_id: this.nodeId,
      offsets: this.offsets,
    });

    this.hide();
  },

  handleHighlight(e) {
    e.preventDefault();
    e.stopPropagation();

    if (!this.selectedText || !this.offsets) return;

    // Send event to server
    this.pushEvent("selection_highlight", {
      selected_text: this.selectedText,
      node_id: this.nodeId,
      offsets: this.offsets,
    });

    this.hide();
  },

  handleSubmitQuestion(e) {
    e.preventDefault();
    e.stopPropagation();

    const formData = new FormData(e.target);
    const question = formData.get("question")?.trim();

    if (!question || !this.selectedText) return;

    // Send event to server
    this.pushEvent("selection_ask", {
      question: question,
      selected_text: this.selectedText,
      node_id: this.nodeId,
      offsets: this.offsets,
    });

    this.hide();
  },
};

export default SelectionActionsHook;

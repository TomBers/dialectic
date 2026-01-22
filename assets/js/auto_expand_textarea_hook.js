const AutoExpandTextareaHook = {
  mounted() {
    this.textarea = this.el;
    this.minHeight = 48; // Match the h-12 default height (3rem = 48px)
    this.maxHeight = 240; // ~6 lines of text maximum

    // Set initial styles
    this.textarea.style.resize = "none";
    this.textarea.style.overflow = "hidden";
    this.textarea.style.minHeight = `${this.minHeight}px`;

    // Bind the handler
    this.handleInput = this.handleInput.bind(this);

    // Add event listeners
    this.textarea.addEventListener("input", this.handleInput);

    // Initial adjustment in case there's pre-filled content
    this.adjustHeight();
  },

  destroyed() {
    this.textarea.removeEventListener("input", this.handleInput);
  },

  handleInput() {
    this.adjustHeight();
  },

  adjustHeight() {
    // Reset height to recalculate
    this.textarea.style.height = `${this.minHeight}px`;

    // Get the scroll height (actual content height)
    const scrollHeight = this.textarea.scrollHeight;

    // Set new height, clamped between min and max
    if (scrollHeight > this.minHeight) {
      const newHeight = Math.min(scrollHeight, this.maxHeight);
      this.textarea.style.height = `${newHeight}px`;

      // Enable scrolling only when max height is reached
      if (scrollHeight > this.maxHeight) {
        this.textarea.style.overflowY = "auto";
      } else {
        this.textarea.style.overflowY = "hidden";
      }
    } else {
      this.textarea.style.overflowY = "hidden";
    }
  },
};

export default AutoExpandTextareaHook;

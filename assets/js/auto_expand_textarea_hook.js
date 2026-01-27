const AutoExpandTextareaHook = {
  mounted() {
    this.textarea = this.el;
    const computedStyle = window.getComputedStyle(this.textarea);

    // Derive minHeight from CSS (min-height), fallback to 48px to match h-12 (3rem = 48px)
    const parsedMinHeight = parseFloat(computedStyle.minHeight);
    this.minHeight =
      Number.isFinite(parsedMinHeight) && parsedMinHeight > 0
        ? parsedMinHeight
        : 48;

    // Derive maxHeight from CSS custom property if available, otherwise fallback to ~6 lines (240px)
    const maxHeightVar = computedStyle.getPropertyValue(
      "--auto-expand-max-height",
    );
    const parsedMaxHeight = parseFloat(maxHeightVar);
    this.maxHeight =
      Number.isFinite(parsedMaxHeight) && parsedMaxHeight > 0
        ? parsedMaxHeight
        : 240; // ~6 lines of text maximum

    // Threshold above minHeight to trigger border radius change (prevents flickering on single-line expansion)
    // Can be customized via the --auto-expand-border-threshold CSS custom property.
    const borderThresholdVar = computedStyle.getPropertyValue(
      "--auto-expand-border-threshold",
    );
    const parsedBorderThreshold = parseFloat(borderThresholdVar);
    this.borderRadiusThreshold =
      Number.isFinite(parsedBorderThreshold) && parsedBorderThreshold >= 0
        ? parsedBorderThreshold
        : 10;

    // Store the initial border radius class (if using rounded-full)
    this.usesRoundedFull = this.textarea.classList.contains("rounded-full");

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

  updated() {
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

      // Adjust border radius for multi-line text
      if (
        this.usesRoundedFull &&
        newHeight > this.minHeight + this.borderRadiusThreshold
      ) {
        // Switch from rounded-full to rounded-3xl when expanding
        this.textarea.classList.remove("rounded-full");
        this.textarea.classList.add("rounded-3xl");
      }
    } else {
      this.textarea.style.overflowY = "hidden";

      // Restore rounded-full for single line
      if (this.usesRoundedFull) {
        this.textarea.classList.remove("rounded-3xl");
        this.textarea.classList.add("rounded-full");
      }
    }
  },
};

export default AutoExpandTextareaHook;

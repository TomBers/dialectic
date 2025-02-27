const toolTipHook = {
  mounted() {
    // Track when a positioning operation is in progress
    this.isPositioning = false;

    // Initially hide the tooltip
    this.el.style.opacity = "0";
    this.el.style.transition = "opacity 0.2s ease-out";

    // Setup debounce function
    this.debouncedHandlePositioning = this.debounce(() => {
      this.calculateAndApplyPosition();
    }, 100);

    // Add observer to detect when element becomes visible
    this.visibilityObserver = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (
          mutation.attributeName === "style" &&
          this.el.style.display === "block" &&
          this.el.style.opacity === "0"
        ) {
          console.log("Menu became visible, positioning it");
          this.debouncedHandlePositioning();
        }
      });
    });

    // Start observing style changes
    this.visibilityObserver.observe(this.el, { attributes: true });

    // Run initial positioning
    this.debouncedHandlePositioning();

    // Setup resize handler
    this.resizeListener = () => this.debouncedHandlePositioning();
    window.addEventListener("resize", this.resizeListener);

    // Add a guaranteed fallback for visibility
    this.visibilityFallback = setInterval(() => {
      if (this.el.style.display === "block" && this.el.style.opacity === "0") {
        console.log("Visibility fallback triggered");
        this.el.style.opacity = "1";
      }
    }, 1000);
  },

  calculateAndApplyPosition() {
    // If already positioning, don't start a new positioning operation
    if (this.isPositioning) {
      console.log("Already positioning, skipping");
      return;
    }

    // If element is not visible, don't try to position it
    if (this.el.style.display === "none") {
      console.log("Element not displayed, skipping positioning");
      return;
    }

    this.isPositioning = true;
    console.log("Starting positioning");

    try {
      // Get node position from data attribute
      const nodePosition = this.el.dataset.nodePosition
        ? JSON.parse(this.el.dataset.nodePosition)
        : null;

      if (!nodePosition) {
        console.log("No node position data, skipping positioning");
        return;
      }

      // Positioning logic...
      // [Your existing positioning code here]

      // Force the browser to process the layout before continuing
      this.el.getBoundingClientRect();

      // Make visible and mark positioning as complete
      this.el.style.opacity = "1";
      console.log("Positioning complete, menu visible");
    } catch (e) {
      console.error("Error during positioning:", e);
    } finally {
      // Always reset the positioning flag
      this.isPositioning = false;
    }
  },

  debounce(func, wait) {
    let timeout;
    return function () {
      const context = this;
      const args = arguments;
      clearTimeout(timeout);
      timeout = setTimeout(() => func.apply(context, args), wait);
    };
  },

  destroyed() {
    window.removeEventListener("resize", this.resizeListener);
    if (this.visibilityObserver) {
      this.visibilityObserver.disconnect();
    }
    clearInterval(this.visibilityFallback);
  },
};

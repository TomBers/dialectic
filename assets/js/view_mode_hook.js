// Client-side view mode toggle hook
// Handles switching between spaced and compact graph views without server round-trips

export const ViewModeHook = {
  mounted() {
    // Get initial view mode from localStorage or default to "spaced"
    const savedViewMode = localStorage.getItem("graph_view_mode") || "spaced";
    this.viewMode = savedViewMode;

    // Get initial graph direction from localStorage or default to "TB" (top-bottom)
    const savedDirection = localStorage.getItem("graph_direction") || "TB";
    this.graphDirection = savedDirection;

    this._bindEvents();
  },

  updated() {
    this._bindEvents();
  },

  destroyed() {
    if (this.toggleInput && this._onToggleChange) {
      this.toggleInput.removeEventListener("change", this._onToggleChange);
    }
    if (this.directionToggleInput && this._onDirectionToggleChange) {
      this.directionToggleInput.removeEventListener(
        "change",
        this._onDirectionToggleChange,
      );
    }
  },

  _bindEvents() {
    // Cleanup old listeners if they exist
    if (this.toggleInput && this._onToggleChange) {
      this.toggleInput.removeEventListener("change", this._onToggleChange);
    }
    if (this.directionToggleInput && this._onDirectionToggleChange) {
      this.directionToggleInput.removeEventListener(
        "change",
        this._onDirectionToggleChange,
      );
    }

    // Get view mode toggle elements
    this.toggleInput = this.el.querySelector(
      '[data-view-mode-toggle="toggle"]',
    );
    this.toggleBg =
      this.toggleInput?.parentElement.querySelector("div:first-of-type");
    this.toggleKnob =
      this.toggleInput?.parentElement.querySelector("div:last-of-type");

    // Get graph direction toggle elements
    this.directionToggleInput = this.el.querySelector(
      '[data-graph-direction-toggle="toggle"]',
    );
    this.directionToggleBg =
      this.directionToggleInput?.parentElement.querySelector(
        "div:first-of-type",
      );
    this.directionToggleKnob =
      this.directionToggleInput?.parentElement.querySelector(
        "div:last-of-type",
      );

    // Set initial toggle states
    this.updateToggle();
    this.updateDirectionToggle();

    // Listen for view mode toggle click
    if (this.toggleInput) {
      this._onToggleChange = (e) => {
        // Toggle between spaced and compact
        const newMode = this.viewMode === "spaced" ? "compact" : "spaced";

        this.viewMode = newMode;
        localStorage.setItem("graph_view_mode", newMode);

        // Update toggle visual state
        this.updateToggle();

        // Notify the graph hook via custom DOM event (client-side only)
        const graphEls = document.querySelectorAll('[phx-hook="Graph"]');
        graphEls.forEach((graphEl) => {
          const event = new CustomEvent("viewModeChanged", {
            detail: { view_mode: newMode },
          });
          graphEl.dispatchEvent(event);
        });
      };
      this.toggleInput.addEventListener("change", this._onToggleChange);
    }

    // Listen for graph direction toggle click
    if (this.directionToggleInput) {
      this._onDirectionToggleChange = (e) => {
        // Toggle between TB (top-bottom) and BT (bottom-top)
        const newDirection = this.graphDirection === "TB" ? "BT" : "TB";

        this.graphDirection = newDirection;
        localStorage.setItem("graph_direction", newDirection);

        // Update toggle visual state
        this.updateDirectionToggle();

        // Notify the graph hook via custom DOM event (client-side only)
        const graphEls = document.querySelectorAll('[phx-hook="Graph"]');
        graphEls.forEach((graphEl) => {
          const event = new CustomEvent("graphDirectionChanged", {
            detail: { direction: newDirection },
          });
          graphEl.dispatchEvent(event);
        });
      };
      this.directionToggleInput.addEventListener(
        "change",
        this._onDirectionToggleChange,
      );
    }
  },

  updateToggle() {
    if (!this.toggleInput || !this.toggleBg || !this.toggleKnob) return;

    const isCompact = this.viewMode === "compact";

    // Update checkbox state
    this.toggleInput.checked = isCompact;

    // Update background color
    if (isCompact) {
      this.toggleBg.classList.remove("bg-gray-300");
      this.toggleBg.classList.add("bg-indigo-600");
    } else {
      this.toggleBg.classList.remove("bg-indigo-600");
      this.toggleBg.classList.add("bg-gray-300");
    }

    // Update knob position
    if (isCompact) {
      this.toggleKnob.classList.add("translate-x-4");
    } else {
      this.toggleKnob.classList.remove("translate-x-4");
    }
  },

  updateDirectionToggle() {
    if (
      !this.directionToggleInput ||
      !this.directionToggleBg ||
      !this.directionToggleKnob
    )
      return;

    const isBottomUp = this.graphDirection === "BT";

    // Update checkbox state
    this.directionToggleInput.checked = isBottomUp;

    // Update background color
    if (isBottomUp) {
      this.directionToggleBg.classList.remove("bg-gray-300");
      this.directionToggleBg.classList.add("bg-indigo-600");
    } else {
      this.directionToggleBg.classList.remove("bg-indigo-600");
      this.directionToggleBg.classList.add("bg-gray-300");
    }

    // Update knob position
    if (isBottomUp) {
      this.directionToggleKnob.classList.add("translate-x-4");
    } else {
      this.directionToggleKnob.classList.remove("translate-x-4");
    }
  },
};

// Client-side view mode toggle hook
// Handles switching between spaced and compact graph views without server round-trips

export const ViewModeHook = {
  mounted() {
    // Get initial view mode from localStorage or default to "spaced"
    const savedViewMode = localStorage.getItem("graph_view_mode") || "spaced";
    this.viewMode = savedViewMode;

    // Get initial graph direction from localStorage or default to "TB" (top-bottom)
    const savedDirection = localStorage.getItem("graph_direction") || "TB";
    this.graphDirection = ["TB", "BT", "LR", "RL"].includes(savedDirection)
      ? savedDirection
      : "TB";

    // Get initial uniform style state from localStorage (default to false/disabled)
    // Uniform style also controls badges (uniform ON = badges ON, uniform OFF = badges OFF)
    const savedUniform = localStorage.getItem("uniform_node_style");
    this.uniformStyle = savedUniform === "true";

    // Keep badge state consistent with the restored uniform style on initial load.
    // This prevents startup mismatches when uniform mode is already persisted.
    localStorage.setItem(
      "show_type_badges",
      this.uniformStyle ? "true" : "false",
    );

    this._bindEvents();
  },

  updated() {
    this._bindEvents();
  },

  destroyed() {
    if (this.toggleInput && this._onToggleChange) {
      this.toggleInput.removeEventListener("change", this._onToggleChange);
    }
    if (this._directionButtonBindings) {
      this._directionButtonBindings.forEach(({ btn, handler }) => {
        btn.removeEventListener("click", handler);
      });
      this._directionButtonBindings = null;
    }
    if (this.uniformToggleInput && this._onUniformToggleChange) {
      this.uniformToggleInput.removeEventListener(
        "change",
        this._onUniformToggleChange,
      );
    }
  },

  _bindEvents() {
    // Cleanup old listeners if they exist
    if (this.toggleInput && this._onToggleChange) {
      this.toggleInput.removeEventListener("change", this._onToggleChange);
    }
    if (this._directionButtonBindings) {
      this._directionButtonBindings.forEach(({ btn, handler }) => {
        btn.removeEventListener("click", handler);
      });
      this._directionButtonBindings = null;
    }
    if (this.uniformToggleInput && this._onUniformToggleChange) {
      this.uniformToggleInput.removeEventListener(
        "change",
        this._onUniformToggleChange,
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

    // Get uniform style toggle elements
    this.uniformToggleInput = this.el.querySelector(
      '[data-uniform-style-toggle="toggle"]',
    );
    this.uniformToggleBg = this.uniformToggleInput?.parentElement.querySelector(
      ".uniform-style-track",
    );
    this.uniformToggleKnob =
      this.uniformToggleInput?.parentElement.querySelector(
        ".uniform-style-thumb",
      );

    // Get graph direction option buttons
    this.directionButtons = Array.from(
      this.el.querySelectorAll("[data-graph-direction-option]"),
    );

    // Set initial toggle states
    this.updateToggle();
    this.updateUniformToggle();
    this.updateDirectionButtons();

    // Listen for view mode toggle click
    if (this.toggleInput) {
      this._onToggleChange = (e) => {
        // Toggle between spaced and compact
        const newMode = this.viewMode === "spaced" ? "compact" : "spaced";

        this.viewMode = newMode;
        localStorage.setItem("graph_view_mode", newMode);

        // Update toggle visual state
        this.updateToggle();

        this._dispatchToGraphs("viewModeChanged", { view_mode: newMode });
      };
      this.toggleInput.addEventListener("change", this._onToggleChange);
    }

    // Listen for uniform style toggle click
    // This also controls badges (uniform ON = badges ON, uniform OFF = badges OFF)
    if (this.uniformToggleInput) {
      this._onUniformToggleChange = (e) => {
        // Toggle uniform style on/off
        const newState = !this.uniformStyle;

        this.uniformStyle = newState;
        localStorage.setItem("uniform_node_style", newState ? "true" : "false");
        // Sync badges with uniform style
        localStorage.setItem("show_type_badges", newState ? "true" : "false");

        // Update toggle visual state
        this.updateUniformToggle();

        // Dispatch event - full graph redraw picks up badge setting from localStorage
        this._dispatchToGraphs("uniformStyleChanged", { enabled: newState });
      };
      this.uniformToggleInput.addEventListener(
        "change",
        this._onUniformToggleChange,
      );
    }

    // Listen for graph direction selection
    this._directionButtonBindings = [];
    this.directionButtons.forEach((btn) => {
      const handler = (e) => {
        e.preventDefault();
        const newDirection = btn.dataset.graphDirectionOption;
        if (!["TB", "BT", "LR", "RL"].includes(newDirection)) return;
        if (this.graphDirection === newDirection) return;

        this.graphDirection = newDirection;
        localStorage.setItem("graph_direction", newDirection);
        this.updateDirectionButtons();
        this._dispatchToGraphs("graphDirectionChanged", {
          direction: newDirection,
        });
      };

      btn.addEventListener("click", handler);
      this._directionButtonBindings.push({ btn, handler });
    });
  },

  _dispatchToGraphs(eventName, detail) {
    const graphEls = document.querySelectorAll('[phx-hook="Graph"]');
    graphEls.forEach((graphEl) => {
      const event = new CustomEvent(eventName, { detail });
      graphEl.dispatchEvent(event);
    });
  },

  updateDirectionButtons() {
    if (!Array.isArray(this.directionButtons)) return;

    this.directionButtons.forEach((btn) => {
      const selected = btn.dataset.graphDirectionOption === this.graphDirection;

      if (selected) {
        btn.classList.add(
          "bg-indigo-600",
          "text-white",
          "border-indigo-600",
          "shadow-sm",
        );
        btn.classList.remove(
          "bg-white",
          "text-gray-700",
          "border-gray-300",
          "hover:bg-gray-50",
          "hover:border-gray-300",
        );
      } else {
        btn.classList.remove(
          "bg-indigo-600",
          "text-white",
          "border-indigo-600",
          "shadow-sm",
        );
        btn.classList.add(
          "bg-white",
          "text-gray-700",
          "border-gray-300",
          "hover:bg-gray-50",
          "hover:border-gray-300",
        );
      }

      btn.setAttribute("aria-pressed", selected ? "true" : "false");
    });
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

  updateUniformToggle() {
    if (
      !this.uniformToggleInput ||
      !this.uniformToggleBg ||
      !this.uniformToggleKnob
    )
      return;

    const isEnabled = this.uniformStyle;

    // Update checkbox state
    this.uniformToggleInput.checked = isEnabled;

    // Update background color
    if (isEnabled) {
      this.uniformToggleBg.classList.remove("bg-gray-300");
      this.uniformToggleBg.classList.add("bg-indigo-600");
    } else {
      this.uniformToggleBg.classList.remove("bg-indigo-600");
      this.uniformToggleBg.classList.add("bg-gray-300");
    }

    // Update knob position
    if (isEnabled) {
      this.uniformToggleKnob.classList.add("translate-x-4");
    } else {
      this.uniformToggleKnob.classList.remove("translate-x-4");
    }
  },
};

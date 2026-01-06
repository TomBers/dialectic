// Client-side view mode toggle hook
// Handles switching between spaced and compact graph views without server round-trips

export const ViewModeHook = {
  mounted() {
    // Get initial view mode from localStorage or default to "spaced"
    const savedViewMode = localStorage.getItem("graph_view_mode") || "spaced";
    this.viewMode = savedViewMode;

    // Get toggle elements
    this.toggleInput = this.el.querySelector(
      '[data-view-mode-toggle="toggle"]',
    );
    this.toggleBg =
      this.toggleInput?.parentElement.querySelector("div:first-of-type");
    this.toggleKnob =
      this.toggleInput?.parentElement.querySelector("div:last-of-type");

    // Set initial toggle state
    this.updateToggle();

    // Listen for toggle click
    if (this.toggleInput) {
      this.toggleInput.addEventListener("change", (e) => {
        // Toggle between spaced and compact
        const newMode = this.viewMode === "spaced" ? "compact" : "spaced";

        this.viewMode = newMode;
        localStorage.setItem("graph_view_mode", newMode);

        // Update toggle visual state
        this.updateToggle();

        // Notify the graph hook via custom DOM event (client-side only)
        const graphEl = document.getElementById("cy");
        if (graphEl) {
          const event = new CustomEvent("viewModeChanged", {
            detail: { view_mode: newMode },
          });
          graphEl.dispatchEvent(event);
        }
      });
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
};

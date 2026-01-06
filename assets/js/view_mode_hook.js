// Client-side view mode toggle hook
// Handles switching between spaced and compact graph views without server round-trips

export const ViewModeHook = {
  mounted() {
    // Get initial view mode from localStorage or default to "spaced"
    const savedViewMode = localStorage.getItem("graph_view_mode") || "spaced";
    this.viewMode = savedViewMode;

    // Set initial button states
    this.updateButtons();

    // Listen for toggle events
    this.el.addEventListener("click", (e) => {
      const button = e.target.closest("[data-view-mode-toggle]");
      if (!button) return;

      const newMode = button.dataset.viewModeToggle;
      if (newMode === this.viewMode) return; // Already active

      this.viewMode = newMode;
      localStorage.setItem("graph_view_mode", newMode);

      // Update button states
      this.updateButtons();

      // Notify the graph hook via custom DOM event (client-side only)
      const graphEl = document.getElementById("cy");
      if (graphEl) {
        const event = new CustomEvent("viewModeChanged", {
          detail: { view_mode: newMode },
        });
        graphEl.dispatchEvent(event);
      }
    });
  },

  updateButtons() {
    const spacedBtn = this.el.querySelector('[data-view-mode-toggle="spaced"]');
    const compactBtn = this.el.querySelector(
      '[data-view-mode-toggle="compact"]',
    );

    if (spacedBtn) {
      if (this.viewMode === "spaced") {
        spacedBtn.classList.add("bg-indigo-600", "text-white");
        spacedBtn.classList.remove(
          "text-gray-700",
          "hover:bg-gray-50",
          "border-r",
          "border-gray-200",
        );
      } else {
        spacedBtn.classList.remove("bg-indigo-600", "text-white");
        spacedBtn.classList.add(
          "text-gray-700",
          "hover:bg-gray-50",
          "border-r",
          "border-gray-200",
        );
      }
    }

    if (compactBtn) {
      if (this.viewMode === "compact") {
        compactBtn.classList.add("bg-indigo-600", "text-white");
        compactBtn.classList.remove("text-gray-700", "hover:bg-gray-50");
      } else {
        compactBtn.classList.remove("bg-indigo-600", "text-white");
        compactBtn.classList.add("text-gray-700", "hover:bg-gray-50");
      }
    }
  },
};

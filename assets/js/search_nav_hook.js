/**
 * SearchNav hook – manages ArrowUp / ArrowDown keyboard navigation
 * inside the quick-search results list.
 *
 * Attach to the search panel container element:
 *
 *     <div id="quick-search-panel" phx-hook="SearchNav">
 *
 * The hook listens for keydown events on the **document** in the
 * **capture phase** so it intercepts arrow keys before the graph's
 * own keydown handler (registered on document in the bubble phase
 * by draw_graph.js) can navigate graph nodes.  When an arrow key
 * is handled here we call `stopImmediatePropagation()` to prevent
 * any other listeners at the same level from firing.
 */
const SearchNav = {
  mounted() {
    this._onKeydown = (e) => {
      if (e.key !== "ArrowDown" && e.key !== "ArrowUp" && e.key !== "Enter") {
        return;
      }

      const buttons = Array.from(
        this.el.querySelectorAll("ul button[phx-click]"),
      );
      if (buttons.length === 0) return;

      const active = document.activeElement;
      const currentIndex = buttons.indexOf(active);

      if (e.key === "ArrowDown") {
        e.preventDefault();
        e.stopImmediatePropagation();
        const next =
          currentIndex < 0 || currentIndex >= buttons.length - 1
            ? buttons[0]
            : buttons[currentIndex + 1];
        next.focus();
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        e.stopImmediatePropagation();
        const prev =
          currentIndex <= 0
            ? buttons[buttons.length - 1]
            : buttons[currentIndex - 1];
        prev.focus();
      } else if (e.key === "Enter" && currentIndex >= 0) {
        // When a result button is focused, Enter should activate it.
        // The browser default will submit the surrounding <form> if
        // focus is in the input, so we only intercept when a result
        // button is focused.
        e.preventDefault();
        e.stopImmediatePropagation();
        active.click();
      }
    };

    // Capture phase ensures we fire before draw_graph.js's document-level
    // bubble-phase handler, so arrow keys stay inside the search overlay.
    document.addEventListener("keydown", this._onKeydown, true);
  },

  destroyed() {
    document.removeEventListener("keydown", this._onKeydown, true);
  },
};

export default SearchNav;

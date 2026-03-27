/**
 * Lightweight hook for the presentation exit bar.
 * Listens for Escape key to exit the filtered-graph presentation mode.
 */
const PresentationHook = {
  mounted() {
    this.handleKeyDown = (e) => {
      // Don't capture keys when user is typing in an input/textarea
      const tag = (e.target && e.target.tagName) || "";
      if (tag === "INPUT" || tag === "TEXTAREA" || e.target.isContentEditable) {
        return;
      }

      if (e.key === "Escape") {
        e.preventDefault();
        this.pushEvent("exit_presentation", {});
      }
    };

    document.addEventListener("keydown", this.handleKeyDown);

    // Hide the site header immediately when the presentation bar mounts
    this._setSiteHeaderVisible(false);

    // Listen for toggle events from the server
    this.handleEvent("toggle_site_header", ({ visible }) => {
      this._setSiteHeaderVisible(visible);
    });
  },

  destroyed() {
    document.removeEventListener("keydown", this.handleKeyDown);
    // Always restore the header when the presentation bar is removed
    this._setSiteHeaderVisible(true);
  },

  /**
   * Show or hide the root-layout site header (#userHeader).
   * Directly toggles the element's display style to show or hide it.
   */
  _setSiteHeaderVisible(visible) {
    const header = document.getElementById("userHeader");
    if (!header) return;

    if (visible) {
      header.style.display = "";
    } else {
      header.style.display = "none";
    }
  },
};

/**
 * Hook for the presentation setup panel's drag-to-reorder slide list.
 * Attaches HTML5 drag-and-drop listeners to <li> items and pushes
 * a "presentation_reorder" event to the server with the new ordering.
 */
const PresentationSetupHook = {
  mounted() {
    this._ensureStyles();
    this._setupDragAndDrop();
  },

  updated() {
    this._setupDragAndDrop();
  },

  destroyed() {
    if (this._dragAbort) {
      this._dragAbort.abort();
      this._dragAbort = null;
    }
  },

  _ensureStyles() {
    if (document.getElementById("pres-drag-styles")) return;
    const style = document.createElement("style");
    style.id = "pres-drag-styles";
    style.textContent = `
      .drag-over-above { box-shadow: 0 -2px 0 0 #6366f1; }
      .drag-over-below { box-shadow: 0 2px 0 0 #6366f1; }
    `;
    document.head.appendChild(style);
  },

  _setupDragAndDrop() {
    // Abort previous listeners to prevent stacking on re-renders
    if (this._dragAbort) this._dragAbort.abort();
    this._dragAbort = new AbortController();
    const signal = this._dragAbort.signal;

    const list = this.el;
    let draggedItem = null;

    const items = list.querySelectorAll("li[draggable]");
    items.forEach((item) => {
      item.addEventListener(
        "dragstart",
        (e) => {
          draggedItem = item;
          item.classList.add("opacity-40");
          e.dataTransfer.effectAllowed = "move";
          e.dataTransfer.setData("text/plain", item.dataset.nodeId);
        },
        { signal },
      );

      item.addEventListener(
        "dragend",
        () => {
          if (draggedItem) {
            draggedItem.classList.remove("opacity-40");
          }
          draggedItem = null;
          // Remove all drag-over indicators
          list
            .querySelectorAll(".drag-over-above, .drag-over-below")
            .forEach((el) => {
              el.classList.remove("drag-over-above", "drag-over-below");
            });
        },
        { signal },
      );

      item.addEventListener(
        "dragover",
        (e) => {
          e.preventDefault();
          e.dataTransfer.dropEffect = "move";

          // Show position indicator based on cursor position
          const rect = item.getBoundingClientRect();
          const midY = rect.top + rect.height / 2;

          item.classList.remove("drag-over-above", "drag-over-below");
          if (e.clientY < midY) {
            item.classList.add("drag-over-above");
          } else {
            item.classList.add("drag-over-below");
          }
        },
        { signal },
      );

      item.addEventListener(
        "dragleave",
        () => {
          item.classList.remove("drag-over-above", "drag-over-below");
        },
        { signal },
      );

      item.addEventListener(
        "drop",
        (e) => {
          e.preventDefault();
          item.classList.remove("drag-over-above", "drag-over-below");

          if (!draggedItem || draggedItem === item) return;

          // Determine insert position
          const rect = item.getBoundingClientRect();
          const midY = rect.top + rect.height / 2;
          const insertBefore = e.clientY < midY;

          if (insertBefore) {
            list.insertBefore(draggedItem, item);
          } else {
            list.insertBefore(draggedItem, item.nextSibling);
          }

          // Collect the new order and push to server
          const newOrder = Array.from(
            list.querySelectorAll("li[data-node-id]"),
          ).map((li) => li.dataset.nodeId);

          this.pushEvent("presentation_reorder", { order: newOrder });
        },
        { signal },
      );
    });
  },
};

export default PresentationHook;
export { PresentationSetupHook };

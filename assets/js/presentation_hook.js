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
  },

  destroyed() {
    document.removeEventListener("keydown", this.handleKeyDown);
  },
};

/**
 * Hook for the presentation setup panel's drag-to-reorder slide list.
 * Attaches HTML5 drag-and-drop listeners to <li> items and pushes
 * a "presentation_reorder" event to the server with the new ordering.
 */
const PresentationSetupHook = {
  mounted() {
    this._setupDragAndDrop();
  },

  updated() {
    this._setupDragAndDrop();
  },

  _setupDragAndDrop() {
    const list = this.el;
    let draggedItem = null;

    // Clean up old listeners by cloning (avoids stacking)
    const items = list.querySelectorAll("li[draggable]");
    items.forEach((item) => {
      item.addEventListener("dragstart", (e) => {
        draggedItem = item;
        item.classList.add("opacity-40");
        e.dataTransfer.effectAllowed = "move";
        e.dataTransfer.setData("text/plain", item.dataset.nodeId);
      });

      item.addEventListener("dragend", () => {
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
      });

      item.addEventListener("dragover", (e) => {
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
      });

      item.addEventListener("dragleave", () => {
        item.classList.remove("drag-over-above", "drag-over-below");
      });

      item.addEventListener("drop", (e) => {
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
      });
    });
  },
};

export default PresentationHook;
export { PresentationSetupHook };

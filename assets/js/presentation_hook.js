const PresentationHook = {
  mounted() {
    this._slideIndex = null;

    this.handleKeyDown = (e) => {
      // Don't capture keys when user is typing in an input/textarea
      const tag = (e.target && e.target.tagName) || "";
      if (tag === "INPUT" || tag === "TEXTAREA" || e.target.isContentEditable) {
        return;
      }

      switch (e.key) {
        case "ArrowRight":
        case "PageDown":
          e.preventDefault();
          this.pushEvent("presentation_next", {});
          break;
        case " ":
          // Space advances unless Shift is held (Shift+Space = previous)
          e.preventDefault();
          if (e.shiftKey) {
            this.pushEvent("presentation_prev", {});
          } else {
            this.pushEvent("presentation_next", {});
          }
          break;
        case "ArrowLeft":
        case "PageUp":
          e.preventDefault();
          this.pushEvent("presentation_prev", {});
          break;
        case "Escape":
          e.preventDefault();
          this.pushEvent("exit_presentation", {});
          break;
      }
    };

    document.addEventListener("keydown", this.handleKeyDown);

    // Run initial entrance animation
    this._animateSlideIn();
  },

  updated() {
    // Detect slide index changes from the server-rendered data
    const counter = this.el.querySelector("[data-slide-index]");
    const newIndex = counter
      ? parseInt(counter.getAttribute("data-slide-index"), 10)
      : null;

    if (this._slideIndex !== null && newIndex !== this._slideIndex) {
      this._animateSlideIn();
    }
    this._slideIndex = newIndex;
  },

  destroyed() {
    document.removeEventListener("keydown", this.handleKeyDown);
  },

  // ── Private helpers ──────────────────────────────────────────────

  /**
   * Applies a brief entrance animation to the slide card.
   * Uses opacity + subtle translateY for a clean fade-up effect.
   */
  _animateSlideIn() {
    const slideContent = this.el.querySelector(".presentation-slide-content");
    if (!slideContent) return;

    // Reset to starting state
    slideContent.style.transition = "none";
    slideContent.style.opacity = "0";
    slideContent.style.transform = "translateY(12px)";

    // Force reflow so the browser registers the starting position
    slideContent.offsetHeight;

    // Animate to final state
    slideContent.style.transition =
      "opacity 350ms ease-out, transform 350ms ease-out";
    slideContent.style.opacity = "1";
    slideContent.style.transform = "translateY(0)";

    // Also scroll the content area back to top on slide change
    const scrollArea = slideContent.querySelector(".overflow-y-auto");
    if (scrollArea) {
      scrollArea.scrollTop = 0;
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

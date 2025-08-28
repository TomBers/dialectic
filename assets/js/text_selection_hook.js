const textSelectionHook = {
  mounted() {
    this.handleSelection = this.handleSelection.bind(this);
    this.hideSelectionActions = this.hideSelectionActions.bind(this);

    // Get node ID from data attribute
    this.nodeId = this.el.dataset.nodeId;

    // Store element ID to prevent duplicate events
    this.elId = this.el.id;

    // Add event listeners for this specific container
    this.el.addEventListener("mouseup", this.handleSelection);
    this.el.addEventListener("touchend", this.handleSelection);

    // Handle clicks outside the selection
    document.addEventListener("mousedown", (e) => {
      if (!this.el.contains(e.target)) {
        this.hideSelectionActions();
      }
    });

    // Handle selection clearing
    document.addEventListener("selectionchange", () => {
      const selection = window.getSelection();
      if (selection.isCollapsed) {
        this.hideSelectionActions();
      }
    });
  },

  destroyed() {
    this.el.removeEventListener("mouseup", this.handleSelection);
    this.el.removeEventListener("touchend", this.handleSelection);
  },

  handleSelection(event) {
    // Add small delay to ensure selection is properly registered
    setTimeout(() => {
      const selection = window.getSelection();
      const selectionActionsEl = this.el.querySelector(".selection-actions");

      if (!selectionActionsEl) return;

      // Check if selection is empty or not within this component
      if (selection.isCollapsed || !this.isSelectionInComponent(selection)) {
        this.hideSelectionActions();
        return;
      }

      const selectedText = selection.toString().trim();
      if (selectedText.length === 0) {
        this.hideSelectionActions();
        return;
      }

      // If we're not the closest container to the selection, don't show our button
      if (!this.isClosestSelectionContainer()) {
        this.hideSelectionActions();
        return;
      }

      // Get the range and its bounding rectangle
      const range = selection.getRangeAt(0);
      const rect = range.getBoundingClientRect();

      // Get the container's bounding rectangle
      const containerRect = this.el.getBoundingClientRect();

      // Make the button visible so we can measure its width
      selectionActionsEl.classList.remove("hidden");

      // Get button dimensions after making it visible
      const buttonWidth = selectionActionsEl.offsetWidth;
      const buttonHeight = selectionActionsEl.offsetHeight;

      // Calculate position relative to the container
      // Position below the selection with some padding
      const top = rect.bottom - containerRect.top + 8;

      // Center the button on the selection, but keep it within bounds
      let leftPos =
        rect.left + rect.width / 2 - buttonWidth / 2 - containerRect.left;

      // Ensure button stays within container bounds with padding
      const padding = 8;
      leftPos = Math.max(padding, leftPos);
      leftPos = Math.min(this.el.clientWidth - buttonWidth - padding, leftPos);

      // Apply the calculated positions
      selectionActionsEl.style.top = `${top}px`;
      selectionActionsEl.style.left = `${leftPos}px`;

      // Set up the button to send the selected text to the server
      const actionButton = selectionActionsEl.querySelector("button");
      if (actionButton) {
        actionButton.onclick = () => {
          this.pushEvent("reply-and-answer", {
            vertex: { content: selectedText },
            prefix: "explain",
          });

          // Hide the action button after clicking
          this.hideSelectionActions();
        };
      }
    }, 10); // 10ms delay
  },

  isSelectionInComponent(selection) {
    if (selection.rangeCount === 0) return false;

    const range = selection.getRangeAt(0);
    const selectionContainer = range.commonAncestorContainer;

    // Check if the selection is within this component
    return this.el.contains(selectionContainer);
  },

  isClosestSelectionContainer() {
    const selection = window.getSelection();
    if (selection.rangeCount === 0) return false;

    const range = selection.getRangeAt(0);
    let container = range.commonAncestorContainer;

    // If the container is a text node, get its parent
    if (container.nodeType === 3) {
      container = container.parentNode;
    }

    // Find all potential selection containers that contain this selection
    const allContainers = document.querySelectorAll(
      '[phx-hook="TextSelectionHook"]',
    );
    let closestContainer = null;
    let minDepth = Infinity;

    // For each potential container, check if it contains the selection
    // and calculate its depth in the DOM
    allContainers.forEach((el) => {
      if (el.contains(container)) {
        // Calculate DOM depth (fewer is closer)
        let depth = 0;
        let parent = container;
        while (parent && parent !== el) {
          depth++;
          parent = parent.parentNode;
        }

        if (depth < minDepth) {
          minDepth = depth;
          closestContainer = el;
        }
      }
    });

    // Return true if this hook's element is the closest container
    return closestContainer === this.el;
  },

  hideSelectionActions() {
    const selectionActionsEl = this.el.querySelector(".selection-actions");
    if (selectionActionsEl) {
      selectionActionsEl.classList.add("hidden");
    }
  },
};

export default textSelectionHook;

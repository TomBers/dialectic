const toolTipHook = {
  mounted() {
    // Initially hide the tooltip
    this.el.style.opacity = "0";
    this.el.style.transition = "opacity 0.2s ease-out";

    // Setup debounce function
    this.debouncedHandlePositioning = this.debounce(() => {
      this.calculateAndApplyPosition();
    }, 100);

    // Run initial positioning with slight delay to ensure DOM is ready
    setTimeout(() => {
      this.calculateAndApplyPosition();
    }, 20);

    // Setup resize handler
    this.resizeListener = () => this.debouncedHandlePositioning();
    window.addEventListener("resize", this.resizeListener);
  },

  calculateAndApplyPosition() {
    // Get node position from data attribute
    const nodePosition = this.el.dataset.nodePosition
      ? JSON.parse(this.el.dataset.nodePosition)
      : null;

    if (!nodePosition) return;

    // Get tooltip dimensions
    const tooltipWidth = this.el.offsetWidth;
    const tooltipHeight = this.el.offsetHeight;

    // Get viewport dimensions
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;

    // Node center and dimensions
    const nodeCenter = {
      x: nodePosition.center_x,
      y: nodePosition.center_y,
    };
    const nodeWidth = nodePosition.width;
    const nodeHeight = nodePosition.height;

    // Calculate best position (default is below the node)
    let tooltipX = nodeCenter.x - tooltipWidth / 2;
    let tooltipY = nodePosition.bb_y2 + 10; // 10px below the node
    let placement = "bottom";

    // Check if tooltip would go below viewport bottom
    if (tooltipY + tooltipHeight > viewportHeight) {
      // Try to place above the node instead
      if (nodePosition.bb_y1 - tooltipHeight - 10 >= 0) {
        tooltipY = nodePosition.bb_y1 - tooltipHeight - 10;
        placement = "top";
      } else {
        // If can't place above, place at side if there's room
        if (nodeCenter.x + nodeWidth / 2 + tooltipWidth <= viewportWidth) {
          tooltipX = nodePosition.bb_x2 + 10;
          tooltipY = nodeCenter.y - tooltipHeight / 2;
          placement = "right";
        } else if (nodeCenter.x - nodeWidth / 2 - tooltipWidth >= 0) {
          tooltipX = nodePosition.bb_x1 - tooltipWidth - 10;
          tooltipY = nodeCenter.y - tooltipHeight / 2;
          placement = "left";
        } else {
          // Last resort: place at bottom but constrain to viewport
          tooltipY = viewportHeight - tooltipHeight - 10;
          placement = "bottom-constrained";
        }
      }
    }

    // Check if tooltip would go beyond right edge
    if (tooltipX + tooltipWidth > viewportWidth) {
      tooltipX = viewportWidth - tooltipWidth - 10;
    }

    // Check if tooltip would go beyond left edge
    if (tooltipX < 0) {
      tooltipX = 10;
    }

    // Apply position to the element
    this.el.style.left = `${tooltipX}px`;
    this.el.style.top = `${tooltipY}px`;

    // Make tooltip visible now that it's positioned
    this.el.style.opacity = "1";

    // Also send to server for any server-side needs
    const updatedPosition = {
      x: tooltipX,
      y: tooltipY,
      viewport_width: viewportWidth,
      viewport_height: viewportHeight,
      width: tooltipWidth,
      height: tooltipHeight,
      placement: placement,
    };

    this.pushEvent("update_tooltip_position", { position: updatedPosition });
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
  },
};

export default toolTipHook;

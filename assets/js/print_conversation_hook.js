const printConversationHook = {
  mounted() {
    this.el.addEventListener("click", () => {
      // Get graph name/title for the print
      const graphName = this.el.getAttribute("data-graph-name");

      // Use slug from URL if available, otherwise use graph name
      const pathParts = window.location.pathname.split("/");
      const graphSlug =
        pathParts[1] === "g" && pathParts[2] ? pathParts[2] : null;
      const displayTitle = graphSlug || graphName;

      document.body.setAttribute("data-graph-name", displayTitle);
      document.title = displayTitle;
      document.body.setAttribute(
        "data-print-date",
        new Date().toLocaleString(),
      );

      // Save original styles for restoration
      const originalStyles = new Map();

      // Force show main content area (may be hidden when minimap is open)
      const mainContent = document.getElementById("linear-main-content");
      if (mainContent) {
        originalStyles.set("mainContent", {
          display: mainContent.style.display,
          visibility: mainContent.style.visibility,
          opacity: mainContent.style.opacity,
          position: mainContent.style.position,
          height: mainContent.style.height,
          maxHeight: mainContent.style.maxHeight,
          overflow: mainContent.style.overflow,
          className: mainContent.className,
        });

        mainContent.style.display = "block";
        mainContent.style.visibility = "visible";
        mainContent.style.opacity = "1";
        mainContent.style.position = "static";
        mainContent.style.height = "auto";
        mainContent.style.maxHeight = "none";
        mainContent.style.overflow = "visible";
        mainContent.classList.remove("hidden");
      }

      // CRITICAL: Force scroll container to expand fully
      const scroller = document.getElementById("linear-scroller");
      if (scroller) {
        originalStyles.set("scroller", {
          cssText: scroller.style.cssText,
        });

        scroller.style.display = "block";
        scroller.style.overflow = "visible";
        scroller.style.height = "auto";
        scroller.style.maxHeight = "none";
        scroller.style.minHeight = "0";
        scroller.style.position = "static";
      }

      // Force all parent containers to expand
      const allScrollContainers = document.querySelectorAll(
        ".overflow-y-auto, .overflow-auto, .flex-1, .h-full, .h-screen",
      );
      const scrollContainerStyles = [];
      allScrollContainers.forEach((container) => {
        scrollContainerStyles.push({
          element: container,
          cssText: container.style.cssText,
        });

        container.style.overflow = "visible";
        container.style.height = "auto";
        container.style.maxHeight = "none";
        container.style.minHeight = "0";
        container.style.display = "block";
      });

      // Hide minimap if it's open
      const minimap = document.getElementById("linear-minimap");
      const minimapWasVisible = minimap && minimap.offsetParent !== null;
      if (minimap) {
        minimap.style.display = "none";
      }

      // Expand all nodes before printing if some are collapsed
      const hiddenNodes = document.querySelectorAll(
        '.node[style*="display: none"]',
      );
      const wasExpanded = [];

      hiddenNodes.forEach((node) => {
        wasExpanded.push(node);
        node.style.display = "block";
      });

      // Make all nodes explicitly visible
      const allNodes = document.querySelectorAll(".node");
      allNodes.forEach((node) => {
        node.style.visibility = "visible";
        node.style.opacity = "1";
        node.style.display = "block";
      });

      // Force browser to recalculate layout before printing
      document.body.offsetHeight;

      // Longer delay to ensure full content rendering
      setTimeout(() => {
        // Call browser print function
        window.print();

        // After print dialog closes, restore everything
        setTimeout(() => {
          // Restore collapsed nodes
          wasExpanded.forEach((node) => {
            node.style.display = "none";
          });

          // Restore main content
          if (mainContent && originalStyles.has("mainContent")) {
            const saved = originalStyles.get("mainContent");
            mainContent.style.display = saved.display;
            mainContent.style.visibility = saved.visibility;
            mainContent.style.opacity = saved.opacity;
            mainContent.style.position = saved.position;
            mainContent.style.height = saved.height;
            mainContent.style.maxHeight = saved.maxHeight;
            mainContent.style.overflow = saved.overflow;
            mainContent.className = saved.className;
          }

          // Restore scroller
          if (scroller && originalStyles.has("scroller")) {
            scroller.style.cssText = originalStyles.get("scroller").cssText;
          }

          // Restore all scroll containers
          scrollContainerStyles.forEach((saved) => {
            saved.element.style.cssText = saved.cssText;
          });

          // Restore minimap if it was visible
          if (minimap && minimapWasVisible) {
            minimap.style.display = "";
          }
        }, 500);
      }, 600);
    });
  },
};

export default printConversationHook;

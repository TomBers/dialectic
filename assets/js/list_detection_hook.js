const listDetectionHook = {
  mounted() {
    const { children } = this.el.dataset;
    // Checks if node has children
    // this is to stop someone re-running the branching leading to lots of duplicate nodes
    if (Number(children) === 0) {
      this.checkForLists();
    }
  },

  updated() {
    const { children } = this.el.dataset;
    if (Number(children) === 0) {
      this.checkForLists();
    }
  },

  checkForLists() {
    // This hook is attached directly to the content div containing the HTML
    const listItems = [];

    // 1. Check for traditional HTML lists (ul, ol)
    const lists = this.el.querySelectorAll("ul, ol");
    lists.forEach((list) => {
      const items = list.querySelectorAll("li");
      items.forEach((item) => {
        const text = item.textContent.trim();
        if (text) {
          listItems.push(text);
        }
      });
    });

    // 2. Check for paragraphs that start with bullet points
    const paragraphs = this.el.querySelectorAll("p");
    paragraphs.forEach((p) => {
      const text = p.textContent.trim();
      // Check if the paragraph's content starts with a bullet character
      if (
        text.startsWith("•") ||
        text.startsWith("-") ||
        text.startsWith("*")
      ) {
        // Check if this is a single-item list or multiple items separated by breaks
        if (p.innerHTML.includes("<br>") || p.innerHTML.includes("<br />")) {
          // Split by <br> tags to get individual items
          const html = p.innerHTML;
          const segments = html.split(/<br\s*\/?>/i);

          segments.forEach((segment) => {
            const itemText = this.extractBulletPointText(segment.trim());
            if (itemText) {
              listItems.push(itemText);
            }
          });
        } else {
          // Just a single bullet point
          const itemText = this.extractBulletPointText(text);
          if (itemText) {
            listItems.push(itemText);
          }
        }
      } else {
        // 3. Check for paragraphs with embedded bullet points
        const html = p.innerHTML;
        // If the paragraph contains bullet points but doesn't start with one
        if (html.includes("•") || html.match(/[^a-zA-Z0-9][-*][^a-zA-Z0-9]/)) {
          // First check if there are <br> tags separating items
          if (html.includes("<br>") || html.includes("<br />")) {
            const segments = html.split(/<br\s*\/?>/i);

            segments.forEach((segment) => {
              const itemText = this.extractBulletPointText(segment.trim());
              if (itemText) {
                listItems.push(itemText);
              }
            });
          } else {
            // Try to find bullet points within the text itself
            const bulletPattern = /([•\-*]\s*[^•\-*]+)(?=[•\-*]|$)/g;
            const matches = text.match(bulletPattern);

            if (matches) {
              matches.forEach((match) => {
                const itemText = this.extractBulletPointText(match.trim());
                if (itemText) {
                  listItems.push(itemText);
                }
              });
            }
          }
        }
      }
    });

    // Process the list items if any were found
    if (listItems.length > 0) {
      // console.log("✅ Total list items found:", listItems.length, listItems);

      // Add a button to the page to allow the user to explore all points
      const button = document.createElement("button");
      button.classList.add("menu-button", "explore-all-points-button");
      button.innerHTML = `
        <span class="icon">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
          <path stroke-linecap="round" stroke-linejoin="round" d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.456 2.456L21.75 6l-1.035.259a3.375 3.375 0 0 0-2.456 2.456ZM16.894 20.567 16.5 21.75l-.394-1.183a2.25 2.25 0 0 0-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 0 0 1.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 0 0 1.423 1.423l1.183.394-1.183.394a2.25 2.25 0 0 0-1.423 1.423Z" />
          </svg>
        </span>
        <span class="label">Explore all points</span>
      `;

      button.addEventListener("click", () => {
        this.pushEvent("branch_list", {
          items: listItems,
        });
      });
      this.el.prepend(button);
    }
  },

  extractBulletPointText(text) {
    // Extract the text following the bullet character
    const bulletMatch = text.match(/^[•\-*]\s*(.*)/);
    if (bulletMatch) {
      return bulletMatch[1].trim();
    }

    // If it doesn't start with a bullet but contains one
    const inlineMatch = text.match(/[•\-*]\s*(.*?)(?=[•\-*]|$)/);
    if (inlineMatch) {
      return inlineMatch[1].trim();
    }

    return null;
  },
};

export default listDetectionHook;

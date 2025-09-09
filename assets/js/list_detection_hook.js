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

    // Prefer ordered-numbered main points first
    let foundOrdered = false;

    // 1. Ordered HTML lists: collect only top-level <li> and exclude nested list text
    const orderedLists = this.el.querySelectorAll("ol");
    orderedLists.forEach((list) => {
      const topLevelLis = Array.from(list.children).filter(
        (el) => el.tagName === "LI",
      );
      topLevelLis.forEach((li) => {
        const clone = li.cloneNode(true);
        // Remove any nested lists so we only keep the top-level item's text
        clone.querySelectorAll("ul, ol").forEach((nested) => nested.remove());
        const text = clone.textContent.trim();
        if (text) {
          listItems.push(text);
        }
      });
    });
    if (listItems.length > 0) {
      foundOrdered = true;
    }

    // 2. Ordered-numbered paragraphs (e.g., "1. Title", "2) Next")
    if (!foundOrdered) {
      const paragraphs = this.el.querySelectorAll("p");
      paragraphs.forEach((p) => {
        const html = p.innerHTML;
        const segments =
          html.includes("<br>") || html.includes("<br />")
            ? html.split(/<br\s*\/?>/i)
            : [p.textContent];

        segments.forEach((segment) => {
          const raw = segment.replace(/<[^>]*>/g, "").trim();
          const match = raw.match(/^\s*(\d{1,3})[.)]\s+(.*)$/);
          if (match) {
            const itemText = match[2].trim();
            if (itemText) {
              listItems.push(itemText);
            }
          }
        });
      });

      if (listItems.length > 0) {
        foundOrdered = true;
      }
    }

    // 3. Fallback to unordered top-level bullets only if no ordered items were found
    if (!foundOrdered) {
      // 3a. Unordered HTML lists: only top-level <li>, excluding nested lists
      const unorderedLists = this.el.querySelectorAll("ul");
      unorderedLists.forEach((list) => {
        const topLevelLis = Array.from(list.children).filter(
          (el) => el.tagName === "LI",
        );
        topLevelLis.forEach((li) => {
          const clone = li.cloneNode(true);
          clone.querySelectorAll("ul, ol").forEach((nested) => nested.remove());
          const text = clone.textContent.trim();
          if (text) {
            listItems.push(text);
          }
        });
      });

      // 3b. Bullet paragraphs that start with a bullet (ignore embedded bullets)
      const paragraphs = this.el.querySelectorAll("p");
      paragraphs.forEach((p) => {
        const text = p.textContent.trim();
        if (
          text.startsWith("•") ||
          text.startsWith("-") ||
          text.startsWith("*")
        ) {
          if (p.innerHTML.includes("<br>") || p.innerHTML.includes("<br />")) {
            const segments = p.innerHTML.split(/<br\s*\/?>/i);
            segments.forEach((segment) => {
              const itemText = this.extractBulletPointText(segment.trim());
              if (itemText) {
                listItems.push(itemText);
              }
            });
          } else {
            const itemText = this.extractBulletPointText(text);
            if (itemText) {
              listItems.push(itemText);
            }
          }
        }
      });
    }

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

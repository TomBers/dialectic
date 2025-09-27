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
      // Cache detected list items for external toolbar usage
      this.el.dataset.listItems = JSON.stringify(listItems);
    } else {
      // Clear cached list items if none are detected
      delete this.el.dataset.listItems;
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

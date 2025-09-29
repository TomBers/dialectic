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
    // One-indent heuristic:
    // - Collect only items that are one level of indentation:
    //   direct <li> children of a <ul>/<ol> that itself is directly under a top-level <li>
    // - Exclude label-like items (e.g., ending with ":" or starting with "Short answer:")
    // - Dedupe and cache
    const items = [];

    const clean = (s) => (s || "").replace(/\s+/g, " ").trim();

    const textFromLi = (li) => {
      const clone = li.cloneNode(true);
      // Exclude nested list contents
      clone.querySelectorAll("ul, ol").forEach((n) => n.remove());
      return clean(clone.textContent || "");
    };

    // For each top-level list item, collect one-indent bullets from its direct nested list(s)
    Array.from(this.el.querySelectorAll("li")).forEach((li) => {
      const nestedLists = Array.from(li.children).filter(
        (el) => el.tagName === "UL" || el.tagName === "OL",
      );
      nestedLists.forEach((list) => {
        Array.from(list.children)
          .filter((el) => el.tagName === "LI")
          .forEach((nli) => {
            const txt = textFromLi(nli);
            if (!txt) return;
            if (/^short answer\s*:/i.test(txt)) return;
            if (/:$/.test(txt)) return;
            items.push(txt);
          });
      });
    });

    const deduped = Array.from(new Set(items));

    if (deduped.length > 0) {
      this.el.dataset.listItems = JSON.stringify(deduped);
    } else {
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

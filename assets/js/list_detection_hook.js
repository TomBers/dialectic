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
    // Ultra-simple heuristic:
    // - Collect all <li> texts (including nested)
    // - Remove any bullet that starts with "Short answer:" (case-insensitive)
    // - Remove any bullet that ends with ":"
    // - Dedupe and cache in data-list-items
    const items = [];

    const clean = (s) => (s || "").replace(/\s+/g, " ").trim();

    const textFromLi = (li) => {
      const clone = li.cloneNode(true);
      // Keep only this item's own text; exclude nested list contents
      clone.querySelectorAll("ul, ol").forEach((n) => n.remove());
      return clean(clone.textContent || "");
    };

    Array.from(this.el.querySelectorAll("li")).forEach((li) => {
      const txt = textFromLi(li);
      if (!txt) return;
      // Filter rules
      if (/^short answer\s*:/i.test(txt)) return;
      if (/:$/.test(txt)) return;
      items.push(txt);
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

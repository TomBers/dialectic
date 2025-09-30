const listDetectionHook = {
  mounted() {
    this.checkForLists();
  },

  updated() {
    this.checkForLists();
  },

  checkForLists() {
    // Collect both styles:
    // 1) Nested sub-bullets (one-indent under a parent list item)
    // 2) Top-level leaf bullets (direct li under a root ul/ol with no nested lists)
    const items = [];

    const clean = (s) => (s || "").replace(/\s+/g, " ").trim();
    const isHeadingLike = (txt) => {
      if (!txt) return true;
      if (/^short answer\s*:/i.test(txt)) return true;
      if (/:$/.test(txt)) return true;
      return false;
    };

    const textFromLi = (li) => {
      const clone = li.cloneNode(true);
      // Exclude nested list contents
      clone.querySelectorAll("ul, ol").forEach((n) => n.remove());
      return clean(clone.textContent || "");
    };

    const root = this.el;

    // 1) Nested sub-bullets (depth 2 under a parent li)
    Array.from(root.querySelectorAll("li")).forEach((li) => {
      const nestedLists = Array.from(li.children).filter(
        (el) => el.tagName === "UL" || el.tagName === "OL",
      );
      nestedLists.forEach((list) => {
        Array.from(list.children)
          .filter((el) => el.tagName === "LI")
          .forEach((nli) => {
            const txt = textFromLi(nli);
            if (!txt) return;
            if (isHeadingLike(txt)) return;
            items.push(txt);
          });
      });
    });

    // 2) Top-level leaf bullets (depth 1 li under root ul/ol that have no nested lists)
    const topLists = Array.from(root.querySelectorAll("ul, ol")).filter(
      (list) => !list.closest("li"),
    );
    topLists.forEach((list) => {
      Array.from(list.children)
        .filter((el) => el.tagName === "LI")
        .forEach((li) => {
          const hasNested = Array.from(li.children).some(
            (el) => el.tagName === "UL" || el.tagName === "OL",
          );
          if (hasNested) return;
          const txt = textFromLi(li);
          if (!txt) return;
          if (isHeadingLike(txt)) return;
          items.push(txt);
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

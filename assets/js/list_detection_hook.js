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

export function extractListItems(root) {
  const items = [];

  if (!root) return items;

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

  return Array.from(new Set(items));
}

const listDetectionHook = {
  mounted() {
    // Attach helper to element so it can be called on-demand
    this.el.extractListItems = () => extractListItems(this.el);

    // Listen for custom event to trigger extraction
    this.el.addEventListener("detect-lists", (e) => {
      const items = extractListItems(this.el);
      // You can dispatch an event back or use the items as needed
      // e.g. this.pushEvent("lists_detected", { items });
      console.debug("List detection triggered manually", items);
    });
  },

  updated() {
    // No automatic scanning to prevent performance issues
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

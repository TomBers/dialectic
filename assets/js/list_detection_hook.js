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
    // Check for both ordered and unordered lists
    const lists = this.el.querySelectorAll("ul, ol");
    const listItems = [];
    // Also look for paragraphs that seem to act like lists
    const paragraphs = this.el.querySelectorAll("p");
    paragraphs.forEach((p) => {
      const text = p.textContent.trim();
      // Check if the paragraph's content starts with the bullet character
      if (text.startsWith("•")) {
        listItems.push(text);
      }
    });

    if (lists.length > 0 || listItems.length > 0) {
      // console.log("🎯 Lists detected!", lists.length, "list(s) found");

      lists.forEach((list) => {
        // console.log("📋 Processing list:", list.tagName, list);
        const items = list.querySelectorAll("li");
        items.forEach((item) => {
          // Get the text content, removing any nested HTML tags
          const text = item.textContent.trim();
          if (text) {
            listItems.push(text);
            // console.log("📝 List item:", text);
          }
        });
      });

      // console.log("✅ Total list items found:", listItems.length, listItems);

      // Send event to server if we found actual list items
      if (listItems.length > 0) {
        // Add a button to the page to allow the user to add a new list item
        const button = document.createElement("button");
        button.classList.add("menu-button");
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
    }
  },
};

export default listDetectionHook;

const listDetectionHook = {
  mounted() {
    this.checkForLists();
  },

  updated() {
    this.checkForLists();
  },

  checkForLists() {
    // This hook is attached directly to the content div containing the HTML
    // Check for both ordered and unordered lists
    const lists = this.el.querySelectorAll("ul, ol");

    if (lists.length > 0) {
      console.log("🎯 Lists detected!", lists.length, "list(s) found");

      // Extract all list items from all lists
      const listItems = [];

      lists.forEach((list) => {
        console.log("📋 Processing list:", list.tagName, list);
        const items = list.querySelectorAll("li");
        items.forEach((item) => {
          // Get the text content, removing any nested HTML tags
          const text = item.textContent.trim();
          if (text) {
            listItems.push(text);
            console.log("📝 List item:", text);
          }
        });
      });

      console.log("✅ Total list items found:", listItems.length, listItems);

      // Send event to server if we found actual list items
      if (listItems.length > 0) {
        // Add a button to the page to allow the user to add a new list item
        const button = document.createElement("button");
        button.textContent = "Branch all items";
        button.classList.add("list-branch-button");
        button.addEventListener("click", () => {
          this.pushEvent("branch_list", {
            items: listItems,
          });
        });
        this.el.prepend(button);
      }
    } else {
      console.log("❌ No lists found in content");
    }
  },
};

export default listDetectionHook;

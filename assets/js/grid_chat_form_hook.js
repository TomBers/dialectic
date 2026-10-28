const GridChatFormHook = {
  mounted() {
    this.textarea = this.el.querySelector("textarea");
    this.storageKey = this.el.dataset.storageKey;
    this.restoreDraft();
    this.handleInput = () => {
      try {
        if (this.textarea.value) {
          localStorage.setItem(`${this.storageKey}:draft`, this.textarea.value.slice(0, 500));
        } else {
          localStorage.removeItem(`${this.storageKey}:draft`);
        }
      } catch {
        window.dispatchEvent(new Event("grid-chat-storage-error"));
      }
    };
    this.textarea?.addEventListener("input", this.handleInput);

    this.handleKeyDown = (event) => {
      if (
        !this.textarea ||
        event.key !== "Enter" ||
        event.shiftKey ||
        event.altKey ||
        event.ctrlKey ||
        event.metaKey ||
        event.isComposing
      ) {
        return;
      }

      event.preventDefault();
      event.stopPropagation();
      event.stopImmediatePropagation();

      if (typeof this.el.requestSubmit === "function") {
        this.el.requestSubmit();
      } else {
        this.el.dispatchEvent(
          new Event("submit", { bubbles: true, cancelable: true }),
        );
      }
    };

    this.textarea?.addEventListener("keydown", this.handleKeyDown, true);

    this.handleEvent("clear_grid_chat_form", () => {
      const form = this.el;
      const textarea = this.textarea || form.querySelector("textarea");

      if (!form || !textarea) return;

      form.reset();
      textarea.value = "";
      textarea.dispatchEvent(new Event("input", { bubbles: true }));
      textarea.dispatchEvent(new Event("change", { bubbles: true }));
      textarea.focus();
    });
  },

  updated() {
    if (this.storageKey === this.el.dataset.storageKey) return;
    this.storageKey = this.el.dataset.storageKey;
    this.restoreDraft();
  },

  restoreDraft() {
    if (!this.textarea) return;
    try {
      this.textarea.value = (localStorage.getItem(`${this.storageKey}:draft`) || "").slice(0, 500);
      this.textarea.dispatchEvent(new Event("input", { bubbles: true }));
    } catch {
      window.dispatchEvent(new Event("grid-chat-storage-error"));
    }
  },

  destroyed() {
    this.textarea?.removeEventListener("keydown", this.handleKeyDown, true);
    this.textarea?.removeEventListener("input", this.handleInput);
  },
};

export default GridChatFormHook;

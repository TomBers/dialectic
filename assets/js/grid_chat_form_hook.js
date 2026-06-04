const GridChatFormHook = {
  mounted() {
    this.textarea = this.el.querySelector("textarea");

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

  destroyed() {
    this.textarea?.removeEventListener("keydown", this.handleKeyDown, true);
  },
};

export default GridChatFormHook;

// Tiny hook that scrolls its element to the top when the server pushes
// a "scroll_to_top" event.  Attach to any scrollable container that
// needs to reset when its content changes server-side.
const ScrollResetHook = {
  mounted() {
    this.handleEvent("scroll_to_top", () => {
      this.el.scrollTop = 0;
    });
  },
};

export default ScrollResetHook;

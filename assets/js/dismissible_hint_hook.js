const DISMISSED_VALUE = "dismissed";

const DismissibleHintHook = {
  mounted() {
    this.dismissedInSession = false;
    this.storageKey = this.el.dataset.dismissKey || "";
    this._onDismiss = (event) => {
      const dismissButton = event.target.closest("[data-dismiss-hint]");
      if (!dismissButton || !this.el.contains(dismissButton)) return;

      this.dismissedInSession = true;
      try {
        if (this.storageKey) {
          localStorage.setItem(this.storageKey, DISMISSED_VALUE);
        }
      } catch (_e) {}

      this.syncVisibility();
    };

    this.el.addEventListener("click", this._onDismiss);
    this.syncVisibility();
  },

  updated() {
    this.syncVisibility();
  },

  destroyed() {
    if (this._onDismiss) {
      this.el.removeEventListener("click", this._onDismiss);
      this._onDismiss = null;
    }
  },

  syncVisibility() {
    let dismissed = this.dismissedInSession;

    if (!dismissed && this.storageKey) {
      try {
        dismissed = localStorage.getItem(this.storageKey) === DISMISSED_VALUE;
      } catch (_e) {}
    }

    this.el.hidden = dismissed;
  },
};

export default DismissibleHintHook;

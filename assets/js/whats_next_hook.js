const WhatsNext = {
  mounted() {
    this.storageKey = "dialectic_whats_next_seen";

    // Check if user has already seen the onboarding in this session
    let hasSeen = "false";
    try {
      hasSeen = sessionStorage.getItem(this.storageKey);
    } catch (e) {
      console.warn("Session storage access failed", e);
    }

    if (hasSeen === "true") {
      this.el.classList.add("hidden");
    } else {
      this.el.classList.remove("hidden");
    }

    // Handle dismissal
    this.handleDismiss = () => this.dismiss();
    this.el.addEventListener("dismiss", this.handleDismiss);
  },

  destroyed() {
    this.el.removeEventListener("dismiss", this.handleDismiss);
  },

  dismiss() {
    this.el.classList.add("hidden");
    try {
      sessionStorage.setItem(this.storageKey, "true");
    } catch (e) {
      console.warn("Failed to save onboarding state", e);
    }
  },
};

export default WhatsNext;

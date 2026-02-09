const WhatsNext = {
  mounted() {
    this.storageKey = "dialectic_whats_next_seen";

    // Check if user has already seen the onboarding in this session
    const hasSeen = sessionStorage.getItem(this.storageKey);

    if (hasSeen === "true") {
      this.el.classList.add("hidden");
    } else {
      this.el.classList.remove("hidden");
    }

    // Handle dismissal
    this.el.addEventListener("dismiss", () => {
      this.dismiss();
    });

    // Handle "Try Related ideas" action
    this.el.addEventListener("trigger-related", () => {
      // Find the related ideas button in the toolbar
      // The button was updated to have data-action="related-ideas"
      const relatedBtn = document.querySelector('[data-action="related-ideas"]');

      if (relatedBtn) {
        relatedBtn.click();
        // Dismiss the panel after clicking
        this.dismiss();
      } else {
        console.warn("Related ideas button not found");
        // Still dismiss so the user isn't stuck if the button is missing
        this.dismiss();
      }
    });
  },

  dismiss() {
    this.el.classList.add("hidden");
    sessionStorage.setItem(this.storageKey, "true");
  }
};

export default WhatsNext;

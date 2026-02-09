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
      // Highlight relevant sections when onboarding is shown
      this.injectStyles();
      this.timeoutId = setTimeout(
        () => document.body.classList.add("onboarding-active"),
        100,
      );
    }

    // Handle dismissal
    this.el.addEventListener("dismiss", () => {
      this.dismiss();
    });

    // Handle "Try Related ideas" action
    this.el.addEventListener("trigger-related", () => {
      // Find the related ideas button in the toolbar
      // The button was updated to have data-action="related-ideas"
      const relatedBtn = document.querySelector(
        '[data-action="related-ideas"]',
      );

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

  destroyed() {
    clearTimeout(this.timeoutId);
    document.body.classList.remove("onboarding-active");
  },

  injectStyles() {
    if (document.getElementById("onboarding-styles")) return;

    const style = document.createElement("style");
    style.id = "onboarding-styles";
    style.textContent = `
      /* Common transition */
      body.onboarding-active [data-role="node-content"],
      body.onboarding-active [data-role="ask-form-container"],
      body.onboarding-active [data-role="action-toolbar"],
      body.onboarding-active [data-panel-toggle="right-panel"],
      body.onboarding-active [data-panel-toggle="graph-nav-drawer"],
      body.onboarding-active [data-panel-toggle="highlights-drawer"],
      body.onboarding-active [data-role="reader-view"],
      body.onboarding-active [data-role="star-node"],
      body.onboarding-active [data-role="translate-node"],
      body.onboarding-active [phx-click="open_share_modal"] {
        transition: box-shadow 1s ease-in-out;
      }

      /* 1. Content (Blue) */
      body.onboarding-active [data-role="node-content"] {
        box-shadow: 0 0 0 2px #fff, 0 0 0 4px #3b82f6;
      }

      /* 2. Ask / Comment (Emerald) */
      body.onboarding-active [data-role="ask-form-container"] {
        box-shadow: 0 0 0 2px #fff, 0 0 0 4px #10b981;
      }

      /* 3. Actions (Orange) */
      body.onboarding-active [data-role="action-toolbar"] {
        box-shadow: 0 0 0 2px #fff, 0 0 0 4px #f97316;
      }

      /* 4. Tools (Purple) */
      body.onboarding-active [data-role="reader-view"],
      body.onboarding-active [data-role="star-node"],
      body.onboarding-active [data-role="translate-node"] {
        box-shadow: 0 0 0 2px #fff, 0 0 0 4px #a855f7;
      }

      /* 5. Settings (Pink) */
      body.onboarding-active [data-panel-toggle="right-panel"],
      body.onboarding-active [data-panel-toggle="graph-nav-drawer"],
      body.onboarding-active [data-panel-toggle="highlights-drawer"] {
        box-shadow: 0 0 0 2px #fff, 0 0 0 4px #ec4899;
      }

      /* 6. Share (Indigo) */
      body.onboarding-active [phx-click="open_share_modal"] {
        box-shadow: 0 0 0 2px #fff, 0 0 0 4px #6366f1;
      }
    `;
    document.head.appendChild(style);
  },

  dismiss() {
    clearTimeout(this.timeoutId);
    this.el.classList.add("hidden");
    document.body.classList.remove("onboarding-active");
    try {
      sessionStorage.setItem(this.storageKey, "true");
    } catch (e) {
      console.warn("Failed to save onboarding state", e);
    }
  },
};

export default WhatsNext;

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
    this.handleDismiss = () => this.dismiss();
    this.el.addEventListener("dismiss", this.handleDismiss);
  },

  destroyed() {
    clearTimeout(this.timeoutId);
    document.body.classList.remove("onboarding-active");
    this.el.removeEventListener("dismiss", this.handleDismiss);

    const styleEl = document.getElementById("onboarding-styles");
    if (styleEl && styleEl.parentNode) {
      styleEl.parentNode.removeChild(styleEl);
    }
  },

  injectStyles() {
    if (document.getElementById("onboarding-styles")) return;

    const style = document.createElement("style");
    style.id = "onboarding-styles";
    style.textContent = `
      /* Common transition */
      body.onboarding-active [data-role="node-content"],
      body.onboarding-active [data-role="ask-form-container"],
      body.onboarding-active [data-role="action-buttons-group"],
      body.onboarding-active [data-role="settings-buttons-group"],
      body.onboarding-active [data-role="reading-tools-group"],
      body.onboarding-active [phx-click="open_share_modal"] {
        transition: box-shadow 1s ease-in-out;
      }

      /* 1. Content (Blue) */
      body.onboarding-active [data-role="node-content"] {
        box-shadow: 0 0 0 3px #fff, 0 0 0 7px #3b82f6;
      }

      /* 2. Ask / Comment (Emerald) */
      body.onboarding-active [data-role="ask-form-container"] {
        box-shadow: 0 0 0 3px #fff, 0 0 0 7px #10b981;
      }

      /* 3. Actions (Orange) */
      body.onboarding-active [data-role="action-buttons-group"] {
        box-shadow: 0 0 0 3px #fff, 0 0 0 7px #f97316;
        border-radius: 6px;
      }

      /* 4. Tools (Purple) */
      body.onboarding-active [data-role="reading-tools-group"] {
        box-shadow: 0 0 0 3px #fff, 0 0 0 7px #a855f7;
        border-radius: 6px;
      }

      /* 5. Settings (Pink) */
      body.onboarding-active [data-role="settings-buttons-group"] {
        box-shadow: 0 0 0 3px #fff, 0 0 0 7px #ec4899;
        border-radius: 8px;
      }

      /* 6. Share (Indigo) */
      body.onboarding-active [phx-click="open_share_modal"] {
        box-shadow: 0 0 0 3px #fff, 0 0 0 7px #6366f1;
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

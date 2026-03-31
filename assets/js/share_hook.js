/**
 * ShareHook – Smooth sharing UX for the share modal.
 *
 * Provides:
 * - Clipboard copy with inline toast feedback (no alert() calls)
 * - Native Web Share API integration for mobile devices
 * - Fallback copy for older browsers
 */

const ShareHook = {
  mounted() {
    this._bindCopyButtons();
    this._bindNativeShare();
  },

  updated() {
    this._bindCopyButtons();
    this._bindNativeShare();
  },

  _bindCopyButtons() {
    // Find all elements with data-share-copy inside this hook's element
    const buttons = this.el.querySelectorAll("[data-share-copy]");
    buttons.forEach((btn) => {
      // Avoid double-binding
      if (btn._shareBound) return;
      btn._shareBound = true;

      btn.addEventListener("click", (e) => {
        e.preventDefault();
        const text = btn.getAttribute("data-share-copy");
        const label = btn.getAttribute("data-share-toast") || "Copied to clipboard!";
        this._copyToClipboard(text, label, btn);
      });
    });
  },

  _bindNativeShare() {
    const btn = this.el.querySelector("[data-native-share]");
    if (!btn) return;
    if (btn._shareBound) return;
    btn._shareBound = true;

    // Only show the native share button if the API is available
    if (navigator.share) {
      btn.classList.remove("hidden");
      btn.addEventListener("click", (e) => {
        e.preventDefault();
        const title = btn.getAttribute("data-share-title") || "";
        const text = btn.getAttribute("data-share-text") || "";
        const url = btn.getAttribute("data-share-url") || "";

        navigator
          .share({ title, text, url })
          .catch(() => {
            // User cancelled or error – silently ignore
          });
      });
    } else {
      // Hide the button on desktop browsers without Web Share API
      btn.classList.add("hidden");
    }
  },

  /**
   * Copy text to clipboard with visual feedback on the triggering button.
   */
  _copyToClipboard(text, toastMessage, triggerEl) {
    const doCopy = (copyText) => {
      this._showToast(toastMessage);
      this._showButtonFeedback(triggerEl);
    };

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard
        .writeText(text)
        .then(() => doCopy(text))
        .catch(() => {
          this._fallbackCopy(text);
          doCopy(text);
        });
    } else {
      this._fallbackCopy(text);
      doCopy(text);
    }
  },

  /**
   * Briefly swap the button content to show a checkmark, then restore.
   */
  _showButtonFeedback(btn) {
    if (!btn) return;
    const icon = btn.querySelector("[data-copy-icon]");
    const check = btn.querySelector("[data-copy-check]");

    if (icon && check) {
      icon.classList.add("hidden");
      check.classList.remove("hidden");
      setTimeout(() => {
        icon.classList.remove("hidden");
        check.classList.add("hidden");
      }, 2000);
    }
  },

  /**
   * Show a brief toast notification near the top of the viewport.
   */
  _showToast(message) {
    // Remove any existing share toasts first
    const existing = document.getElementById("share-toast");
    if (existing) existing.remove();

    const toast = document.createElement("div");
    toast.id = "share-toast";
    toast.textContent = message;
    Object.assign(toast.style, {
      position: "fixed",
      top: "56px",
      left: "50%",
      transform: "translateX(-50%) translateY(-8px)",
      background: "#1f2937",
      color: "#fff",
      padding: "8px 20px",
      borderRadius: "8px",
      fontSize: "13px",
      fontWeight: "500",
      zIndex: "10001",
      opacity: "0",
      transition: "opacity 0.2s ease, transform 0.2s ease",
      pointerEvents: "none",
      boxShadow: "0 4px 12px rgba(0,0,0,0.15)",
      whiteSpace: "nowrap",
    });
    document.body.appendChild(toast);

    // Trigger entrance animation on next frame
    requestAnimationFrame(() => {
      toast.style.opacity = "1";
      toast.style.transform = "translateX(-50%) translateY(0)";
    });

    // Fade out and remove
    setTimeout(() => {
      toast.style.opacity = "0";
      toast.style.transform = "translateX(-50%) translateY(-8px)";
      setTimeout(() => toast.remove(), 200);
    }, 2200);
  },

  /**
   * Fallback copy for browsers without navigator.clipboard support.
   */
  _fallbackCopy(text) {
    const ta = document.createElement("textarea");
    ta.value = text;
    ta.style.position = "fixed";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.select();
    try {
      document.execCommand("copy");
    } catch (_e) {
      /* best-effort */
    }
    document.body.removeChild(ta);
  },
};

export default ShareHook;

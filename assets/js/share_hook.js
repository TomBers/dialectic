/**
 * ShareHook – Smooth sharing UX for the share modal.
 *
 * Provides:
 * - Clipboard copy with inline toast feedback (no alert() calls)
 * - Native Web Share API integration for mobile devices
 * - Fallback copy for older browsers
 *
 * Toast and clipboard logic is delegated to the shared toast utility
 * (assets/js/toast.js) to avoid styling/behavior drift with graph_hook.
 */

import { showToast, copyToClipboard } from "./toast.js";

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
        const label =
          btn.getAttribute("data-share-toast") || "Copied to clipboard!";
        this._copyAndNotify(text, label, btn);
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

        navigator.share({ title, text, url }).catch(() => {
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
  _copyAndNotify(text, toastMessage, triggerEl) {
    copyToClipboard(text).then(() => {
      showToast(toastMessage, { id: "share-toast" });
      this._showButtonFeedback(triggerEl);
    });
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
};

export default ShareHook;

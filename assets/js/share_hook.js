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
    this._resetLinkFeedback();
    this._bindCopyButtons();
    this._bindNativeShare();
    this._bindLinkSelection();
  },

  updated() {
    this._resetLinkFeedback();
    this._bindCopyButtons();
    this._bindNativeShare();
    this._bindLinkSelection();
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

  _resetLinkFeedback() {
    const input = this.el.querySelector("[data-share-link-input]");
    const url = this.el.querySelector("[data-share-copy]")?.dataset.shareCopy;
    if (input && url) input.value = url;
    if (url === this._lastShareUrl) return;
    this._lastShareUrl = url;
    const status = this.el.querySelector("#share-feedback");
    if (status) status.textContent = "";
    this.el.querySelectorAll("[data-share-copy]").forEach(btn => this._resetButtonFeedback(btn));
  },

  _bindNativeShare() {
    const btn = this.el.querySelector("[data-native-share]");
    if (!btn) return;
    const container = this.el.querySelector("[data-native-share-container]");
    const data = {
      title: btn.dataset.shareTitle || "",
      text: btn.dataset.shareText || "",
      url: btn.dataset.shareUrl || "",
    };
    let available = typeof navigator.share === "function";
    try {
      if (available && typeof navigator.canShare === "function") {
        available = navigator.canShare(data);
      }
    } catch {
      available = false;
    }
    container.hidden = !available;
    if (btn._shareBound) return;
    btn._shareBound = true;

    btn.addEventListener("click", async (event) => {
      event.preventDefault();
      btn.disabled = true;
      try {
        await navigator.share({
          title: btn.dataset.shareTitle || "",
          text: btn.dataset.shareText || "",
          url: btn.dataset.shareUrl || "",
        });
      } catch (error) {
        if (error.name !== "AbortError") {
          this._notify("Device sharing is unavailable. Copy the link or choose an app below.", true);
        }
      } finally {
        btn.disabled = false;
      }
    });
  },

  _bindLinkSelection() {
    const input = this.el.querySelector("[data-share-link-input]");
    if (!input || input._shareBound) return;
    input._shareBound = true;
    input.addEventListener("click", () => input.select());
  },

  /**
   * Copy text to clipboard with visual feedback on the triggering button.
   */
  _copyAndNotify(text, toastMessage, triggerEl) {
    return copyToClipboard(text).then((copied) => {
      if (copied === false) throw new Error("Copy unavailable");
      if (triggerEl?.dataset.shareCopy !== text) {
        this._notify("The link changed. Copy again to share the current link.", true);
        return;
      }
      this._notify(toastMessage);
      this._showButtonFeedback(triggerEl);
    }).catch(() => {
      this._resetButtonFeedback(triggerEl);
      const input = this.el.querySelector("[data-share-link-input]");
      input?.focus();
      input?.select();
      this._notify("Could not copy automatically. Select and copy the link above.", true);
    });
  },

  _notify(message, error = false) {
    const status = this.el.querySelector("#share-feedback");
    if (status) {
      status.dataset.state = error ? "error" : "success";
      status.textContent = message;
    } else {
      showToast(message, { id: "share-toast", zIndex: 10040 });
    }
  },

  /**
   * Briefly swap the button content to show a checkmark, then restore.
   */
  _showButtonFeedback(btn) {
    if (!btn) return;
    const icon = btn.querySelector("[data-copy-icon]");
    const check = btn.querySelector("[data-copy-check]");
    const label = btn.querySelector("[data-copy-label]");

    if (icon && check) {
      clearTimeout(btn._shareFeedbackTimeout);
      if (label) label.textContent = "Copied";
      icon.classList.add("hidden");
      check.classList.remove("hidden");
      btn._shareFeedbackTimeout = setTimeout(() => this._resetButtonFeedback(btn), 2000);
    }
  },

  _resetButtonFeedback(btn) {
    if (!btn) return;
    clearTimeout(btn._shareFeedbackTimeout);
    btn.querySelector("[data-copy-icon]")?.classList.remove("hidden");
    btn.querySelector("[data-copy-check]")?.classList.add("hidden");
    const label = btn.querySelector("[data-copy-label]");
    if (label) label.textContent = "Copy link";
  },
};

export default ShareHook;

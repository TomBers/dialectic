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
    this._bindImageDownloads();
    this._bindGridDownloads();
  },

  updated() {
    this._bindCopyButtons();
    this._bindNativeShare();
    this._bindImageDownloads();
    this._bindGridDownloads();
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

  _bindImageDownloads() {
    const buttons = this.el.querySelectorAll("[data-download-svg-png]");
    buttons.forEach((btn) => {
      if (btn._shareDownloadBound) return;
      btn._shareDownloadBound = true;

      btn.addEventListener("click", async (e) => {
        e.preventDefault();
        const url = btn.getAttribute("data-download-svg-png");
        const filename =
          btn.getAttribute("data-download-filename") ||
          "rationalgrid-image.png";
        if (!url) return;

        btn.disabled = true;
        try {
          await this._downloadSvgAsPng(url, filename);
        } catch (_e) {
          showToast("Could not download image. Please try again.", {
            id: "share-toast",
          });
        } finally {
          btn.disabled = false;
        }
      });
    });
  },

  _bindGridDownloads() {
    const buttons = this.el.querySelectorAll("[data-download-grid-png]");
    buttons.forEach((btn) => {
      if (btn._shareGridDownloadBound) return;
      btn._shareGridDownloadBound = true;

      btn.addEventListener("click", (e) => {
        e.preventDefault();
        window.dispatchEvent(
          new CustomEvent("download-graph-png", {
            detail: {
              filename: btn.getAttribute("data-download-filename") || "",
            },
          }),
        );
      });
    });
  },

  async _downloadSvgAsPng(url, filename) {
    const response = await fetch(url, { credentials: "same-origin" });
    if (!response.ok) throw new Error("Could not fetch SVG");

    const svg = await response.text();
    const svgUrl = URL.createObjectURL(
      new Blob([svg], { type: "image/svg+xml" }),
    );

    try {
      const image = await this._loadImage(svgUrl);
      const canvas = document.createElement("canvas");
      canvas.width = image.naturalWidth || 1200;
      canvas.height = image.naturalHeight || 630;

      const ctx = canvas.getContext("2d");
      ctx.fillStyle = "#ffffff";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(image, 0, 0, canvas.width, canvas.height);

      const blob = await new Promise((resolve, reject) => {
        canvas.toBlob((result) => {
          if (result) resolve(result);
          else reject(new Error("Could not render PNG"));
        }, "image/png");
      });

      this._downloadBlob(blob, filename);
    } finally {
      URL.revokeObjectURL(svgUrl);
    }
  },

  _loadImage(src) {
    return new Promise((resolve, reject) => {
      const image = new Image();
      image.onload = () => resolve(image);
      image.onerror = reject;
      image.src = src;
    });
  },

  _downloadBlob(blob, filename) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
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

import { showToast, copyToClipboard } from "./toast.js";

const ContentDraftsHook = {
  mounted() {
    this._onClick = async (event) => {
      const downloadButton = event.target.closest("[data-download-svg-png]");
      if (downloadButton && this.el.contains(downloadButton)) {
        event.preventDefault();
        await this._downloadSvgButton(downloadButton);
        return;
      }

      const copyButton = event.target.closest(
        "[data-copy-target], [data-copy-text]",
      );
      if (!copyButton || !this.el.contains(copyButton)) return;

      event.preventDefault();
      const text = this._copyText(copyButton);

      copyToClipboard(text).then(() => {
        showToast("Copied to clipboard.", { id: "content-draft-toast" });
      });
    };

    this.el.addEventListener("click", this._onClick);
  },

  destroyed() {
    if (this._onClick) {
      this.el.removeEventListener("click", this._onClick);
    }
  },

  _copyText(button) {
    const directText = button.getAttribute("data-copy-text");
    if (directText !== null) return directText;

    const selector = button.getAttribute("data-copy-target");
    const target = selector ? document.querySelector(selector) : null;
    return target ? target.value || target.textContent || "" : "";
  },

  async _downloadSvgButton(button) {
    const url = button.getAttribute("data-download-svg-png");
    const filename =
      button.getAttribute("data-download-filename") ||
      "rationalgrid-share-card.png";
    if (!url) return;

    button.disabled = true;
    try {
      await this._downloadSvgAsPng(url, filename);
      showToast("Image downloaded.", { id: "content-draft-toast" });
    } catch (_e) {
      showToast("Could not download image. Please try again.", {
        id: "content-draft-toast",
      });
    } finally {
      button.disabled = false;
    }
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
    const link = document.createElement("a");
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  },
};

export default ContentDraftsHook;

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
    this._renderShareCards();
    this._bindCopyButtons();
    this._bindNativeShare();
    this._bindImageDownloads();
  },

  updated() {
    this._renderShareCards();
    this._bindCopyButtons();
    this._bindNativeShare();
    this._bindImageDownloads();
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
    const buttons = this.el.querySelectorAll("[data-download-share-card]");
    buttons.forEach((btn) => {
      if (btn._shareDownloadBound) return;
      btn._shareDownloadBound = true;

      btn.addEventListener("click", async (e) => {
        e.preventDefault();
        const canvasId = btn.getAttribute("data-download-share-card");
        const filename =
          btn.getAttribute("data-download-filename") ||
          "rationalgrid-image.png";
        const canvas = canvasId ? document.getElementById(canvasId) : null;
        if (!canvas) return;

        btn.disabled = true;
        try {
          const blob = await canvasToPng(canvas);
          this._downloadBlob(blob, filename);
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

  _renderShareCards() {
    this.el.querySelectorAll("[data-share-card-canvas]").forEach((canvas) => {
      renderShareCard(canvas, {
        orientation: canvas.dataset.orientation,
        text: canvas.dataset.cardText || "",
        gridTitle: canvas.dataset.cardGridTitle || "",
        source: canvas.dataset.cardSource || "",
        faviconSrc: canvas.dataset.faviconSrc || "",
      });
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

export function canvasToPng(canvas) {
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (blob) resolve(blob);
      else reject(new Error("Could not render PNG"));
    }, "image/png");
  });
}

export function fitCanvasText(ctx, text, maxWidth, maxHeight, options = {}) {
  const maxFontSize = options.maxFontSize || 88;
  const minFontSize = options.minFontSize || 34;
  const family = options.family || "Georgia, 'Times New Roman', serif";

  for (let fontSize = maxFontSize; fontSize >= minFontSize; fontSize -= 2) {
    ctx.font = `600 ${fontSize}px ${family}`;
    const lines = wrapCanvasText(ctx, text, maxWidth);
    const lineHeight = Math.round(fontSize * 1.14);

    if (lines.length * lineHeight <= maxHeight) {
      return { fontSize, lineHeight, lines };
    }
  }

  const fontSize = minFontSize;
  const lineHeight = Math.round(fontSize * 1.14);
  const maxLines = Math.max(1, Math.floor(maxHeight / lineHeight));
  ctx.font = `600 ${fontSize}px ${family}`;
  const lines = wrapCanvasText(ctx, text, maxWidth);

  if (lines.length > maxLines) {
    const visible = lines.slice(0, maxLines);
    visible[maxLines - 1] = ellipsizeCanvasLine(
      ctx,
      lines.slice(maxLines - 1).join(" "),
      maxWidth,
    );
    return { fontSize, lineHeight, lines: visible };
  }

  return { fontSize, lineHeight, lines };
}

export function wrapCanvasText(ctx, text, maxWidth) {
  const words = String(text).trim().split(/\s+/).filter(Boolean);
  const lines = [];

  words.forEach((word) => {
    if (ctx.measureText(word).width > maxWidth) {
      const pieces = splitCanvasWord(ctx, word, maxWidth);
      pieces.forEach((piece) => appendCanvasWord(ctx, lines, piece, maxWidth));
    } else {
      appendCanvasWord(ctx, lines, word, maxWidth);
    }
  });

  return lines.length ? balanceCanvasLines(ctx, lines, maxWidth) : [""];
}

export function balanceCanvasLines(ctx, lines, maxWidth) {
  const balanced = [...lines];

  for (let index = balanced.length - 1; index > 0; index -= 1) {
    let previousWords = balanced[index - 1].split(" ");
    let current = balanced[index];

    while (previousWords.length > 1) {
      const movedWord = previousWords.at(-1);
      const nextPrevious = previousWords.slice(0, -1).join(" ");
      const nextCurrent = `${movedWord} ${current}`;

      if (ctx.measureText(nextCurrent).width > maxWidth) break;

      const oldDifference = Math.abs(
        ctx.measureText(balanced[index - 1]).width - ctx.measureText(current).width,
      );
      const newDifference = Math.abs(
        ctx.measureText(nextPrevious).width - ctx.measureText(nextCurrent).width,
      );

      if (newDifference >= oldDifference) break;

      balanced[index - 1] = nextPrevious;
      balanced[index] = nextCurrent;
      previousWords = nextPrevious.split(" ");
      current = nextCurrent;
    }
  }

  return balanced;
}

function appendCanvasWord(ctx, lines, word, maxWidth) {
  const current = lines[lines.length - 1];
  const candidate = current ? `${current} ${word}` : word;

  if (!current || ctx.measureText(candidate).width <= maxWidth) {
    if (current) lines[lines.length - 1] = candidate;
    else lines.push(word);
  } else {
    lines.push(word);
  }
}

function splitCanvasWord(ctx, word, maxWidth) {
  const pieces = [];
  let piece = "";

  Array.from(word).forEach((character) => {
    const candidate = piece + character;
    if (piece && ctx.measureText(candidate).width > maxWidth) {
      pieces.push(piece);
      piece = character;
    } else {
      piece = candidate;
    }
  });

  if (piece) pieces.push(piece);
  return pieces;
}

function ellipsizeCanvasLine(ctx, text, maxWidth) {
  const ellipsis = "…";
  const characters = Array.from(text.trim());

  while (characters.length && ctx.measureText(characters.join("") + ellipsis).width > maxWidth) {
    characters.pop();
  }

  return characters.join("").trimEnd() + ellipsis;
}

const shareCardRenderTokens = new WeakMap();

export function renderShareCard(canvas, card) {
  const renderToken = Symbol("share-card-render");
  shareCardRenderTokens.set(canvas, renderToken);

  const portrait = card.orientation === "portrait";
  const width = portrait ? 1080 : 1200;
  const height = portrait ? 1350 : 630;
  canvas.width = width;
  canvas.height = height;

  const ctx = canvas.getContext("2d");
  drawShareCard(ctx, width, height, card);

  if (card.faviconSrc) {
    const favicon = new Image();
    favicon.onload = () => {
      if (shareCardRenderTokens.get(canvas) === renderToken) {
        drawShareCard(ctx, width, height, card, favicon);
      }
    };
    favicon.src = card.faviconSrc;
  }
}

function drawShareCard(ctx, width, height, card, favicon = null) {
  const scale = width / 1200;
  const padding = 58 * scale;
  const contentInset = 104 * scale;
  const innerWidth = width - contentInset * 2;
  const headerBottom = 136 * scale;
  const footerHeight = card.source
    ? (card.orientation === "portrait" ? 230 : 180) * scale
    : 76 * scale;
  const textTop = headerBottom + 34 * scale;
  const textBottom = height - footerHeight;
  const textHeight = textBottom - textTop;

  ctx.textAlign = "left";
  ctx.textBaseline = "alphabetic";

  const background = ctx.createLinearGradient(0, 0, width, height);
  background.addColorStop(0, "#120f16");
  background.addColorStop(0.5, "#21132a");
  background.addColorStop(1, "#08231f");
  ctx.fillStyle = background;
  ctx.fillRect(0, 0, width, height);

  const amber = ctx.createRadialGradient(0, 0, 0, 0, 0, width * 0.72);
  amber.addColorStop(0, "rgba(245, 158, 11, 0.38)");
  amber.addColorStop(1, "rgba(245, 158, 11, 0)");
  ctx.fillStyle = amber;
  ctx.fillRect(0, 0, width, height);

  const teal = ctx.createRadialGradient(width, 0, 0, width, 0, width * 0.72);
  teal.addColorStop(0, "rgba(20, 184, 166, 0.32)");
  teal.addColorStop(1, "rgba(20, 184, 166, 0)");
  ctx.fillStyle = teal;
  ctx.fillRect(0, 0, width, height);

  roundedRect(ctx, padding, 34 * scale, width - padding * 2, height - 68 * scale, 38 * scale);
  ctx.fillStyle = "rgba(11, 16, 23, 0.88)";
  ctx.fill();
  ctx.strokeStyle = "rgba(255, 255, 255, 0.14)";
  ctx.lineWidth = Math.max(1, scale);
  ctx.stroke();

  ctx.fillStyle = "rgba(248, 250, 252, 0.8)";
  ctx.font = `700 ${15 * scale}px Arial, Helvetica, sans-serif`;
  const brandLabel = "RationalGrid.ai";
  const faviconSize = 26 * scale;
  const brandGap = 10 * scale;
  const brandWidth = faviconSize + brandGap + ctx.measureText(brandLabel).width;
  const brandX = (width - brandWidth) / 2;

  if (favicon) {
    ctx.drawImage(favicon, brandX, 76 * scale, faviconSize, faviconSize);
  } else {
    roundedRect(ctx, brandX, 76 * scale, faviconSize, faviconSize, 6 * scale);
    ctx.fillStyle = "rgba(245, 158, 11, 0.72)";
    ctx.fill();
    ctx.fillStyle = "rgba(248, 250, 252, 0.8)";
  }

  ctx.fillText(brandLabel, brandX + faviconSize + brandGap, 95 * scale);

  ctx.strokeStyle = "rgba(255, 255, 255, 0.14)";
  ctx.beginPath();
  ctx.moveTo(contentInset, headerBottom);
  ctx.lineTo(width - contentInset, headerBottom);
  ctx.stroke();

  const layout = fitCanvasText(ctx, card.text, innerWidth, textHeight, {
    maxFontSize: (card.orientation === "portrait" ? 100 : 82) * scale,
    minFontSize: 32 * scale,
  });
  const blockHeight = layout.lines.length * layout.lineHeight;
  let y = textTop + Math.max(0, (textHeight - blockHeight) / 2) + layout.fontSize;

  ctx.fillStyle = "#fff7ed";
  ctx.font = `600 ${layout.fontSize}px Georgia, 'Times New Roman', serif`;
  ctx.textAlign = "center";
  layout.lines.forEach((line) => {
    ctx.fillText(line, width / 2, y);
    y += layout.lineHeight;
  });

  const footerTop = height - footerHeight;
  const accentWidth = 168 * scale;
  const accentX = (width - accentWidth) / 2;
  const accent = ctx.createLinearGradient(accentX, 0, accentX + accentWidth, 0);
  accent.addColorStop(0, "#f59e0b");
  accent.addColorStop(0.5, "#fef3c7");
  accent.addColorStop(1, "#2dd4bf");
  ctx.fillStyle = accent;
  roundedRect(
    ctx,
    accentX,
    footerTop + 14 * scale,
    accentWidth,
    5 * scale,
    3 * scale,
  );
  ctx.fill();

  if (card.source) {
    const gridTitleTop = footerTop + 34 * scale;
    const gridTitleHeight = (card.orientation === "portrait" ? 72 : 48) * scale;
    const gridTitleLayout = fitCanvasText(
      ctx,
      card.gridTitle,
      innerWidth,
      gridTitleHeight,
      {
        maxFontSize: 13 * scale,
        minFontSize: 9 * scale,
        family: "Arial, Helvetica, sans-serif",
      },
    );
    let gridTitleY = gridTitleTop + gridTitleLayout.fontSize;

    ctx.fillStyle = "rgba(245, 158, 11, 0.88)";
    ctx.font = `600 ${gridTitleLayout.fontSize}px Arial, Helvetica, sans-serif`;
    gridTitleLayout.lines.forEach((line) => {
      ctx.fillText(line, width / 2, gridTitleY);
      gridTitleY += gridTitleLayout.lineHeight;
    });

    const sourceTop = gridTitleTop + gridTitleHeight + 8 * scale;
    const sourceHeight = height - 24 * scale - sourceTop;
    const sourceLayout = fitCanvasText(ctx, card.source, innerWidth, sourceHeight, {
      maxFontSize: 19 * scale,
      minFontSize: 10 * scale,
      family: "Arial, Helvetica, sans-serif",
    });
    const sourceBlockHeight = sourceLayout.lines.length * sourceLayout.lineHeight;
    let sourceY =
      sourceTop + Math.max(0, (sourceHeight - sourceBlockHeight) / 2) + sourceLayout.fontSize;

    ctx.fillStyle = "rgba(248, 250, 252, 0.92)";
    ctx.font = `600 ${sourceLayout.fontSize}px Arial, Helvetica, sans-serif`;
    sourceLayout.lines.forEach((line) => {
      ctx.fillText(line, width / 2, sourceY);
      sourceY += sourceLayout.lineHeight;
    });
  }
}

function roundedRect(ctx, x, y, width, height, radius) {
  ctx.beginPath();
  ctx.roundRect(x, y, width, height, radius);
}

export default ShareHook;

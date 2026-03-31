/**
 * Shared toast notification and clipboard utilities.
 *
 * Extracted from graph_hook._showCopiedToast() and share_hook._showToast()
 * to avoid styling/behavior drift and reduce maintenance.
 */

/**
 * Show a brief toast notification near the top of the viewport.
 *
 * @param {string} message  – The text to display.
 * @param {object} [opts]   – Optional overrides.
 * @param {string} [opts.id]       – DOM id for the toast (prevents duplicates). Default: "app-toast".
 * @param {number} [opts.duration] – How long the toast stays visible in ms. Default: 2200.
 * @param {number} [opts.zIndex]   – z-index for the toast element. Default: 10001.
 */
export function showToast(message, opts = {}) {
  const {
    id = "app-toast",
    duration = 2200,
    zIndex = 10001,
  } = opts;

  // Remove any existing toast with the same id first
  const existing = document.getElementById(id);
  if (existing) existing.remove();

  const toast = document.createElement("div");
  toast.id = id;
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
    zIndex: String(zIndex),
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
  }, duration);
}

/**
 * Fallback copy for browsers / contexts where navigator.clipboard is unavailable.
 *
 * @param {string} text – The text to copy.
 */
export function fallbackCopy(text) {
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
}

/**
 * Copy text to the clipboard, using the modern API with a fallback.
 * Returns a Promise that resolves when the copy succeeds (or the
 * fallback has been attempted).
 *
 * @param {string} text – The text to copy.
 * @returns {Promise<void>}
 */
export function copyToClipboard(text) {
  if (navigator.clipboard && navigator.clipboard.writeText) {
    return navigator.clipboard.writeText(text).catch(() => {
      fallbackCopy(text);
    });
  }
  fallbackCopy(text);
  return Promise.resolve();
}

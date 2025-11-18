/**
 * Shared utilities for extracting and formatting a title from Markdown-like content.
 *
 * Goals:
 * - Keep title extraction consistent across the Markdown hook and graph label rendering.
 * - Strip leading Markdown heading markers (e.g. "## ").
 * - Strip an optional "Title:" prefix (case-insensitive).
 * - Remove common emphasis markers that shouldn't appear in titles (e.g. "**").
 * - Optionally truncate and/or add zero-width break opportunities for better wrapping.
 *
 * Usage:
 *   import { extractTitle } from "./title_utils.js";
 *
 *   const title = extractTitle(md, { truncate: 80, addEllipsis: true, addBreaks: true });
 *
 * Options:
 *   - truncate: number (default: 0)        -> if > 0, limit title length to this many chars
 *   - addEllipsis: boolean (default: false)-> if true and truncated, appends "…"
 *   - addBreaks: boolean (default: false)  -> insert zero-width space after '/', '-', '–', '—'
 */

export function extractTitle(md, opts = {}) {
  const { truncate = 0, addEllipsis = false, addBreaks = false } = opts;

  // Normalize input and take only the first line
  const norm = String(md ?? "")
    .replace(/\r\n|\r/g, "\n")
    .replace(/^\s+/, "");
  const firstLine = (norm.split("\n")[0] || "").trimStart();

  // Strip leading heading markers (e.g., "#", "##", up to "######")
  // and an optional "Title:" prefix (case-insensitive).
  let title = firstLine
    .replace(/^\s*#{1,6}\s*/, "")
    .replace(/^\s*title\s*:?\s*/i, "")
    // Strip common bold markers
    .replace(/\*\*/g, "")
    .trim();

  // Truncate if requested
  if (Number.isFinite(truncate) && truncate > 0 && title.length > truncate) {
    title = title.slice(0, truncate) + (addEllipsis ? "…" : "");
  }

  // Optionally add break opportunities for better label wrapping
  if (addBreaks) {
    title = title.replace(/\//g, "/\u200B").replace(/([\-–—‑])/g, "$1\u200B");
  }

  return title;
}

/**
 * Convenience helper for hashing titles (useful for caching or id generation).
 * Fast non-cryptographic 32-bit hash.
 */
export function hashTitle(str) {
  const s = String(str ?? "");
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = (h << 5) - h + s.charCodeAt(i);
    h |= 0;
  }
  return String(h);
}

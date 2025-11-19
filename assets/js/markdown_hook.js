/* Markdown LiveView hook using marked + DOMPurify for client-side rendering
 *
 * Usage patterns in HEEx:
 *
 * 1) Inline via data attribute:
 *    <div phx-hook="Markdown" data-md={@markdown_string}></div>
 *
 * 2) Using a <template> to avoid curly interpolation issues in HEEx:
 *    <div phx-hook="Markdown">
 *      <template phx-no-curly-interpolation data-md>
 *        {@markdown_string}
 *      </template>
 *    </div>
 *
 * Optional:
 *    - Truncate input before rendering: data-truncate="200" (in characters)
 *    - Debounce rendering: data-debounce="50" (ms). Use 0 for requestAnimationFrame batching.

 *    - You can re-run rendering by updating the element (LiveView updated/replace)
 */

import { marked } from "marked";
import DOMPurify from "dompurify";
import { extractTitle, hashTitle as hashString } from "./title_utils.js";

// Configure marked defaults (tweak as needed)
marked.setOptions({
  gfm: true,
  breaks: true,
  headerIds: true,
  mangle: false, // keep emails readable; set true to obfuscate
});

/**
 * Enhances anchor tags for safer external navigation.
 * Ensures new-tab behavior and prevents reverse tabnabbing.
 */
function enhanceLinks(root) {
  const links = root.querySelectorAll("a[href]");
  links.forEach((a) => {
    // Preserve existing target/rel if already set
    if (!a.getAttribute("target")) {
      a.setAttribute("target", "_blank");
    }
    const currentRel = (a.getAttribute("rel") || "").split(/\s+/);
    const required = ["noopener", "noreferrer", "nofollow"];
    required.forEach((v) => {
      if (!currentRel.includes(v)) currentRel.push(v);
    });
    a.setAttribute("rel", currentRel.join(" ").trim());
  });
}

/**
 * Retrieves markdown source from:
 * - data-md attribute (highest priority)
 * - <template data-md> child content
 */
function readMarkdownSource(el) {
  const fromAttr = el.getAttribute("data-md");
  if (fromAttr != null) return fromAttr;

  const tpl = el.querySelector("template[data-md]");
  if (tpl) {
    // template.textContent preserves literal braces and newlines
    return tpl.textContent || "";
  }

  return "";
}

// hashing moved to title_utils.js (hashTitle aliased as hashString)
//

/**
 * Renders markdown into the element using marked -> DOMPurify.
 * Applies optional truncation (character count) before parsing.
 */
function renderMdInto(el) {
  let md = readMarkdownSource(el) || "";
  const debug = el.getAttribute("data-debug") === "true";

  // Title-only mode: render first line as plain text (no HTML), strip headings/Title: and bold markers
  if (el.getAttribute("data-title-only") === "true") {
    const tLen = parseInt(el.getAttribute("data-truncate") || "0", 10);
    const title = extractTitle(md, {
      truncate: Number.isNaN(tLen) ? 0 : tLen,
      addEllipsis: !Number.isNaN(tLen) && tLen > 0,
      addBreaks: false,
    });

    const tHash = hashString("TITLE|" + title);
    if (el.__markdownHash === tHash) {
      return;
    }

    // Plain text content prevents any HTML injection
    el.textContent = title;
    el.__markdownHash = tHash;
    el.dispatchEvent(new CustomEvent("markdown:rendered", { bubbles: true }));
    return;
  }

  // Body-only mode: drop first line, and optionally a second heading/title line
  if (el.getAttribute("data-body-only") === "true") {
    const norm = md.replace(/\r\n|\r/g, "\n");
    const parts = norm.split("\n");
    const rest = parts.slice(1).join("\n").replace(/^\n+/, "");
    const lines2 = rest.split("\n");
    if (lines2.length > 0) {
      const first2 = lines2[0];
      if (
        /^\s*#{1,6}\s+\S/.test(first2) ||
        /^\s*(title|Title)\s*:?\s*/.test(first2)
      ) {
        md = lines2.slice(1).join("\n");
      } else {
        md = rest;
      }
    } else {
      md = rest;
    }
  }

  const truncate = parseInt(el.getAttribute("data-truncate") || "0", 10);
  if (!Number.isNaN(truncate) && truncate > 0 && md.length > truncate) {
    md = md.slice(0, truncate) + "…";
  }

  // Use a per-element cache to avoid unnecessary DOM churn
  const currentHash = hashString(md);

  if (el.__markdownHash === currentHash) {
    if (debug)
      console.debug("[MarkdownHook] skip: unchanged hash", { id: el.id });
    return; // No change since last render
  }

  // Proceed to render full buffer immediately (no safety gating)

  // Markdown -> HTML -> sanitize
  const html = marked.parse(md);
  const safe = DOMPurify.sanitize(html);

  // Inject result
  if (debug)
    console.debug("[MarkdownHook] rendered", { id: el.id, hash: currentHash });
  el.innerHTML = safe;

  // Enhance anchors for safety/UX
  enhanceLinks(el);

  // Cache this render
  el.__markdownHash = currentHash;

  // Notify listeners that content has been rendered
  el.dispatchEvent(new CustomEvent("markdown:rendered", { bubbles: true }));
}

const Markdown = {
  scheduleRender(el) {
    const val = el.getAttribute("data-debounce");
    if (val == null) {
      // No debounce specified: render immediately
      renderMdInto(el);
      return;
    }

    const n = parseInt(val, 10);

    // rAF batching when debounce is explicitly 0
    if (n === 0) {
      if (el.__mdRafScheduled) return;
      el.__mdRafScheduled = true;
      requestAnimationFrame(() => {
        el.__mdRafScheduled = false;
        renderMdInto(el);
      });
      return;
    }

    // Positive debounce in ms
    if (!Number.isNaN(n) && n > 0) {
      if (el.__mdDebounceTimer) clearTimeout(el.__mdDebounceTimer);
      el.__mdDebounceTimer = setTimeout(() => {
        el.__mdDebounceTimer = null;
        renderMdInto(el);
      }, n);
      return;
    }

    // Fallback: invalid value -> immediate render
    renderMdInto(el);
  },

  mounted() {
    this.scheduleRender(this.el);
  },
  updated() {
    this.scheduleRender(this.el);
  },
  destroyed() {
    const el = this.el;
    if (el.__mdDebounceTimer) clearTimeout(el.__mdDebounceTimer);
    el.__mdDebounceTimer = null;
    el.__mdRafScheduled = false;
  },
};

export default Markdown;

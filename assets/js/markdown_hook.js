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
 *    - You can re-run rendering by updating the element (LiveView updated/replace)
 */

import { marked } from "marked";
import DOMPurify from "dompurify";

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

/**
 * Simple fast string hash for change detection (not cryptographic).
 */
function hashString(str) {
  let h = 0;
  for (let i = 0; i < str.length; i++) {
    h = (h << 5) - h + str.charCodeAt(i);
    h |= 0; // Convert to 32-bit int
  }
  return String(h);
}

/**
 * Renders markdown into the element using marked -> DOMPurify.
 * Applies optional truncation (character count) before parsing.
 */
function renderMdInto(el) {
  let md = readMarkdownSource(el) || "";

  const truncate = parseInt(el.getAttribute("data-truncate") || "0", 10);
  if (!Number.isNaN(truncate) && truncate > 0 && md.length > truncate) {
    md = md.slice(0, truncate) + "…";
  }

  // Use a per-element cache to avoid unnecessary DOM churn
  const currentHash = hashString(md);
  if (el.__markdownHash === currentHash) {
    return; // No change since last render
  }

  // Markdown -> HTML -> sanitize
  const html = marked.parse(md);
  const safe = DOMPurify.sanitize(html);

  // Inject result
  el.innerHTML = safe;

  // Enhance anchors for safety/UX
  enhanceLinks(el);

  // Cache this render
  el.__markdownHash = currentHash;

  // Notify listeners that content has been rendered
  el.dispatchEvent(new CustomEvent("markdown:rendered", { bubbles: true }));
}

const Markdown = {
  mounted() {
    renderMdInto(this.el);
  },
  updated() {
    renderMdInto(this.el);
  },
};

export default Markdown;

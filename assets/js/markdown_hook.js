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
import katex from "katex";
import { extractTitle, hashTitle as hashString } from "./title_utils.js";

const katexPlugin = {
  extensions: [
    {
      name: "katexBlock",
      level: "block",
      start(src) {
        return src.indexOf("$$");
      },
      tokenizer(src, _tokens) {
        // Block math $$...$$
        const blockMatch = /^\$\$([\s\S]+?)\$\$/.exec(src);
        if (blockMatch) {
          return {
            type: "katexBlock",
            raw: blockMatch[0],
            text: blockMatch[1].trim(),
            displayMode: true,
          };
        }
      },
      renderer(token) {
        return katex.renderToString(token.text, {
          displayMode: true,
          throwOnError: false,
        });
      },
    },
    {
      name: "katex",
      level: "inline",
      start(src) {
        return src.indexOf("$");
      },
      tokenizer(src, _tokens) {
        // Inline math $...$
        const inlineMatch = /^\$([^$\n]+?)\$/.exec(src);
        if (inlineMatch) {
          return {
            type: "katex",
            raw: inlineMatch[0],
            text: inlineMatch[1].trim(),
            displayMode: false,
          };
        }
      },
      renderer(token) {
        return katex.renderToString(token.text, {
          displayMode: false,
          throwOnError: false,
        });
      },
    },
  ],
};

// Configure DOMPurify to only allow styles on KaTeX elements
DOMPurify.addHook("uponSanitizeAttribute", (node, data) => {
  if (data.attrName === "style") {
    if (
      node.closest &&
      (node.closest(".katex") || node.closest(".katex-display"))
    ) {
      data.keepAttr = true;
    } else {
      data.keepAttr = false;
    }
  }
});

// Configure marked defaults (tweak as needed)
marked.use(katexPlugin);
marked.setOptions({
  gfm: true,
  breaks: true,
});

/**
 * Enhances anchor tags for safer external navigation.
 * Ensures new-tab behavior and prevents reverse tabnabbing.
 */
/**
 * Allowed URL protocols for links rendered from LLM markdown output.
 * Anything else (javascript:, data:, vbscript:, etc.) is stripped.
 */
const ALLOWED_PROTOCOLS = ["https:", "http:"];

function enhanceLinks(root) {
  const links = root.querySelectorAll("a[href]");
  links.forEach((a) => {
    const href = a.getAttribute("href") || "";

    // --- Protocol allowlist ---
    // Reject anything that isn't http(s). Relative URLs are also removed
    // because LLM-generated links should always be fully qualified.
    let url;
    try {
      url = new URL(href, window.location.origin);
    } catch {
      // Malformed URL — remove the link, keep the text
      a.replaceWith(document.createTextNode(a.textContent));
      return;
    }

    if (!ALLOWED_PROTOCOLS.includes(url.protocol)) {
      a.replaceWith(document.createTextNode(a.textContent));
      return;
    }

    // --- Safety attributes ---
    if (!a.getAttribute("target")) {
      a.setAttribute("target", "_blank");
    }
    const currentRel = (a.getAttribute("rel") || "").split(/\s+/);
    const required = ["noopener", "noreferrer", "nofollow"];
    required.forEach((v) => {
      if (!currentRel.includes(v)) currentRel.push(v);
    });
    a.setAttribute("rel", currentRel.join(" ").trim());

    // --- Visible domain indicator ---
    // Append the hostname in a small badge so users can see where the link
    // goes before clicking, guarding against misleading anchor text.
    const hostname = url.hostname;
    if (hostname && !a.querySelector(".link-domain")) {
      const badge = document.createElement("span");
      badge.className = "link-domain";
      badge.textContent = hostname;
      a.appendChild(badge);
    }
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

/**
 * Renders markdown into the element using marked -> DOMPurify.
 * Applies optional truncation (character count) before parsing.
 */
function renderMdInto(el) {
  let md = readMarkdownSource(el) || "";

  // Title-only mode: render first line as plain text (no HTML), strip headings/Title: and bold markers
  if (el.getAttribute("data-title-only") === "true") {
    const tLen = parseInt(el.getAttribute("data-truncate") || "0", 10);
    const title = extractTitle(md, {
      truncate: Number.isNaN(tLen) ? 0 : tLen,
      addEllipsis: !Number.isNaN(tLen) && tLen > 0,
      addBreaks: false,
    });

    const tHash = hashString("TITLE|" + title);
    if (el.__markdownHash === tHash && el.textContent.trim() !== "") {
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
  if (el.__markdownHash === currentHash && el.innerHTML.trim() !== "") {
    return; // No change since last render
  }

  // Markdown -> HTML -> sanitize
  const html = marked.parse(md);
  const safe = DOMPurify.sanitize(html, {
    USE_PROFILES: { html: true, mathMl: true },
  });

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

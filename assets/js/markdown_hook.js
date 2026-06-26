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

/** Allowed URL protocols for links rendered from LLM markdown output.
 * Anything else (javascript:, data:, vbscript:, etc.) is stripped.
 */
export const ALLOWED_PROTOCOLS = ["https:", "http:"];
/**
 * Enhances anchor tags for safer external navigation.
 * Ensures new-tab behavior and prevents reverse tabnabbing.
 */
export function enhanceLinks(root) {
  const links = root.querySelectorAll("a[href]");
  links.forEach((a) => {
    const href = a.getAttribute("href") || "";

    // --- Protocol allowlist ---
    // Reject anything that isn't http(s). Relative URLs are also removed
    // because LLM-generated links should always be fully qualified.
    //
    // Note: Protocol-relative URLs (starting with "//") are intentionally
    // allowed. The `new URL()` constructor resolves them to absolute URLs
    // using the current page's protocol (e.g. "//example.com/path" becomes
    // "https://example.com/path" when served over HTTPS). This is acceptable
    // for LLM-generated content since the resulting URL will always use the
    // same protocol as the host page and pass the allowlist check below.
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

function normalizedHeadingText(text) {
  return (text || "")
    .trim()
    .toLowerCase()
    .replace(/[-_]+/g, " ")
    .replace(/[^\w\s-]/g, "")
    .replace(/\s+/g, " ");
}

function normalizedQuestionText(text) {
  return (text || "").trim().toLowerCase().replace(/\s+/g, " ");
}

const FOLLOW_UP_HEADINGS = new Set([
  "follow up questions",
  "followup questions",
  "deepen your exploration",
  "questions to explore",
  "further questions",
  "explore further",
]);

function isFollowUpHeading(heading) {
  return FOLLOW_UP_HEADINGS.has(normalizedHeadingText(heading.textContent));
}

function questionTextFromListItem(item) {
  const clone = item.cloneNode(true);
  clone.querySelectorAll(".link-domain").forEach((badge) => badge.remove());

  const firstElement = clone.firstElementChild;

  if (
    firstElement &&
    firstElement.tagName === "STRONG" &&
    firstElement.textContent.trim().endsWith(":")
  ) {
    firstElement.remove();
  }

  return clone.textContent.trim().replace(/\s+/g, " ");
}

function followUpQuestionsFromList(list) {
  const items = Array.from(list.children).filter(
    (child) => child.tagName === "LI",
  );
  if (items.length !== 3) return [];

  const questions = items.map(questionTextFromListItem);
  if (questions.some((text) => !text.endsWith("?"))) return [];

  return questions;
}

function findFollowUpListAfterHeading(heading) {
  let current = heading.nextElementSibling;
  let skippedParagraphs = 0;

  while (current) {
    if (["OL", "UL"].includes(current.tagName)) return current;

    if (current.tagName === "P" && skippedParagraphs < 2) {
      skippedParagraphs += 1;
      current = current.nextElementSibling;
      continue;
    }

    return null;
  }

  return null;
}

function readExistingFollowUpQuestions(root) {
  const raw = root.getAttribute("data-existing-follow-up-questions") || "[]";

  try {
    const questions = JSON.parse(raw);
    if (!Array.isArray(questions)) return new Set();

    return new Set(
      questions
        .map((question) => normalizedQuestionText(question))
        .filter((question) => question !== ""),
    );
  } catch (_error) {
    return new Set();
  }
}

function buildFollowUpPanel(root, questions, askQuestion, existingQuestions) {
  const panel = document.createElement("div");
  panel.className = "not-prose mt-3 grid gap-2";
  panel.setAttribute("data-follow-up-question-panel", "true");

  questions.forEach((question, index) => {
    const alreadyAsked = existingQuestions.has(
      normalizedQuestionText(question),
    );
    const button = document.createElement("button");
    button.type = "button";
    button.id = `${root.id || "markdown"}-follow-up-${index + 1}`;
    button.className =
      "group flex w-full items-start gap-3 rounded-lg border border-slate-200 bg-white px-3 py-2.5 text-left text-sm font-medium leading-5 text-slate-800 shadow-sm transition hover:border-sky-300 hover:bg-sky-50 hover:text-slate-950 focus:outline-none focus:ring-2 focus:ring-sky-500 focus:ring-offset-2 disabled:cursor-wait disabled:opacity-70";
    if (alreadyAsked) {
      button.className =
        "group flex w-full items-start gap-3 rounded-lg border border-slate-200 bg-slate-50 px-3 py-2.5 text-left text-sm font-medium leading-5 text-slate-500 shadow-sm disabled:cursor-not-allowed disabled:opacity-80";
    }
    button.setAttribute("data-follow-up-question", question);
    button.setAttribute(
      "aria-label",
      alreadyAsked
        ? `Already asked follow-up question: ${question}`
        : `Ask follow-up question: ${question}`,
    );
    if (alreadyAsked) {
      button.disabled = true;
      button.setAttribute("data-follow-up-question-asked", "true");
    }

    const number = document.createElement("span");
    number.className =
      "mt-0.5 inline-flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-sky-100 text-[11px] font-semibold text-sky-700 group-hover:bg-sky-200";
    if (alreadyAsked) {
      number.className =
        "mt-0.5 inline-flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-slate-200 text-[11px] font-semibold text-slate-500";
    }
    number.textContent = String(index + 1);

    const text = document.createElement("span");
    text.className = "min-w-0 flex-1";
    text.textContent = question;

    button.append(number, text);

    if (alreadyAsked) {
      const status = document.createElement("span");
      status.className =
        "ml-auto shrink-0 rounded-full bg-slate-200 px-2 py-0.5 text-[11px] font-semibold text-slate-600";
      status.textContent = "Asked";
      button.appendChild(status);
    }

    button.addEventListener("click", () => {
      if (typeof askQuestion !== "function") return;
      if (button.disabled) return;

      button.disabled = true;
      askQuestion(question);
    });

    panel.appendChild(button);
  });

  return panel;
}

export function enhanceFollowUpQuestions(root, askQuestion) {
  const headings = root.querySelectorAll("h2, h3");
  const existingQuestions = readExistingFollowUpQuestions(root);

  headings.forEach((heading) => {
    if (!isFollowUpHeading(heading)) return;

    const list = findFollowUpListAfterHeading(heading);
    if (!list) return;
    if (list.dataset.followUpQuestionsEnhanced === "true") return;

    const questions = followUpQuestionsFromList(list);
    if (questions.length !== 3) return;

    const panel = buildFollowUpPanel(
      root,
      questions,
      askQuestion,
      existingQuestions,
    );
    list.dataset.followUpQuestionsEnhanced = "true";
    list.replaceWith(panel);
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
function renderMdInto(el, askQuestion) {
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
  const existingFollowUpQuestions =
    el.getAttribute("data-existing-follow-up-questions") || "[]";
  const enhanceFollowUpQuestionsEnabled =
    el.getAttribute("data-enhance-follow-up-questions") !== "false";
  const currentHash = hashString(
    md +
      "|FOLLOW_UPS|" +
      existingFollowUpQuestions +
      "|ENHANCE_FOLLOW_UPS|" +
      enhanceFollowUpQuestionsEnabled,
  );
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

  if (enhanceFollowUpQuestionsEnabled) {
    enhanceFollowUpQuestions(el, askQuestion);
  }

  // Cache this render
  el.__markdownHash = currentHash;

  // Notify listeners that content has been rendered
  el.dispatchEvent(new CustomEvent("markdown:rendered", { bubbles: true }));
}

const Markdown = {
  mounted() {
    renderMdInto(this.el, (question) => {
      this.pushEvent("reply-and-answer", { vertex: { content: question } });
    });
  },
  updated() {
    renderMdInto(this.el, (question) => {
      this.pushEvent("reply-and-answer", { vertex: { content: question } });
    });
  },
};

export default Markdown;

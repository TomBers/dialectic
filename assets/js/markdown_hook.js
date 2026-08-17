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

const GROUNDING_REDIRECT_HOSTS = new Set([
  "vertexaisearch.cloud.google.com",
]);

function enhanceSourceLink(link) {
  link.classList.add("markdown-source-link");

  try {
    const url = new URL(link.getAttribute("href"), window.location.origin);
    if (GROUNDING_REDIRECT_HOSTS.has(url.hostname)) {
      link.querySelector(".link-domain")?.remove();
    }
  } catch (_error) {
    // Invalid URLs are already handled by enhanceLinks.
  }
}

const TABLE_DELIMITER_ROW =
  /^\s*\|?\s*:?-{3,}:?\s*(?:\|\s*:?-{3,}:?\s*)+\|?\s*$/;

function normalizeTableFragmentMarkdown(markdown, cellSeparator) {
  const lines = (markdown || "").split(/\r?\n/);
  if (lines.some((line) => TABLE_DELIMITER_ROW.test(line))) return markdown;

  let tableFragmentFound = false;

  const normalized = lines.map((line) => {
    const trimmed = line.trim();

    if (trimmed === "|") {
      tableFragmentFound = true;
      return "";
    }

    if (!trimmed.startsWith("| ")) return line;

    tableFragmentFound = true;

    const cells = trimmed
      .slice(1)
      .replace(/\|\s*$/, "")
      .trim()
      .split(/\s+\|\s+/)
      .map((cell) => cell.trim())
      .filter((cell) => cell !== "");

    if (cells.length <= 1) return cells[0] || "";

    return `${cells[0]}${cellSeparator}${cells.slice(1).join(" — ")}`;
  });

  if (!tableFragmentFound) return markdown;

  return normalized.join("\n").replace(/\n{3,}/g, "\n\n").trim();
}

function normalizedSupportReferenceText(markdown) {
  const container = document.createElement("div");
  const normalized = normalizeTableFragmentMarkdown(markdown, " ");
  container.innerHTML = DOMPurify.sanitize(marked.parse(normalized), {
    USE_PROFILES: { html: true, mathMl: true },
  });

  return (container.textContent || "").replace(/\s+/g, " ").trim();
}

function readGroundingMetadata(root) {
  const raw = root.getAttribute("data-grounding");
  if (!raw) return null;

  try {
    const metadata = JSON.parse(raw);
    return metadata && typeof metadata === "object" ? metadata : null;
  } catch (_error) {
    return null;
  }
}

const PREFERRED_SOURCE_DOMAINS = [
  "doi.org",
  "jstor.org",
  "muse.jhu.edu",
  "plato.stanford.edu",
  "iep.utm.edu",
  "cambridge.org",
  "oup.com",
  "oxfordacademic.com",
  "springer.com",
  "wiley.com",
  "tandfonline.com",
  "sagepub.com",
  "sciencedirect.com",
  "semanticscholar.org",
  "researchgate.net",
];

const SUPPLEMENTARY_SOURCE_DOMAINS = [
  "reddit.com",
  "quora.com",
  "youtube.com",
  "medium.com",
  "scribd.com",
  "goodreads.com",
  "facebook.com",
  "instagram.com",
  "tiktok.com",
  "x.com",
];

function sourceDomain(title) {
  return (title || "")
    .trim()
    .toLowerCase()
    .replace(/^www\./, "")
    .split(/\s+/)[0];
}

function domainMatches(domain, candidate) {
  return domain === candidate || domain.endsWith(`.${candidate}`);
}

function sourcePriority(reference) {
  const domain = sourceDomain(reference.title);

  if (
    domain.endsWith(".edu") ||
    domain.includes(".edu.") ||
    domain.includes(".ac.") ||
    PREFERRED_SOURCE_DOMAINS.some((candidate) =>
      domainMatches(domain, candidate),
    )
  ) {
    return 0;
  }

  if (
    SUPPLEMENTARY_SOURCE_DOMAINS.some((candidate) =>
      domainMatches(domain, candidate),
    )
  ) {
    return 2;
  }

  return 1;
}

function groundingView(metadata) {
  const google = metadata?.google;
  if (!google || typeof google !== "object") return null;

  const chunks = Array.isArray(google.groundingChunks)
    ? google.groundingChunks
    : [];
  const supports = Array.isArray(google.groundingSupports)
    ? google.groundingSupports
    : [];
  const references = [];
  const referenceByUrl = new Map();
  const referenceByChunk = new Map();
  const referenceNumberByChunk = new Map();

  chunks.forEach((chunk, chunkIndex) => {
    const web = chunk?.web;
    if (!web || typeof web.uri !== "string" || web.uri.trim() === "") return;

    let reference = referenceByUrl.get(web.uri);
    if (!reference) {
      reference = {
        title:
          typeof web.title === "string" && web.title.trim() !== ""
            ? web.title.trim()
            : `Source ${references.length + 1}`,
        url: web.uri,
        supports: [],
      };
      references.push(reference);
      referenceByUrl.set(web.uri, reference);
    }

    referenceByChunk.set(chunkIndex, reference);
  });

  references.sort((left, right) => sourcePriority(left) - sourcePriority(right));

  referenceByChunk.forEach((reference, chunkIndex) => {
    referenceNumberByChunk.set(chunkIndex, references.indexOf(reference) + 1);
  });

  const citationGroups = [];
  supports.forEach((support) => {
    const text = support?.segment?.text;
    const chunkIndices = support?.groundingChunkIndices;
    if (typeof text !== "string" || !Array.isArray(chunkIndices)) return;

    const numbers = Array.from(
      new Set(
        chunkIndices
          .map((index) => referenceNumberByChunk.get(index))
          .filter((number) => Number.isInteger(number)),
      ),
    ).sort((left, right) => left - right);

    if (numbers.length === 0) return;
    citationGroups.push({ numbers, text });

    numbers.forEach((number) => {
      const reference = references[number - 1];
      if (reference && !reference.supports.includes(text)) {
        reference.supports.push(text);
      }
    });
  });

  return references.length === 0 ? null : { references, citationGroups };
}

function answerTextIndex(root, sourceHeading) {
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  const positions = [];
  let text = "";
  let pendingWhitespacePosition = null;
  let node = walker.nextNode();

  while (node) {
    if (sourceHeading.contains(node)) break;
    if (node.parentElement?.closest("[data-source-citation]")) {
      node = walker.nextNode();
      continue;
    }

    for (let offset = 0; offset < node.textContent.length; offset += 1) {
      const character = node.textContent[offset];
      const position = { node, offset: offset + 1 };

      if (/\s/.test(character)) {
        pendingWhitespacePosition = position;
      } else {
        if (pendingWhitespacePosition && text !== "" && !text.endsWith(" ")) {
          text += " ";
          positions.push(pendingWhitespacePosition);
        }
        text += character;
        positions.push(position);
        pendingWhitespacePosition = null;
      }
    }

    node = walker.nextNode();
  }

  return { text, positions };
}

function uniqueSupportMatch(text, supportText) {
  let candidate = supportText;

  for (let skippedWords = 0; skippedWords <= 12; skippedWords += 1) {
    const matchStart = text.indexOf(candidate);
    if (matchStart >= 0 && matchStart === text.lastIndexOf(candidate)) {
      return { matchStart, length: candidate.length };
    }

    const nextWord = candidate.indexOf(" ");
    if (nextWord < 0) break;
    candidate = candidate.slice(nextWord + 1);
    if (candidate.length < 64) break;
  }

  return null;
}

function insertSourceCitation(root, sourceHeading, support, references) {
  const supportText = normalizedSupportReferenceText(support.text);
  if (supportText.length < 32) return;

  const index = answerTextIndex(root, sourceHeading);
  const match = uniqueSupportMatch(index.text, supportText);
  if (!match) return;

  let matchEnd = match.matchStart + match.length - 1;
  while (
    matchEnd + 1 < index.text.length &&
    /[\p{L}\p{N}]/u.test(index.text[matchEnd + 1])
  ) {
    matchEnd += 1;
  }

  if (!/[.!?]/.test(index.text[matchEnd])) {
    const sentenceTail = index.text.slice(matchEnd + 1, matchEnd + 482);
    const sentenceEnd = sentenceTail.search(/[.!?](?=\s|$)/);
    if (sentenceEnd >= 0) {
      matchEnd += sentenceEnd;
    }
  }

  const endPosition = index.positions[matchEnd];
  if (!endPosition) return;

  const citation = document.createElement("sup");
  citation.className = "markdown-inline-citation";
  citation.dataset.sourceCitation = support.numbers.join(",");

  support.numbers.forEach((number) => {
    const reference = references[number - 1];
    if (!reference) return;

    const link = document.createElement("a");
    link.href = `#${reference.id}`;
    link.dataset.citationNumber = String(number);
    link.setAttribute("aria-label", `See source ${number}`);
    link.title = `See source ${number}`;
    citation.appendChild(link);
  });

  if (citation.children.length === 0) return;

  const range = document.createRange();
  range.setStart(endPosition.node, endPosition.offset);
  range.collapse(true);
  range.insertNode(citation);
}

function supportElement(markdown) {
  const support = document.createElement("blockquote");
  support.className = "markdown-source-support";

  const label = document.createElement("p");
  label.className = "markdown-source-support-label";
  label.textContent = "Supports";

  const body = document.createElement("div");
  body.className = "markdown-source-support-body";
  const normalized = normalizeTableFragmentMarkdown(markdown, ": ");
  body.innerHTML = DOMPurify.sanitize(marked.parse(normalized), {
    USE_PROFILES: { html: true, mathMl: true },
  });

  support.append(label, body);
  return support;
}

export function renderGroundingReferences(root, metadata) {
  const view = groundingView(metadata);
  if (!view) return;

  const heading = document.createElement("h2");
  heading.className = "markdown-sources-heading";
  heading.textContent = "Sources";

  const list = document.createElement("ol");
  list.className = "markdown-source-references";

  view.references.forEach((reference, index) => {
    const number = index + 1;
    const item = document.createElement("li");
    item.id = `${root.id || "markdown"}-source-${number}`;
    item.className = "markdown-source-reference";
    reference.id = item.id;

    const link = document.createElement("a");
    link.className = "markdown-source-link";
    link.href = reference.url;
    link.textContent = reference.title;
    item.appendChild(link);

    if (reference.supports.length > 0) {
      const supports = document.createElement("div");
      supports.className = "markdown-source-supports";
      reference.supports.forEach((support) => {
        supports.appendChild(supportElement(support));
      });
      item.appendChild(supports);
    }

    list.appendChild(item);
  });

  const followUpHeading = Array.from(root.querySelectorAll("h2, h3")).find(
    isFollowUpHeading,
  );

  if (followUpHeading) {
    followUpHeading.before(heading, list);
  } else {
    root.append(heading, list);
  }

  enhanceLinks(root);
  list.querySelectorAll(".markdown-source-link").forEach(enhanceSourceLink);

  view.citationGroups.forEach((support) => {
    insertSourceCitation(root, heading, support, view.references);
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

export function enhanceBlockquoteAttributions(root) {
  const paragraphs = root.querySelectorAll("blockquote > p:last-child");

  paragraphs.forEach((paragraph) => {
    const meaningfulNodes = Array.from(paragraph.childNodes).filter(
      (node) => node.nodeType !== 3 || node.textContent.trim() !== "",
    );

    if (meaningfulNodes.length !== 1) return;

    const emphasis = meaningfulNodes[0];
    if (emphasis.nodeType !== 1 || emphasis.tagName !== "EM") return;
    if (!/^[—–-]\s*\S/.test(emphasis.textContent.trim())) return;

    paragraph.classList.add("quote-attribution");
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
        /^\s*title\b\s*:?\s*/i.test(first2)
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
  const groundingSource = el.getAttribute("data-grounding") || "";
  const enhanceFollowUpQuestionsEnabled =
    el.getAttribute("data-enhance-follow-up-questions") !== "false";
  const currentHash = hashString(
    md +
      "|FOLLOW_UPS|" +
      existingFollowUpQuestions +
      "|GROUNDING|" +
      groundingSource +
      "|ENHANCE_FOLLOW_UPS|" +
      enhanceFollowUpQuestionsEnabled,
  );
  const serverFallbackPresent = el.querySelector(
    '[data-role="server-markdown-fallback"]',
  );

  if (
    el.__markdownHash === currentHash &&
    el.innerHTML.trim() !== "" &&
    !serverFallbackPresent
  ) {
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
  enhanceBlockquoteAttributions(el);
  renderGroundingReferences(el, readGroundingMetadata(el));

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

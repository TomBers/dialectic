import { followUpQuestionsFromMarkdown } from "./markdown_hook.js";
import { showToast, copyToClipboard } from "./toast.js";

const ContentDraftsHook = {
  mounted() {
    this._renderFollowUpQuestions();

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

  updated() {
    this._renderFollowUpQuestions();
  },

  destroyed() {
    if (this._onClick) {
      this.el.removeEventListener("click", this._onClick);
    }
  },

  _renderFollowUpQuestions() {
    this.el
      .querySelectorAll("[data-follow-up-question-source]")
      .forEach((el) => {
        const source = el.getAttribute("data-follow-up-question-source") || "";
        const list = el.querySelector("[data-follow-up-question-list]");
        const empty = el.querySelector("[data-follow-up-question-empty]");
        if (!list) return;

        const questions = followUpQuestionsFromMarkdown(source);
        list.replaceChildren();
        this._syncFollowUpInputs(questions);
        this._renderFollowUpAssets(el, questions);

        if (questions.length === 0) {
          if (empty) empty.classList.remove("hidden");
          list.classList.add("hidden");
          return;
        }

        if (empty) empty.classList.add("hidden");
        list.classList.remove("hidden");

        questions.forEach((question, index) => {
          const item = document.createElement("li");
          item.className =
            "rounded-lg border border-sky-100 bg-sky-50 px-3 py-2 text-sm font-medium leading-5 text-slate-800";
          item.textContent = `${index + 1}. ${question}`;
          list.appendChild(item);
        });
      });
  },

  _syncFollowUpInputs(questions) {
    this.el
      .querySelectorAll("[data-follow-up-question-inputs]")
      .forEach((el) => {
        el.replaceChildren();

        questions.forEach((question) => {
          const input = document.createElement("input");
          input.type = "hidden";
          input.name = "content_generation[follow_up_questions][]";
          input.value = question;
          el.appendChild(input);
        });
      });
  },

  _renderFollowUpAssets(sourceEl, questions) {
    const list = this.el.querySelector("[data-follow-up-asset-list]");
    if (!list) return;

    list.replaceChildren();
    if (questions.length === 0) return;

    const template =
      sourceEl.getAttribute("data-follow-up-card-url-template") || "";
    const filenamePrefix =
      sourceEl.getAttribute("data-follow-up-card-filename-prefix") ||
      "rationalgrid-follow-up";
    if (!template.includes("__QUESTION__")) return;

    const heading = document.createElement("div");
    heading.className = "pt-1";
    heading.innerHTML = `
        <p class="text-xs font-semibold uppercase tracking-wide text-gray-500">Question cards</p>
        <p class="mt-1 text-xs leading-5 text-gray-500">Image assets generated from the key follow-up questions.</p>
      `;
    list.appendChild(heading);

    questions.forEach((question, index) => {
      const url = template.replace(
        "__QUESTION__",
        encodeURIComponent(question),
      );
      const filename = `${filenamePrefix}-follow-up-${index + 1}.png`;
      const article = document.createElement("article");
      article.className =
        "overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm";
      article.innerHTML = `
          <img src="${escapeAttribute(url)}" alt="${escapeAttribute(question)}" class="block aspect-[1200/630] w-full bg-gray-50 object-contain" loading="lazy" />
          <div class="space-y-3 p-3">
            <div>
              <p class="text-xs font-semibold uppercase tracking-wide text-gray-500">Follow-up question card</p>
              <h3 class="mt-1 text-sm font-semibold text-gray-900">Question ${index + 1}</h3>
              <p class="mt-1 text-xs leading-5 text-gray-500">${escapeHtml(question)}</p>
            </div>
            <div class="flex flex-wrap gap-2">
              <button type="button" data-copy-text="${escapeAttribute(url)}" class="inline-flex items-center gap-1.5 rounded-lg border border-gray-200 px-2.5 py-1.5 text-xs font-semibold text-gray-700 transition hover:bg-gray-50">Copy URL</button>
              <button type="button" data-download-svg-png="${escapeAttribute(url)}" data-download-filename="${escapeAttribute(filename)}" class="inline-flex items-center gap-1.5 rounded-lg border border-indigo-200 bg-indigo-50 px-2.5 py-1.5 text-xs font-semibold text-indigo-700 transition hover:bg-indigo-100 disabled:cursor-wait disabled:opacity-60">Download PNG</button>
            </div>
          </div>
        `;
      list.appendChild(article);
    });
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

function escapeHtml(value) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function escapeAttribute(value) {
  return escapeHtml(value);
}

export default ContentDraftsHook;

/* RandomIdeas LiveView hook
 *
 * Usage in HEEx:
 *   <div
 *     phx-hook="RandomIdeas"
 *     data-count="4"
 *     data-target-input="global-chat-input"
 *     data-loading-text="Finding ideas…"
 *     data-empty-text="No ideas right now. Try again."
 *   ></div>
 *
 * Behavior:
 * - On mount, fetches N random questions from /api/random_question.
 * - Deduplicates results and renders them as small “suggestion chips”.
 * - Clicking a chip fills the target input and triggers an input event.
 *
 * Notes:
 * - Keeps requests modest (default 4, sequential) to avoid performance issues.
 * - Adds simple loading and empty states, customizable via data-* attributes.
 */

const DEFAULT_COUNT = 4;
const DEFAULT_INPUT_ID = "global-chat-input";
const DEFAULT_LOADING = "Loading ideas…";
const DEFAULT_EMPTY = "No ideas yet. Try again.";

const BUTTON_CLASS =
  "rounded-full bg-stone-900/90 text-white text-xs px-3 py-1.5 hover:bg-stone-900 transition";

function safeParseInt(v, fallback) {
  const n = parseInt(v, 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

function fireInputEvent(el) {
  // Trigger standard input event for LiveView bindings to pick up the change
  el.dispatchEvent(new Event("input", { bubbles: true }));
}

function createChip(text, onClick, className = BUTTON_CLASS) {
  const btn = document.createElement("button");
  btn.type = "button";
  btn.className = className;
  btn.textContent = text;
  btn.title = text;
  btn.addEventListener("click", onClick, { passive: true });
  return btn;
}

async function fetchOneRandomQuestion(signal) {
  const res = await fetch("/api/random_question", {
    headers: { Accept: "application/json" },
    signal,
  });
  if (!res.ok) return null;
  const data = await res.json().catch(() => null);
  const q = data && data.question;
  if (typeof q !== "string") return null;
  const t = q.trim();
  return t.length ? t : null;
}

async function fetchMany(count, signal) {
  // Sequential fetch with a few extra attempts to avoid duplicates
  const ideas = [];
  const seen = new Set();
  const maxAttempts = Math.min(20, Math.max(count * 3, count));

  for (let i = 0; i < maxAttempts && ideas.length < count; i++) {
    if (signal.aborted) break;
    try {
      const q = await fetchOneRandomQuestion(signal);
      if (!q) continue;
      const key = q.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      ideas.push(q);
    } catch (_e) {
      // Ignore individual failures; continue trying up to maxAttempts
    }
  }
  return ideas;
}

const RandomIdeasHook = {
  mounted() {
    this.abortController = null;
    this.renderLoading();
    this.load();
  },

  updated() {
    // Optional: if attributes change (count, etc.), re-fetch
    // You can opt-in by setting data-refresh-on-update="true"
    const refreshOnUpdate = this.el.dataset.refreshOnUpdate === "true";
    if (refreshOnUpdate) {
      this.renderLoading();
      this.load();
    }
  },

  destroyed() {
    if (this.abortController) this.abortController.abort();
  },

  async load() {
    if (this.abortController) this.abortController.abort();
    this.abortController = new AbortController();

    const count = safeParseInt(this.el.dataset.count, DEFAULT_COUNT);
    try {
      const ideas = await fetchMany(count, this.abortController.signal);
      if (this.abortController.signal.aborted) return; // If we were aborted mid-flight

      if (!ideas.length) {
        this.renderEmpty();
        return;
      }
      this.renderChips(ideas);
    } catch (_e) {
      if (!this.abortController.signal.aborted) {
        this.renderEmpty();
      }
    }
  },

  renderLoading() {
    const loadingText = this.el.dataset.loadingText || DEFAULT_LOADING;
    this.el.innerHTML = "";
    const container = document.createElement("div");
    container.className = "text-sm text-stone-600";
    container.textContent = loadingText;
    this.el.appendChild(container);
  },

  renderEmpty() {
    const emptyText = this.el.dataset.emptyText || DEFAULT_EMPTY;
    this.el.innerHTML = "";
    const container = document.createElement("div");
    container.className = "text-sm text-stone-600";
    container.textContent = emptyText;

    // Optional refresh link
    const refresh = document.createElement("button");
    refresh.type = "button";
    refresh.className =
      "ml-2 text-sm text-stone-700 underline decoration-stone-300 hover:decoration-stone-600";
    refresh.textContent = "Refresh";
    refresh.addEventListener("click", () => {
      this.renderLoading();
      this.load();
    });

    const wrap = document.createElement("div");
    wrap.className = "flex items-center gap-2";
    wrap.appendChild(container);
    wrap.appendChild(refresh);

    this.el.appendChild(wrap);
  },

  renderChips(ideas) {
    const targetId = this.el.dataset.targetInput || DEFAULT_INPUT_ID;
    const classOverride = this.el.dataset.btnClass || null;

    this.el.innerHTML = "";
    const wrap = document.createElement("div");
    wrap.className = "flex flex-wrap gap-2";

    for (const idea of ideas) {
      const chip = createChip(
        idea,
        () => {
          const input = document.getElementById(targetId);
          if (!input) return;

          input.value = idea;
          input.focus();
          try {
            fireInputEvent(input);
          } catch (_e) {
            // No-op
          }
        },
        classOverride || undefined
      );
      wrap.appendChild(chip);
    }

    // Optional: add a refresh button to get a new set without full rerender
    const refresh = document.createElement("button");
    refresh.type = "button";
    refresh.className =
      "rounded-full border border-stone-300 text-stone-700 text-xs px-3 py-1.5 hover:bg-stone-50 transition";
    refresh.textContent = "Refresh ideas";
    refresh.addEventListener("click", () => {
      this.renderLoading();
      this.load();
    });

    const outer = document.createElement("div");
    outer.className = "flex flex-wrap items-center gap-2";
    outer.appendChild(wrap);
    outer.appendChild(refresh);

    this.el.appendChild(outer);
  },
};

export default RandomIdeasHook;

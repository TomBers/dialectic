/**
 * keep_focus_hook.js
 *
 * A Phoenix LiveView hook to keep the Ask/Comment input focused after submit.
 *
 * Usage
 * 1) Register the hook in your LiveSocket hooks (usually in assets/js/app.js):
 *
 *    import keepFocusHook from "./keep_focus_hook.js";
 *    hooks.KeepFocus = keepFocusHook;
 *
 * 2) Attach the hook to a stable ancestor of the chat input (recommended: the sticky input bar):
 *
 *    <div phx-hook="KeepFocus"> ... </div>
 *
 *    The hook looks for these IDs (already used in the codebase):
 *      - form:  #content-panel-chat-form
 *      - input: #content-panel-chat-input
 *
 * Behavior
 * - Detects submit on the chat form and refocuses the input after LiveView updates.
 * - Places the caret at the end of the input content.
 * - Avoids stealing focus if the user intentionally focused a different element.
 */

const INPUT_ID = "content-panel-chat-input";
const FORM_ID = "content-panel-chat-form";

const keepFocusHook = {
  mounted() {
    this._submittedRecently = false;
    this._boundOnSubmit = null;
    this._boundOnKeydown = null;
    this._lastForm = null;

    // Bind listeners and focus on initial mount
    this.bindFormListener();
    this.focusInputIfNeeded({ force: true });
  },

  updated() {
    // Rebind in case DOM nodes were replaced by LV patch
    this.bindFormListener();

    // Only refocus after a submit-triggered patch or if forced
    if (this._submittedRecently) {
      this.focusInputIfNeeded({ force: true });
      this._submittedRecently = false;
    }
  },

  destroyed() {
    // Cleanup event listeners
    if (this._lastForm && this._boundOnSubmit) {
      try {
        this._lastForm.removeEventListener("submit", this._boundOnSubmit, true);
      } catch (_) {}
    }
    if (this._boundOnKeydown) {
      try {
        window.removeEventListener("keydown", this._boundOnKeydown, true);
      } catch (_) {}
    }
  },

  // --- Helpers ---

  bindFormListener() {
    const form = document.getElementById(FORM_ID);

    // If form ref changed, unbind previous and bind new
    if (this._lastForm !== form) {
      if (this._lastForm && this._boundOnSubmit) {
        try {
          this._lastForm.removeEventListener(
            "submit",
            this._boundOnSubmit,
            true,
          );
        } catch (_) {}
      }

      if (form) {
        this._boundOnSubmit = (e) => {
          // Mark a submit happened so we refocus after patch
          this._submittedRecently = true;

          // In case LV patches synchronously, attempt immediate focus too
          this.defer(() => this.focusInputIfNeeded({ force: true }));
        };
        form.addEventListener("submit", this._boundOnSubmit, true);
      }

      this._lastForm = form;
    }

    // Optional: keep Enter from bubbling to graph-level shortcuts while typing
    if (!this._boundOnKeydown) {
      this._boundOnKeydown = (e) => {
        if (e.key !== "Enter") return;
        const t = e.target;
        const tag = (t && t.tagName) || "";
        const isEditable =
          tag === "INPUT" ||
          tag === "TEXTAREA" ||
          (t &&
            (t.isContentEditable ||
              t.closest('[contenteditable="true"], [contenteditable=""]')));

        if (isEditable) {
          e.stopPropagation();
        }
      };
      window.addEventListener("keydown", this._boundOnKeydown, true);
    }
  },

  focusInputIfNeeded({ force = false } = {}) {
    const input = document.getElementById(INPUT_ID);
    if (!input) return;

    // Don't steal focus if the user is interacting elsewhere, unless forced (after submit)
    const active = document.activeElement;
    const isInputFocused = active === input;

    const isUserFocusingAnotherEditable =
      !isInputFocused &&
      active &&
      (active.tagName === "INPUT" ||
        active.tagName === "TEXTAREA" ||
        active.isContentEditable ||
        active.closest?.('[contenteditable="true"], [contenteditable=""]'));

    if (!force && isUserFocusingAnotherEditable) {
      return;
    }

    this.defer(() => {
      try {
        input.focus({ preventScroll: true });
        // Place caret at end
        const len = input.value?.length || 0;
        if (typeof input.setSelectionRange === "function") {
          input.setSelectionRange(len, len);
        }
      } catch (_) {
        // no-op
      }
    });
  },

  // Utility to schedule work after LV DOM patch/morph settles
  defer(fn) {
    if (typeof requestAnimationFrame === "function") {
      requestAnimationFrame(() => setTimeout(fn, 0));
    } else {
      setTimeout(fn, 0);
    }
  },
};

export default keepFocusHook;

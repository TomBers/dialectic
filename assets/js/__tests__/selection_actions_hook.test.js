import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("../toast.js", () => ({
  copyToClipboard: vi.fn(() => Promise.resolve()),
  showToast: vi.fn(),
}));

import SelectionActionsHook from "../selection_actions_hook.js";
import { copyToClipboard, showToast } from "../toast.js";

let hook;

function mountHook() {
  document.body.innerHTML = `
    <div id="selection-actions-hook">
      <div id="selection-actions" data-can-edit="true">
        <div id="selection-actions-modal-selection-actions" class="hidden" aria-hidden="true">
          <div data-selection-dialog class="max-w-[620px]"></div>
          <div data-selection-text></div>
          <button type="button" data-selection-copy>
            <span data-selection-copy-icon>Copy icon</span>
            <span data-selection-copy-check class="hidden">Check icon</span>
            <span data-selection-copy-label>Copy text</span>
          </button>
          <button
            type="button"
            data-selection-action="highlight_only"
            data-disable-if-highlight="true"
          >Highlight</button>
          <form data-selection-input-form>
            <textarea name="question" data-selection-input></textarea>
            <button
              type="button"
              data-selection-advanced-toggle
              aria-expanded="false"
            >Tools</button>
            <button
              type="submit"
              data-selection-input-submit
              data-selection-submit-action="comment"
            >Comment</button>
            <button
              type="submit"
              data-selection-input-submit
              data-selection-submit-action="ask_question"
            >Ask</button>
          </form>
          <div data-selection-advanced-tools class="hidden">Advanced tools</div>
          <button type="button" data-selection-close>Close</button>
        </div>
      </div>
    </div>
  `;

  hook = Object.create(SelectionActionsHook);
  hook.el = document.querySelector("#selection-actions-hook");
  hook.pushEventTo = vi.fn();
  hook.mounted();
  return hook;
}

function showSelection(detail = {}) {
  window.dispatchEvent(
    new CustomEvent("selection:show", {
      detail: {
        selectedText: "working memory",
        nodeId: "2",
        offsets: { start: 10, end: 24 },
        ...detail,
      },
    }),
  );
}

afterEach(() => {
  hook?.destroyed();
  hook = null;
  window.__highlightsCache = [];
  vi.clearAllMocks();
  document.body.replaceChildren();
});

describe("SelectionActionsHook", () => {
  it("opens and populates the modal without sending a server event", () => {
    const instance = mountHook();

    showSelection();

    expect(instance.modalEl.classList.contains("hidden")).toBe(false);
    expect(instance.modalEl.getAttribute("aria-hidden")).toBe("false");
    expect(instance.modalEl.querySelector("[data-selection-text]").textContent).toBe(
      "“working memory”",
    );
    expect(instance.pushEventTo).not.toHaveBeenCalled();
  });

  it("sends the captured selection only after an action is chosen", () => {
    const instance = mountHook();
    showSelection();

    instance.modalEl
      .querySelector('[data-selection-action="highlight_only"]')
      .click();

    expect(instance.pushEventTo).toHaveBeenCalledOnce();
    expect(instance.pushEventTo).toHaveBeenCalledWith(
      instance.componentEl,
      "action",
      {
        action: "highlight_only",
        selectedText: "working memory",
        nodeId: "2",
        offsets: { start: 10, end: 24 },
      },
    );
    expect(instance.modalEl.classList.contains("hidden")).toBe(true);
  });

  it("copies the raw selected text and confirms the action", async () => {
    const instance = mountHook();
    showSelection();

    instance.modalEl.querySelector("[data-selection-copy]").click();
    await Promise.resolve();

    expect(copyToClipboard).toHaveBeenCalledWith("working memory");
    expect(showToast).toHaveBeenCalledWith("Selected text copied.", {
      id: "selection-copy-toast",
    });
    expect(
      instance.modalEl.querySelector("[data-selection-copy-label]").textContent,
    ).toBe("Copied");
    expect(instance.modalEl.classList.contains("hidden")).toBe(false);
    expect(instance.pushEventTo).not.toHaveBeenCalled();
  });

  it("refreshes editability from the patched component root on every open", () => {
    const instance = mountHook();
    const action = instance.modalEl.querySelector("[data-selection-action]");
    const input = instance.modalEl.querySelector("[data-selection-input]");
    const submit = instance.modalEl.querySelector("[data-selection-input-submit]");

    showSelection();
    expect(action.disabled).toBe(false);
    expect(input.disabled).toBe(false);
    expect(submit.disabled).toBe(false);

    instance.closeModal();
    instance.componentEl.dataset.canEdit = "false";
    showSelection();

    expect(action.disabled).toBe(true);
    expect(input.disabled).toBe(true);
    expect(submit.disabled).toBe(true);

    instance.closeModal();
    instance.componentEl.dataset.canEdit = "true";
    showSelection();

    expect(action.disabled).toBe(false);
    expect(input.disabled).toBe(false);
    expect(submit.disabled).toBe(false);
  });

  it("submits the selected composer action directly", () => {
    const instance = mountHook();
    showSelection();

    instance.modalEl.querySelector('[name="question"]').value = "My interpretation";
    instance.modalEl
      .querySelector('[data-selection-submit-action="comment"]')
      .click();

    expect(instance.pushEventTo).toHaveBeenCalledWith(
      instance.componentEl,
      "action",
      {
        action: "comment",
        input: "My interpretation",
        selectedText: "working memory",
        nodeId: "2",
        offsets: { start: 10, end: 24 },
      },
    );
  });

  it("toggles the tools popover from the composer", () => {
    const instance = mountHook();
    showSelection();
    const toggle = instance.modalEl.querySelector("[data-selection-advanced-toggle]");
    const tools = instance.modalEl.querySelector("[data-selection-advanced-tools]");
    const dialog = instance.modalEl.querySelector("[data-selection-dialog]");

    toggle.click();
    expect(tools.classList.contains("hidden")).toBe(false);
    expect(toggle.getAttribute("aria-expanded")).toBe("true");
    expect(dialog.classList.contains("max-w-[760px]")).toBe(true);

    toggle.click();
    expect(tools.classList.contains("hidden")).toBe(true);
    expect(toggle.getAttribute("aria-expanded")).toBe("false");
    expect(dialog.classList.contains("max-w-[620px]")).toBe(true);
  });

  it("disables highlighting when the exact selection is already cached", () => {
    window.__highlightsCache = [
      {
        id: 7,
        node_id: "2",
        selection_start: 10,
        selection_end: 24,
        links: [],
      },
    ];
    const instance = mountHook();

    showSelection();

    expect(
      instance.modalEl.querySelector(
        '[data-selection-action="highlight_only"]',
      ).disabled,
    ).toBe(true);
    expect(instance.pushEventTo).not.toHaveBeenCalled();
  });
});

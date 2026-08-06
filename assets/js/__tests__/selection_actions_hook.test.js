import { afterEach, describe, expect, it, vi } from "vitest";
import SelectionActionsHook from "../selection_actions_hook.js";

let hook;

function mountHook() {
  document.body.innerHTML = `
    <div id="selection-actions-hook">
      <div id="selection-actions">
        <div id="selection-actions-modal-selection-actions" class="hidden" aria-hidden="true">
          <div data-selection-text></div>
          <button
            type="button"
            data-selection-action="highlight_only"
            data-disable-if-highlight="true"
            data-base-disabled="false"
          >Highlight</button>
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

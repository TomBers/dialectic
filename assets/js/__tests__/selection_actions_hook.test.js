import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("../toast.js", () => ({
  copyToClipboard: vi.fn(() => Promise.resolve()),
  showToast: vi.fn(),
}));

import AskFormShortcuts from "../ask_form_shortcuts.js";
import SelectionActionsHook from "../selection_actions_hook.js";
import { copyToClipboard, showToast } from "../toast.js";

let hook;

function mountHook(context = "selection", presentation = "modal") {
  vi.spyOn(navigator, "platform", "get").mockReturnValue("MacIntel");
  document.body.innerHTML = `
    <button id="answer-trigger">Respond</button>
    <div id="selection-actions-hook">
      <div id="selection-actions" data-can-edit="true" data-action-context="${context}" data-presentation="${presentation}" data-node-id="2" data-answer-title="Practice" data-bookmarked="false" data-trigger-id="answer-trigger" data-draft-key="test-selection-drafts">
        <div id="selection-actions-modal-selection-actions" class="hidden" aria-hidden="true">
          <div data-selection-dialog tabindex="-1" class="max-w-[620px]"></div>
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
            <textarea name="vertex[content]" data-selection-input></textarea>
            ${context === "answer" ? '<input type="checkbox" name="guided_learning"><button type="button" data-answer-bookmark data-selection-action="bookmark" data-reader-shortcut="b"><span data-tool-label>Bookmark</span></button>' : ''}
            <button
              type="button"
              data-selection-advanced-toggle
              data-reader-shortcut="t"
              data-reader-shortcut-modifier="none"
              aria-expanded="false"
            ><span data-tools-closed>Thinking tools</span><span data-tools-open class="hidden">Hide tools</span></button>
            <button
              type="submit"
              data-selection-input-submit
              data-selection-submit-action="comment" data-shortcut-action="comment"
            >Comment</button>
            <button
              type="submit"
              data-selection-input-submit
              data-selection-submit-action="ask_question" data-shortcut-action="ask"
            >Ask</button>
          </form>
          <div data-selection-advanced-tools hidden><button type="button" data-selection-action="clarify">Clarify</button><button data-tools-close>Hide tools</button></div><p data-selection-status></p>
          <button type="button" data-selection-close>Close</button>
        </div>
      </div>
    </div>
  `;

  hook = Object.create(SelectionActionsHook);
  hook.el = document.querySelector("#selection-actions-hook");
  hook.el.querySelector("[data-selection-advanced-toggle]").scrollIntoView = vi.fn();
  hook.pushEventTo = vi.fn();
  hook.pushEvent = vi.fn();
  hook.handleEvent = vi.fn((name, callback) => { hook.resultHandler = callback; });
  if (presentation === "drawer") document.getElementById("answer-trigger").focus();
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
  sessionStorage.clear();
  vi.clearAllMocks();
  vi.restoreAllMocks();
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
        request_id: expect.any(String),
        action: "highlight_only",
        selectedText: "working memory",
        nodeId: "2",
        offsets: { start: 10, end: 24 },
      },
    );
    expect(instance.modalEl.classList.contains("hidden")).toBe(false);
    instance.resultHandler({request_id: instance.pendingRequest.id, status: "ok"});
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

  it("does not apply stale copy feedback to a newly selected passage", async () => {
    let finishCopy;
    copyToClipboard.mockReturnValueOnce(
      new Promise((resolve) => {
        finishCopy = resolve;
      }),
    );

    const instance = mountHook();
    showSelection();
    instance.modalEl.querySelector("[data-selection-copy]").click();

    instance.closeModal();
    showSelection({
      selectedText: "a different passage",
      offsets: { start: 30, end: 49 },
    });

    finishCopy();
    await Promise.resolve();

    expect(copyToClipboard).toHaveBeenCalledWith("working memory");
    expect(showToast).toHaveBeenCalledWith("Selected text copied.", {
      id: "selection-copy-toast",
    });
    expect(
      instance.modalEl.querySelector("[data-selection-copy-label]").textContent,
    ).toBe("Copy text");
    expect(
      instance.modalEl
        .querySelector("[data-selection-copy-check]")
        .classList.contains("hidden"),
    ).toBe(true);
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

    instance.modalEl.querySelector("[data-selection-input]").value = "My interpretation";
    instance.modalEl
      .querySelector('[data-selection-submit-action="comment"]')
      .click();

    expect(instance.pushEventTo).toHaveBeenCalledWith(
      instance.componentEl,
      "action",
      {
        request_id: expect.any(String),
        action: "comment",
        input: "My interpretation",
        selectedText: "working memory",
        nodeId: "2",
        offsets: { start: 10, end: 24 },
      },
    );
  });

  it("toggles the integrated tools panel from the composer", () => {
    const instance = mountHook();
    showSelection();
    const toggle = instance.modalEl.querySelector("[data-selection-advanced-toggle]");
    const tools = instance.modalEl.querySelector("[data-selection-advanced-tools]");

    toggle.click();
    expect(tools.hidden).toBe(false);
    expect(toggle.getAttribute("aria-expanded")).toBe("true");
    expect(toggle.querySelector("[data-tools-open]").classList.contains("hidden")).toBe(false);

    toggle.click();
    expect(tools.hidden).toBe(true);
    expect(toggle.getAttribute("aria-expanded")).toBe("false");
    expect(toggle.querySelector("[data-tools-closed]").classList.contains("hidden")).toBe(false);
  });

  it("closes just the tools and preserves the passage draft", () => {
    const instance = mountHook();
    showSelection();
    const input = instance.modalEl.querySelector("[data-selection-input]");
    input.value = "My draft";
    instance.modalEl.querySelector("[data-selection-advanced-toggle]").click();
    instance.modalEl.querySelector("[data-tools-close]").click();
    expect(instance.modalEl.querySelector("[data-selection-advanced-tools]").hidden).toBe(true);
    expect(instance.modalEl.classList.contains("hidden")).toBe(false);
    expect(input.value).toBe("My draft");
    expect(instance.pushEventTo).not.toHaveBeenCalled();
  });

  it.each(["selection", "answer"])("toggles %s tools repeatedly with T without submitting the draft", (context) => {
    const instance = mountHook(context, context === "answer" ? "drawer" : "modal");
    if (context === "selection") showSelection();
    const toggle = instance.modalEl.querySelector("[data-selection-advanced-toggle]");
    const tools = instance.modalEl.querySelector("[data-selection-advanced-tools]");
    const input = instance.modalEl.querySelector("textarea");
    input.value = "Keep my thinking";
    for (const expanded of [true, false, true]) {
      const event = new KeyboardEvent("keydown", {key: "t", code: "KeyT", bubbles: true, cancelable: true});
      document.activeElement.dispatchEvent(event);
      expect(event.defaultPrevented).toBe(true);
      expect(tools.hidden).toBe(!expanded);
      expect(toggle.getAttribute("aria-expanded")).toBe(String(expanded));
      expect(document.activeElement).toBe(toggle);
    }
    expect(input.value).toBe("Keep my thinking");
    expect(instance.pushEventTo).not.toHaveBeenCalled();
  });

  it.each(["selection", "answer"])("keeps %s tools expanded after a failed action and scopes Escape to the tools", (context) => {
    const instance = mountHook(context, context === "answer" ? "drawer" : "modal");
    if (context === "selection") showSelection();
    const toggle = instance.modalEl.querySelector("[data-selection-advanced-toggle]");
    const tools = instance.modalEl.querySelector("[data-selection-advanced-tools]");
    const input = instance.modalEl.querySelector("textarea");
    input.value = "Keep my draft";
    toggle.click();
    const action = tools.querySelector('[data-selection-action="clarify"]');
    action.focus();
    action.click();
    expect(instance.pendingRequest?.action).toBe("clarify");
    expect(tools.hidden).toBe(false);
    instance.resultHandler({request_id: instance.pendingRequest.id, status: "error", message: "Try again"});
    expect(document.activeElement).toBe(action);
    expect(tools.hidden).toBe(false);
    action.dispatchEvent(new KeyboardEvent("keydown", {key: "Escape", bubbles: true, cancelable: true}));
    expect(tools.hidden).toBe(true);
    expect(instance.modalEl.classList.contains("hidden")).toBe(false);
    expect(document.activeElement).toBe(toggle);
    expect(input.value).toBe("Keep my draft");
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

it.each([false, true])("submits the selected passage through the shared form shortcut (comment: %s)", (shiftKey) => {
  const instance = mountHook();
  const form = instance.el.querySelector("form");
  const formHook = { ...AskFormShortcuts, el: form };
  formHook.mounted();
  try {
    showSelection();
    const input = form.querySelector("textarea");
    input.value = "My question or comment";
    input.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", metaKey: true, shiftKey, bubbles: true, cancelable: true }));
    expect(instance.pushEventTo).toHaveBeenCalledWith(instance.componentEl, "action", expect.objectContaining({
      selectedText: "working memory", nodeId: "2", offsets: { start: 10, end: 24 },
      action: shiftKey ? "comment" : "ask_question", input: "My question or comment",
    }));
  } finally { formHook.destroyed(); }
});

it("focuses with slash and leaves the draft before closing with Escape", () => {
  const instance = mountHook();
  showSelection();
  const form = instance.el.querySelector("form");
  form.scrollIntoView = vi.fn();
  const input = form.querySelector("textarea");
  const dialog = instance.el.querySelector("[data-selection-dialog]");
  dialog.dispatchEvent(new KeyboardEvent("keydown", { key: "/", bubbles: true, cancelable: true }));
  expect(document.activeElement).toBe(input);
  input.value = "Keep this draft";
  input.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true }));
  expect(document.activeElement).toBe(dialog);
  expect(input.value).toBe("Keep this draft");
  expect(instance.modalEl.classList.contains("hidden")).toBe(false);
  dialog.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true }));
  expect(instance.modalEl.classList.contains("hidden")).toBe(true);
  expect(instance.pushEventTo).not.toHaveBeenCalled();
});

it.each([["a", "pros_cons"], ["r", "related_ideas"]])("shares the modifier shortcut for %s and ignores it when closed", (key, action) => {
  const instance = mountHook();
  const button = document.createElement("button");
  button.dataset.readerShortcut = key;
  button.dataset.selectionAction = action;
  button.scrollIntoView = vi.fn();
  instance.modalEl.append(button);
  showSelection();
  const dialog = instance.el.querySelector("[data-selection-dialog]");
  dialog.dispatchEvent(new KeyboardEvent("keydown", { key, altKey: true, shiftKey: true, bubbles: true, cancelable: true }));
  expect(instance.pushEventTo).toHaveBeenCalledWith(instance.componentEl, "action", expect.objectContaining({ action }));
  dialog.dispatchEvent(new KeyboardEvent("keydown", { key, altKey: true, shiftKey: true, bubbles: true, cancelable: true }));
  expect(instance.pushEventTo).toHaveBeenCalledTimes(1);
});

it.each([["e", "explain"], ["h", "highlight_only"]])("requires Alt+Shift for %s, respecting typing and disabled actions", (key, action) => {
  const instance = mountHook();
  const button = document.createElement("button");
  button.dataset.readerShortcut = key;
  button.dataset.selectionAction = action;
  button.scrollIntoView = vi.fn();
  instance.modalEl.append(button);
  showSelection();
  const dialog = instance.el.querySelector("[data-selection-dialog]");
  const press = (target, options) => target.dispatchEvent(new KeyboardEvent("keydown", {key, bubbles: true, cancelable: true, ...options}));
  press(dialog, {});
  press(dialog, {metaKey: true, shiftKey: true});
  press(dialog, {metaKey: true});
  press(instance.el.querySelector("textarea"), {altKey: true, shiftKey: true});
  button.disabled = true;
  press(dialog, {altKey: true, shiftKey: true});
  expect(instance.pushEventTo).not.toHaveBeenCalled();
  button.disabled = false;
  press(dialog, {altKey: true, shiftKey: true});
  expect(instance.pushEventTo).toHaveBeenCalledWith(instance.componentEl, "action", expect.objectContaining({action}));
});

it("restores the opening control when the modal closes", () => {
  const instance = mountHook();
  const opener = document.createElement("button");
  document.body.append(opener);
  opener.focus();
  showSelection();
  expect(document.activeElement).toBe(instance.modalEl.querySelector("[data-selection-dialog]"));
  instance.closeModal();
  expect(document.activeElement).toBe(opener);
});

it("retains drafts when dismissed, when another passage opens, and after remount", () => {
  const instance = mountHook();
  showSelection();
  const input = instance.el.querySelector("textarea");
  input.value = "My unfinished thought";
  input.dispatchEvent(new Event("input", {bubbles: true}));
  instance.closeModal();
  showSelection({offsets: {start: 50, end: 64}});
  expect(input.value).toBe("");
  instance.closeModal();
  instance.destroyed();
  const remounted = mountHook();
  showSelection();
  expect(remounted.el.querySelector("textarea").value).toBe("My unfinished thought");
});

it("keeps rejected submissions open and prevents duplicates while saving", () => {
  const instance = mountHook();
  showSelection();
  const input = instance.el.querySelector("textarea");
  input.value = "Keep my thought";
  instance.submitAction("comment", {input: input.value});
  const requestId = instance.pendingRequest.id;
  instance.submitAction("comment", {input: input.value});
  expect(instance.pushEventTo).toHaveBeenCalledOnce();
  instance.resultHandler({request_id: requestId, status: "error", message: "Sign in to continue"});
  expect(instance.modalEl.classList.contains("hidden")).toBe(false);
  expect(input.value).toBe("Keep my thought");
  expect(instance.el.querySelector("[data-selection-status]").textContent).toBe("Sign in to continue");
  expect(instance.el.querySelector("[data-selection-input-submit]").disabled).toBe(false);
});

it("clears a posted draft only after server confirmation", () => {
  const instance = mountHook();
  showSelection();
  const input = instance.el.querySelector("textarea");
  input.value = "Saved thought";
  instance.submitAction("comment", {input: input.value});
  expect(input.value).toBe("Saved thought");
  instance.resultHandler({request_id: "unrelated", status: "ok"});
  expect(instance.modalEl.classList.contains("hidden")).toBe(false);
  instance.resultHandler({request_id: instance.pendingRequest.id, status: "ok"});
  showSelection();
  expect(input.value).toBe("");
});

it("rejects blank text without sending an action", () => {
  const instance = mountHook();
  showSelection();
  instance.submitAction("comment", {input: "  \n "});
  expect(instance.pushEventTo).not.toHaveBeenCalled();
  expect(instance.modalEl.classList.contains("hidden")).toBe(false);
});

it("restores a guest draft after signing in without reading another user's drafts", () => {
  const instance = mountHook();
  const key = JSON.stringify(["2", 10, 24, "working memory"]);
  sessionStorage.setItem("guest-drafts", JSON.stringify({[key]: "Before sign-in"}));
  sessionStorage.setItem("someone-else", JSON.stringify({[key]: "Another person's draft"}));
  instance.componentEl.dataset.guestDraftKey = "guest-drafts";
  instance.drafts = instance.readDrafts();
  showSelection();
  expect(instance.el.querySelector("textarea").value).toBe("Before sign-in");
  expect(sessionStorage.getItem("guest-drafts")).toBeNull();
});

function showAnswer(detail = {}) {
  window.dispatchEvent(new CustomEvent("answer:show", {
    detail: {nodeId: "2", title: "Practice in your own words", bookmarked: false, ...detail},
  }));
}

it("opens the answer modal without a text selection and ignores passage events", () => {
  const instance = mountHook("answer");
  showSelection();
  expect(instance.modalEl.classList.contains("hidden")).toBe(true);
  showAnswer();
  expect(instance.modalEl.classList.contains("hidden")).toBe(false);
  expect(instance.modalEl.querySelector("[data-selection-text]").textContent).toBe("Practice in your own words");
  expect(instance.selectionData).toEqual({nodeId: "2"});
  expect(instance.pushEventTo).not.toHaveBeenCalled();
});

it("does not open a passage modal for an answer action", () => {
  const instance = mountHook();
  showAnswer();
  expect(instance.modalEl.classList.contains("hidden")).toBe(true);
});

it("preserves each answer draft and learning preference across closing and remounting", () => {
  const instance = mountHook("answer");
  showAnswer();
  instance.el.querySelector("textarea").value = "How would I practise?";
  instance.el.querySelector('[name="guided_learning"]').checked = true;
  instance.closeModal();
  showAnswer({nodeId: "3", title: "Recall"});
  expect(instance.el.querySelector("textarea").value).toBe("");
  expect(instance.el.querySelector('[name="guided_learning"]').checked).toBe(false);
  instance.closeModal();
  instance.destroyed();
  const remounted = mountHook("answer");
  showAnswer();
  expect(remounted.el.querySelector("textarea").value).toBe("How would I practise?");
  expect(remounted.el.querySelector('[name="guided_learning"]').checked).toBe(true);
});

it("submits whole-answer questions with their learning preference and no passage offsets", () => {
  const instance = mountHook("answer");
  showAnswer();
  const form = instance.el.querySelector("form");
  form.querySelector("textarea").value = "How can I practise?";
  form.querySelector('[name="guided_learning"]').checked = true;
  const submitter = form.querySelector('[data-selection-submit-action="ask_question"]');
  form.dispatchEvent(new SubmitEvent("submit", {bubbles: true, cancelable: true, submitter}));
  expect(instance.pushEventTo).toHaveBeenCalledWith(instance.componentEl, "action", {
    nodeId: "2", input: "How can I practise?", action: "ask_question", guided_learning: true, request_id: expect.any(String),
  });
  instance.resultHandler({request_id: instance.pendingRequest.id, status: "ok"});
  showAnswer();
  expect(form.querySelector("textarea").value).toBe("");
  expect(form.querySelector('[name="guided_learning"]').checked).toBe(false);
});

it("confirms bookmarks while keeping the modal and draft open", () => {
  const instance = mountHook("answer");
  showAnswer();
  const bookmark = instance.el.querySelector("[data-answer-bookmark]");
  const input = instance.el.querySelector("textarea");
  input.value = "Keep my thinking";
  bookmark.click();
  expect(instance.pushEventTo).toHaveBeenCalledWith(instance.componentEl, "action", {
    nodeId: "2", action: "bookmark", request_id: expect.any(String),
  });
  instance.resultHandler({request_id: instance.pendingRequest.id, status: "ok", bookmarked: true});
  expect(bookmark.getAttribute("aria-pressed")).toBe("true");
  expect(bookmark.textContent).toBe("Bookmarked");
  expect(instance.modalEl.classList.contains("hidden")).toBe(false);
  expect(input.value).toBe("Keep my thinking");
  expect(instance.modalEl.querySelector("[data-selection-status]").textContent).toBe("Bookmarked.");
  bookmark.click();
  instance.resultHandler({request_id: instance.pendingRequest.id, status: "ok", bookmarked: false});
  expect(bookmark.getAttribute("aria-pressed")).toBe("false");
  expect(bookmark.getAttribute("aria-label")).toBe("Bookmark this response");
  expect(input.value).toBe("Keep my thinking");
});

it.each([
  ["drawer", "MacIntel"],
  ["drawer", "Win32"],
  ["modal", "MacIntel"],
  ["modal", "Win32"],
])("keeps repeated bookmark shortcuts focused in the %s on %s", (presentation, platform) => {
  const instance = mountHook("answer", presentation);
  vi.spyOn(navigator, "platform", "get").mockReturnValue(platform);
  if (presentation === "modal") showAnswer();
  const bookmark = instance.el.querySelector("[data-answer-bookmark]");
  bookmark.scrollIntoView = vi.fn();
  const region = instance.modalEl.querySelector("[data-selection-dialog]");
  region.focus();

  for (const bookmarked of [true, false]) {
    document.activeElement.dispatchEvent(new KeyboardEvent("keydown", {
      key: "b", code: "KeyB", altKey: true, shiftKey: true, bubbles: true, cancelable: true,
    }));
    expect(instance.pendingRequest?.action).toBe("bookmark");
    expect(bookmark.disabled).toBe(true);
    expect(document.activeElement).toBe(region);
    instance.resultHandler({request_id: instance.pendingRequest.id, status: "ok", bookmarked});
    expect(document.activeElement).toBe(bookmark);
    expect(bookmark.getAttribute("aria-pressed")).toBe(String(bookmarked));
  }
  expect(instance.pushEventTo).toHaveBeenCalledTimes(2);
});

it("keeps the bookmark focused after a failed save so it can be retried", () => {
  const instance = mountHook("answer", "drawer");
  const bookmark = instance.el.querySelector("[data-answer-bookmark]");
  bookmark.focus();
  bookmark.click();
  expect(document.activeElement).toBe(instance.modalEl.querySelector("[data-selection-dialog]"));
  instance.resultHandler({request_id: instance.pendingRequest.id, status: "error", message: "Try again"});
  expect(document.activeElement).toBe(bookmark);
  expect(bookmark.disabled).toBe(false);
  expect(bookmark.getAttribute("aria-pressed")).toBe("false");
});

it.each(["textarea", "outside"])("does not take focus back from %s after saving a bookmark", (destination) => {
  const instance = mountHook("answer", "drawer");
  const bookmark = instance.el.querySelector("[data-answer-bookmark]");
  bookmark.focus();
  bookmark.click();
  const nextFocus = destination === "textarea"
    ? instance.el.querySelector("textarea")
    : document.body.appendChild(document.createElement("button"));
  nextFocus.focus();
  instance.resultHandler({request_id: instance.pendingRequest.id, status: "ok", bookmarked: true});
  expect(document.activeElement).toBe(nextFocus);
});

it("closes the answer modal back to its trigger without losing the draft", () => {
  const instance = mountHook("answer");
  const trigger = document.createElement("button");
  document.body.appendChild(trigger);
  trigger.focus();
  showAnswer();
  instance.el.querySelector("textarea").value = "A draft";
  instance.modalEl.querySelector("[data-selection-close]").click();
  expect(document.activeElement).toBe(trigger);
  showAnswer();
  expect(instance.el.querySelector("textarea").value).toBe("A draft");
});

it("focuses the response region when the drawer opens without focusing the text input", () => {
  const instance = mountHook("answer", "drawer");
  expect(instance.selectionData).toEqual({nodeId: "2"});
  expect(instance.modalEl.classList.contains("hidden")).toBe(false);
  expect(document.activeElement).toBe(instance.modalEl.querySelector("[data-selection-dialog]"));
  expect(document.activeElement).not.toBe(instance.modalEl.querySelector("textarea"));
  expect(instance.pushEventTo).not.toHaveBeenCalled();
});

it("hides the drawer through its owner and restores its draft after remount", () => {
  const instance = mountHook("answer", "drawer");
  instance.el.querySelector("textarea").value = "My drawer draft";
  instance.el.querySelector("[data-selection-close]").click();
  expect(instance.pushEvent).toHaveBeenCalledWith("close_answer_drawer", {node_id: "2"});
  expect(document.activeElement.id).toBe("answer-trigger");
  instance.destroyed();
  const remounted = mountHook("answer", "drawer");
  expect(remounted.el.querySelector("textarea").value).toBe("My drawer draft");
});

it("ignores page keyboard events while a drawer is open", () => {
  const instance = mountHook("answer", "drawer");
  const trigger = document.getElementById("answer-trigger");
  trigger.focus();
  trigger.dispatchEvent(new KeyboardEvent("keydown", {key: "Escape", bubbles: true, cancelable: true}));
  expect(instance.pushEvent).not.toHaveBeenCalled();
  expect(instance.modalEl.classList.contains("hidden")).toBe(false);
  const region = instance.modalEl.querySelector("[data-selection-dialog]");
  region.focus();
  region.dispatchEvent(new KeyboardEvent("keydown", {key: "Escape", bubbles: true, cancelable: true}));
  expect(instance.pushEvent).toHaveBeenCalledWith("close_answer_drawer", {node_id: "2"});
});

it("keeps the drawer mounted during submission so confirmation can clear the draft", () => {
  const instance = mountHook("answer", "drawer");
  instance.el.querySelector("textarea").value = "My submitted thought";
  instance.submitAction("comment", {input: "My submitted thought"});
  expect(document.getElementById("answer-trigger").disabled).toBe(true);
  instance.closeModal();
  expect(instance.pushEvent).not.toHaveBeenCalled();
  instance.resultHandler({request_id: instance.pendingRequest.id, status: "ok"});
  expect(document.getElementById("answer-trigger").disabled).toBe(false);
  expect(instance.pushEvent).toHaveBeenCalledWith("close_answer_drawer", {node_id: "2"});
  instance.destroyed();
  const remounted = mountHook("answer", "drawer");
  expect(remounted.el.querySelector("textarea").value).toBe("");
});

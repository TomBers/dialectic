import { afterEach, beforeEach, expect, it, vi } from "vitest";
import AskFormShortcuts from "../ask_form_shortcuts.js";

let hook, textarea, submit;
beforeEach(() => {
  document.body.innerHTML = `<form id="ask-form"><textarea>My question</textarea>
    <button type="submit" data-shortcut-action="comment" name="submit_action" value="post">Comment</button>
    <button type="submit" data-shortcut-action="ask">Ask</button></form>`;
  hook = { ...AskFormShortcuts, el: document.querySelector("form") };
  textarea = hook.el.querySelector("textarea");
  submit = vi.fn((event) => event.preventDefault());
  hook.el.addEventListener("submit", submit);
  hook.mounted();
});
afterEach(() => hook.destroyed());

function press(options = {}) {
  const event = new KeyboardEvent("keydown", {
    key: "Enter", bubbles: true, cancelable: true, ...options,
  });
  textarea.dispatchEvent(event);
  return event;
}

it.each(["ctrlKey", "metaKey"])("submits the correct action with %s", (modifier) => {
  expect(press({ [modifier]: true }).defaultPrevented).toBe(true);
  expect(submit.mock.calls[0][0].submitter.dataset.shortcutAction).toBe("ask");
  press({ [modifier]: true, shiftKey: true });
  const button = submit.mock.calls[1][0].submitter;
  expect(new FormData(hook.el, button).get("submit_action")).toBe("post");
});

it.each([{}, { shiftKey: true }, { ctrlKey: true, altKey: true },
  { ctrlKey: true, isComposing: true }, { ctrlKey: true, repeat: true }])(
  "preserves other key presses: %j", (options) => {
    expect(press(options).defaultPrevented).toBe(false);
    expect(submit).not.toHaveBeenCalled();
  },
);

it("does not submit empty or disabled forms", () => {
  textarea.value = "  ";
  press({ ctrlKey: true });
  textarea.value = "Question";
  hook.el.querySelector('[data-shortcut-action="ask"]').disabled = true;
  press({ ctrlKey: true });
  hook.el.setAttribute("aria-disabled", "true");
  press({ ctrlKey: true, shiftKey: true });
  expect(submit).not.toHaveBeenCalled();
});

it("removes its listener on destruction", () => {
  hook.destroyed();
  press({ ctrlKey: true });
  expect(submit).not.toHaveBeenCalled();
});

it.each([["MacIntel", "mac", "Meta"], ["Win32", "windows", "Control"]])(
  "adapts shortcut labels for %s after LiveView updates", (platform, expected, modifier) => {
    vi.spyOn(navigator, "platform", "get").mockReturnValue(platform);
    try {
      hook.updated();
      expect(hook.el.dataset.shortcutPlatform).toBe(expected);
      expect(hook.el.querySelector('[data-shortcut-action="ask"]').getAttribute("aria-keyshortcuts"))
        .toBe(`${modifier}+Enter`);
      expect(hook.el.querySelector('[data-shortcut-action="comment"]').getAttribute("aria-keyshortcuts"))
        .toBe(`${modifier}+Shift+Enter`);
    } finally {
      vi.restoreAllMocks();
    }
  },
);

it("keeps Enter inside the form so graph shortcuts do not open a modal", () => {
  const graphShortcut = vi.fn();
  window.addEventListener("keydown", graphShortcut);
  try {
    expect(press().defaultPrevented).toBe(false);
    press({ metaKey: true });
    textarea.value = "";
    press({ metaKey: true, shiftKey: true });
    expect(graphShortcut).not.toHaveBeenCalled();
    expect(submit).toHaveBeenCalledTimes(1);
  } finally {
    window.removeEventListener("keydown", graphShortcut);
  }
});

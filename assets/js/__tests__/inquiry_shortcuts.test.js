import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { handleInquiryShortcut, syncInquiryShortcutLabels } from "../inquiry_shortcuts.js";
let root, button;
beforeEach(() => {
  document.body.innerHTML = '<section tabindex="0"><button data-reader-shortcut="a">Test</button><button data-reader-shortcut="c">Connect</button><button data-reader-shortcut="r">Related</button></section>';
  root = document.querySelector("section");
  button = root.querySelector("button");
  button.scrollIntoView = vi.fn();
  button.addEventListener("click", event => event.preventDefault());
});
afterEach(() => vi.restoreAllMocks());
function press(options) {
  const event = new KeyboardEvent("keydown", { key: "a", bubbles: true, cancelable: true, ...options });
  root.addEventListener("keydown", event => handleInquiryShortcut(event, root), { once: true });
  root.dispatchEvent(event);
  return event;
}
it.each(["metaKey", "ctrlKey"])("preserves select all, copy, and reload with %s", modifier => {
  const clicks = vi.fn();
  root.addEventListener("click", clicks);
  for (const key of ["a", "c", "r"]) {
    expect(press({key, [modifier]: true}).defaultPrevented).toBe(false);
  }
  expect(clicks).not.toHaveBeenCalled();
});
it("recognizes Option-modified physical letter keys on Mac", () => {
  const clicks = vi.fn();
  button.addEventListener("click", clicks);
  expect(press({key: "Å", code: "KeyA", altKey: true, shiftKey: true}).defaultPrevented).toBe(true);
  expect(clicks).toHaveBeenCalledOnce();
});
it.each(["MacIntel", "Win32"])("publishes the new shortcut for %s", platform => {
  vi.spyOn(navigator, "platform", "get").mockReturnValue(platform);
  syncInquiryShortcutLabels(root);
  expect(button.getAttribute("aria-keyshortcuts")).toBe("Alt+Shift+A");
  expect(button.title).toContain(platform === "MacIntel" ? "Option+Shift+A" : "Alt+Shift+A");
});

import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { handleInquiryShortcut, syncInquiryShortcutLabels } from "../inquiry_shortcuts.js";

let root, button;
beforeEach(() => {
  vi.spyOn(navigator, "platform", "get").mockReturnValue("MacIntel");
  document.body.innerHTML = '<section tabindex="0"><button data-reader-shortcut="a">Test</button><button data-reader-shortcut="c">Synthesis</button><button data-reader-shortcut="r">Related</button><button data-reader-shortcut="b">Bookmark</button><button data-reader-shortcut="t" data-reader-shortcut-modifier="none">More tools</button><textarea></textarea><p>Selected passage</p></section>';
  root = document.querySelector("section");
  button = root.querySelector("button");
  root.querySelectorAll("button").forEach(button => { button.scrollIntoView = vi.fn(); });
});
afterEach(() => {
  window.getSelection().removeAllRanges();
  vi.restoreAllMocks();
});

function press(options, target = root) {
  const event = new KeyboardEvent("keydown", { key: "a", bubbles: true, cancelable: true, ...options });
  root.addEventListener("keydown", event => handleInquiryShortcut(event, root), { once: true });
  target.dispatchEvent(event);
  return event;
}

it.each([["MacIntel", "metaKey"], ["Win32", "ctrlKey"]])("activates A/C/R/B using the primary modifier on %s", (platform, modifier) => {
  vi.spyOn(navigator, "platform", "get").mockReturnValue(platform);
  for (const key of ["a", "c", "r", "b"]) {
    const targetButton = root.querySelector(`[data-reader-shortcut="${key}"]`);
    const clicks = vi.fn();
    targetButton.addEventListener("click", clicks);
    expect(press({key, [modifier]: true}).defaultPrevented).toBe(true);
    expect(clicks).toHaveBeenCalledOnce();
    expect(document.activeElement).toBe(targetButton);
  }
});

it.each([["MacIntel", "metaKey"], ["Win32", "ctrlKey"]])("preserves native shortcuts while typing on %s", (platform, modifier) => {
  vi.spyOn(navigator, "platform", "get").mockReturnValue(platform);
  const clicks = vi.fn();
  root.addEventListener("click", clicks);
  for (const key of ["a", "c", "r", "b", "e", "h"]) {
    expect(press({key, [modifier]: true}, root.querySelector("textarea")).defaultPrevented).toBe(false);
  }
  expect(clicks).not.toHaveBeenCalled();
});

it.each(["MacIntel", "Win32"])("uses plain T for tools and preserves modified browser shortcuts on %s", (platform) => {
  vi.spyOn(navigator, "platform", "get").mockReturnValue(platform);
  const tools = root.querySelector('[data-reader-shortcut="t"]');
  const clicks = vi.fn();
  tools.addEventListener("click", clicks);
  expect(press({key: "t", code: "KeyT"}).defaultPrevented).toBe(true);
  expect(clicks).toHaveBeenCalledOnce();
  expect(document.activeElement).toBe(tools);
  for (const options of [{metaKey: true}, {ctrlKey: true}, {altKey: true}, {shiftKey: true}, {repeat: true}, {isComposing: true}]) {
    expect(press({key: "t", ...options}).defaultPrevented).toBe(false);
  }
  expect(press({key: "m", metaKey: true}).defaultPrevented).toBe(false);
  expect(press({key: "t"}, root.querySelector("textarea")).defaultPrevented).toBe(false);
  expect(clicks).toHaveBeenCalledOnce();
  syncInquiryShortcutLabels(root);
  expect(tools.getAttribute("aria-keyshortcuts")).toBe("T");
  expect(tools.title).toBe("T (when not typing)");
});

it("preserves copy when a passage is selected", () => {
  const range = document.createRange();
  range.selectNodeContents(root.querySelector("p"));
  window.getSelection().addRange(range);
  const clicks = vi.fn();
  root.addEventListener("click", clicks);
  expect(press({key: "c", metaKey: true}).defaultPrevented).toBe(false);
  expect(clicks).not.toHaveBeenCalled();
});

it("ignores other modifiers, repeating events, and disabled tools", () => {
  const clicks = vi.fn();
  button.addEventListener("click", clicks);
  for (const options of [{}, {ctrlKey: true}, {altKey: true, shiftKey: true}, {metaKey: true, shiftKey: true}, {metaKey: true, repeat: true}]) {
    expect(press(options).defaultPrevented).toBe(false);
  }
  button.disabled = true;
  expect(press({metaKey: true}).defaultPrevented).toBe(false);
  expect(clicks).not.toHaveBeenCalled();
});

it.each(["a", "t"])("does not intercept %s outside the reader", (key) => {
  const outside = document.createElement("button");
  document.body.append(outside);
  const event = new KeyboardEvent("keydown", { key, metaKey: key === "a", bubbles: true, cancelable: true });
  outside.addEventListener("keydown", event => {
    expect(handleInquiryShortcut(event, root)).toBe(false);
  });
  outside.dispatchEvent(event);
  expect(event.defaultPrevented).toBe(false);
});

it.each([["MacIntel", "Meta+A", "Command+A"], ["Win32", "Control+A", "Ctrl+A"]])("publishes matching shortcut labels for %s", (platform, aria, title) => {
  vi.spyOn(navigator, "platform", "get").mockReturnValue(platform);
  syncInquiryShortcutLabels(root);
  expect(button.getAttribute("aria-keyshortcuts")).toBe(aria);
  expect(button.title).toContain(title);
});

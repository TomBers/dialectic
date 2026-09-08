import { beforeEach, afterEach, it, expect, vi } from "vitest";
import GraphKeyboardNavigation from "../graph_keyboard_navigation.js";
let hook, grid, reader, input;
beforeEach(() => {
  document.body.innerHTML = `<div id="workspace"><div id="cy-inner" tabindex="0"></div><div id="side-drawer-scroll" tabindex="0"><form phx-hook="AskFormShortcuts"><textarea></textarea></form></div></div>`;
  hook = { ...GraphKeyboardNavigation, el: document.querySelector("#workspace") };
  grid = document.querySelector("#cy-inner");
  reader = document.querySelector("#side-drawer-scroll");
  input = document.querySelector("textarea");
  vi.spyOn(HTMLElement.prototype, "getClientRects").mockReturnValue([{}]);
  input.scrollIntoView = vi.fn();
  hook.mounted();
});
afterEach(() => { hook.destroyed(); vi.restoreAllMocks(); });
function key(key, options = {}) {
  const event = new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true, ...options });
  document.activeElement.dispatchEvent(event);
  return event;
}
it("switches regions, focuses the composer, and preserves a draft on return", () => {
  grid.focus();
  key("F6");
  expect(document.activeElement).toBe(reader);
  key("/");
  expect(document.activeElement).toBe(input);
  input.value = "My draft";
  key("Escape");
  expect(document.activeElement).toBe(reader);
  key("Escape");
  expect(document.activeElement).toBe(grid);
  key("Enter");
  expect(document.activeElement).toBe(reader);
  key("F6");
  expect(document.activeElement).toBe(grid);
  expect(input.value).toBe("My draft");
});
it("preserves typing and native reader scrolling", () => {
  reader.focus();
  expect(key("ArrowDown").defaultPrevented).toBe(false);
  expect(key("PageDown").defaultPrevented).toBe(false);
  input.focus();
  expect(key("/").defaultPrevented).toBe(false);
  expect(key("Enter", { metaKey: true }).defaultPrevented).toBe(false);
});
it("removes listeners when unmounted", () => {
  hook.destroyed();
  grid.focus();
  key("F6");
  expect(document.activeElement).toBe(grid);
});

it("scrolls the nested node content when the reader is focused", () => {
  const scroller = document.createElement("div");
  scroller.id = "tt-node-2";
  scroller.scrollBy = vi.fn();
  scroller.scrollTo = vi.fn();
  reader.append(scroller);
  reader.focus();
  expect(key("ArrowDown").defaultPrevented).toBe(true);
  expect(scroller.scrollBy).toHaveBeenCalledWith({ top: 48, behavior: "instant" });
  key("Home");
  expect(scroller.scrollTo).toHaveBeenCalledWith({ top: 0, behavior: "instant" });
});

it("switches regions with Tab and Shift+Tab, including from a draft", () => {
  grid.focus();
  expect(key("Tab").defaultPrevented).toBe(true);
  expect(document.activeElement).toBe(reader);
  key("Tab", { shiftKey: true });
  expect(document.activeElement).toBe(grid);
  input.focus();
  input.value = "Keep this draft";
  key("Tab");
  expect(document.activeElement).toBe(grid);
  expect(input.value).toBe("Keep this draft");
});

it("reveals the full composer and tools when focusing with slash", () => {
  const composer = document.createElement("section");
  composer.dataset.keyboardComposer = "";
  composer.scrollIntoView = vi.fn();
  input.form.before(composer);
  composer.append(input.form);
  reader.focus();
  key("/");
  expect(document.activeElement).toBe(input);
  expect(composer.scrollIntoView).toHaveBeenCalledWith({ block: "center", behavior: "instant" });
});

it.each(["a", "c", "r"])("activates %s only outside typing and respects disabled tools", (shortcut) => {
  const button = document.createElement("button");
  button.dataset.readerShortcut = shortcut;
  button.scrollIntoView = vi.fn();
  const click = vi.fn();
  button.addEventListener("click", click);
  reader.append(button);
  input.focus();
  expect(key(shortcut, { metaKey: true }).defaultPrevented).toBe(false);
  expect(click).not.toHaveBeenCalled();
  key("Escape");
  expect(key(shortcut).defaultPrevented).toBe(false);
  expect(click).not.toHaveBeenCalled();
  key(shortcut, { metaKey: true });
  expect(click).toHaveBeenCalledTimes(1);
  button.disabled = true;
  reader.focus();
  key(shortcut, { metaKey: true });
  expect(click).toHaveBeenCalledTimes(1);
});

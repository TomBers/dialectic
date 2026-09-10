import { afterEach, beforeEach, expect, it, vi } from "vitest";
import ToolsMenu from "../tools_menu_hook.js";

let hook, trigger, menu;
beforeEach(() => {
  document.body.innerHTML = `<button id="tools" aria-expanded="false" aria-controls="extra-tools">
      <span data-tools-closed>More tools</span><span data-tools-open class="hidden">Hide tools</span>
    </button>
    <div id="extra-tools" role="group" data-trigger-id="tools" phx-target="17" data-open="false" hidden>
      <button phx-click="node_clarify">Clarify</button>
      <button data-tools-close>Hide tools</button>
    </div><input id="composer-input">`;
  trigger = document.getElementById("tools");
  trigger.scrollIntoView = vi.fn();
  menu = document.getElementById("extra-tools");
  menu.showPopover = vi.fn();
  menu.hidePopover = vi.fn();
  hook = { ...ToolsMenu, el: menu, pushEventTo: vi.fn() };
  hook.mounted();
});
afterEach(() => {
  hook.destroyed();
  document.body.replaceChildren();
});

function expandTools() {
  menu.dataset.open = "true";
  hook.updated();
}

it("reveals inline tools without moving focus or opening a popover", () => {
  trigger.focus();
  expandTools();
  expect(menu.hidden).toBe(false);
  expect(document.activeElement).toBe(trigger);
  expect(menu.showPopover).not.toHaveBeenCalled();
  expect(trigger.scrollIntoView).not.toHaveBeenCalled();
});

it("follows server disclosure state without sending another event", () => {
  expect(menu.hidden).toBe(true);
  expandTools();
  expect(menu.hidden).toBe(false);
  expect(trigger.getAttribute("aria-expanded")).toBe("true");
  expect(trigger.querySelector("[data-tools-open]").classList.contains("hidden")).toBe(false);
  expect(trigger.querySelector("[data-tools-closed]").classList.contains("hidden")).toBe(true);

  menu.dataset.open = "false";
  hook.updated();
  expect(menu.hidden).toBe(true);
  expect(trigger.getAttribute("aria-expanded")).toBe("false");
  expect(trigger.querySelector("[data-tools-closed]").classList.contains("hidden")).toBe(false);
  expect(hook.pushEventTo).not.toHaveBeenCalled();
});

it("collapses from the bottom and brings the toggle back into view", () => {
  expandTools();
  const hide = menu.querySelector("[data-tools-close]");
  hide.focus();
  hide.click();
  expect(menu.hidden).toBe(true);
  expect(document.activeElement).toBe(trigger);
  expect(trigger.scrollIntoView).toHaveBeenCalledExactlyOnceWith({block: "nearest", behavior: "instant"});
  expect(menu.hidePopover).not.toHaveBeenCalled();
  expect(hook.pushEventTo).toHaveBeenCalledExactlyOnceWith(17, "close_advanced_tools", {});
});

it.each(["tool", "trigger"])("Escape on the %s collapses tools and returns focus", (target) => {
  expandTools();
  const focused = target === "tool" ? menu.querySelector("button") : trigger;
  focused.focus();
  const event = new KeyboardEvent("keydown", {key: "Escape", bubbles: true, cancelable: true});
  focused.dispatchEvent(event);
  expect(event.defaultPrevented).toBe(true);
  expect(menu.hidden).toBe(true);
  expect(document.activeElement).toBe(trigger);
  expect(hook.pushEventTo).toHaveBeenCalledExactlyOnceWith(17, "close_advanced_tools", {});
});

it("stays open while typing, clicking elsewhere, scrolling and resizing", () => {
  expandTools();
  const input = document.getElementById("composer-input");
  input.dispatchEvent(new Event("pointerdown", {bubbles: true}));
  input.focus();
  input.value = "My question";
  input.dispatchEvent(new Event("input", {bubbles: true}));
  const escape = new KeyboardEvent("keydown", {key: "Escape", bubbles: true, cancelable: true});
  input.dispatchEvent(escape);
  window.dispatchEvent(new Event("scroll"));
  window.dispatchEvent(new Event("resize"));
  expect(menu.hidden).toBe(false);
  expect(escape.defaultPrevented).toBe(false);
  expect(document.activeElement).toBe(input);
  expect(input.value).toBe("My question");
  expect(hook.pushEventTo).not.toHaveBeenCalled();
});

it("keeps tools revealed when an action is selected", () => {
  expandTools();
  menu.querySelector("button[phx-click]").click();
  expect(menu.hidden).toBe(false);
  expect(hook.pushEventTo).not.toHaveBeenCalled();
});

it("removes local listeners when the panel is removed", () => {
  expandTools();
  hook.destroyed();
  trigger.dispatchEvent(new KeyboardEvent("keydown", {key: "Escape", bubbles: true}));
  menu.querySelector("[data-tools-close]").click();
  expect(hook.pushEventTo).not.toHaveBeenCalled();
});

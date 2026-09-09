import { afterEach, beforeEach, expect, it, vi } from "vitest";
import ToolsMenu from "../tools_menu_hook.js";

let hook, trigger, menu;
beforeEach(() => {
  document.body.innerHTML = `<button id="tools" aria-expanded="false">
      <span data-tools-closed>Thinking tools</span><span data-tools-open class="hidden">Hide tools</span>
    </button>
    <div id="menu" data-trigger-id="tools" phx-target="17" data-open="false" hidden>
      <button phx-click="node_clarify">Clarify</button>
    </div><input id="composer-input">`;
  trigger = document.getElementById("tools");
  menu = document.getElementById("menu");
  hook = { ...ToolsMenu, el: menu, pushEventTo: vi.fn() };
  hook.mounted();
});
afterEach(() => {
  hook.destroyed();
  document.body.innerHTML = "";
});

function expandTools() {
  menu.dataset.open = "true";
  hook.updated();
}

it("follows server disclosure state and updates the trigger without sending another event", () => {
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

it("Escape collapses the tools and returns focus to the trigger", () => {
  expandTools();
  menu.querySelector("button").focus();
  menu.dispatchEvent(new KeyboardEvent("keydown", {key: "Escape", bubbles: true}));
  expect(menu.hidden).toBe(true);
  expect(hook.pushEventTo).toHaveBeenCalledExactlyOnceWith(17, "close_advanced_tools", {});
  expect(document.activeElement).toBe(trigger);
});

it("stays expanded while the user works in the composer", () => {
  expandTools();
  const input = document.getElementById("composer-input");
  input.dispatchEvent(new Event("pointerdown", {bubbles: true}));
  input.click();
  input.focus();
  expect(menu.hidden).toBe(false);
  expect(hook.pushEventTo).not.toHaveBeenCalled();
});

it("collapses after selecting an enabled tool and targets its owning component", () => {
  expandTools();
  const button = menu.querySelector("button");
  button.disabled = true;
  button.dispatchEvent(new Event("click", {bubbles: true}));
  expect(menu.hidden).toBe(false);
  expect(hook.pushEventTo).not.toHaveBeenCalled();
  button.disabled = false;
  menu.setAttribute("phx-target", "99");
  button.dispatchEvent(new Event("click", {bubbles: true}));
  expect(menu.hidden).toBe(true);
  expect(hook.pushEventTo).toHaveBeenCalledExactlyOnceWith(17, "close_advanced_tools", {});
});

it("removes dismissal listeners when the panel is removed", () => {
  expandTools();
  hook.destroyed();
  window.dispatchEvent(new KeyboardEvent("keydown", {key: "Escape"}));
  expect(hook.pushEventTo).not.toHaveBeenCalled();
});

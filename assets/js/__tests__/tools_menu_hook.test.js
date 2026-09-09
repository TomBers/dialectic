import { afterEach, beforeEach, expect, it, vi } from "vitest";
import ToolsMenu, { toolsMenuPlacement } from "../tools_menu_hook.js";

let hook, trigger, menu;
beforeEach(() => {
  document.body.innerHTML = `<button id="tools" aria-expanded="false">
      <span data-tools-closed>Thinking tools</span><span data-tools-open class="hidden">Hide tools</span>
    </button>
    <div id="menu" data-trigger-id="tools" phx-target="17" data-open="false" popover="manual" hidden>
      <div data-tools-scroll><button phx-click="node_clarify">Clarify</button></div>
      <p data-tools-scroll-hint hidden>Scroll for more tools</p>
      <button data-tools-close>Close tools</button>
    </div><input id="composer-input">`;
  trigger = document.getElementById("tools");
  trigger.scrollIntoView = vi.fn();
  menu = document.getElementById("menu");
  menu.showPopover = vi.fn();
  menu.hidePopover = vi.fn();
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

it("shows the scroll cue only while more tools remain below", () => {
  const scroller = menu.querySelector("[data-tools-scroll]");
  const hint = menu.querySelector("[data-tools-scroll-hint]");
  Object.defineProperties(scroller, {
    scrollHeight: { configurable: true, value: 600 },
    clientHeight: { configurable: true, value: 240 },
  });
  expandTools();
  expect(hint.hidden).toBe(false);

  scroller.scrollTop = 360;
  scroller.dispatchEvent(new Event("scroll"));
  expect(hint.hidden).toBe(true);

  scroller.scrollTop = 0;
  scroller.dispatchEvent(new Event("scroll"));
  expect(hint.hidden).toBe(false);

  Object.defineProperty(scroller, "clientHeight", { value: 600 });
  window.dispatchEvent(new Event("resize"));
  expect(hint.hidden).toBe(true);
});

it("does not suggest scrolling when all tools already fit", () => {
  expandTools();
  expect(menu.querySelector("[data-tools-scroll-hint]").hidden).toBe(true);
});

it("opens in the top layer and returns focus without moving the page on close", () => {
  expandTools();
  expect(menu.showPopover).toHaveBeenCalledOnce();
  expect(document.activeElement).toBe(menu.querySelector("button[phx-click]"));
  menu.querySelector("[data-tools-close]").click();
  expect(menu.hidden).toBe(true);
  expect(document.activeElement).toBe(trigger);
  expect(trigger.scrollIntoView).not.toHaveBeenCalled();
  expect(menu.hidePopover).toHaveBeenCalledOnce();
  expect(hook.pushEventTo).toHaveBeenCalledExactlyOnceWith(17, "close_advanced_tools", {});
});

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

it("dismisses on an outside click while allowing the trigger to toggle the menu", () => {
  expandTools();
  trigger.dispatchEvent(new Event("pointerdown", {bubbles: true}));
  expect(menu.hidden).toBe(false);
  const input = document.getElementById("composer-input");
  input.dispatchEvent(new Event("pointerdown", {bubbles: true}));
  input.click();
  input.focus();
  expect(menu.hidden).toBe(true);
  expect(hook.pushEventTo).toHaveBeenCalledExactlyOnceWith(17, "close_advanced_tools", {});
});

it("anchors above the trigger and keeps the menu inside a narrow viewport", () => {
  expect(toolsMenuPlacement(
    {top: 500, bottom: 544, left: 200, right: 300},
    {top: 0, left: 0, width: 390, height: 844},
    844,
  )).toEqual({width: "374px", left: "8px", maxHeight: "480px", top: "auto", bottom: "352px"});
});

it("opens below a trigger near the top of the viewport", () => {
  expect(toolsMenuPlacement(
    {top: 50, bottom: 94, left: 100, right: 200},
    {top: 0, left: 0, width: 390, height: 844},
    844,
  )).toMatchObject({top: "102px", bottom: "auto", maxHeight: "480px"});
});

it("aligns with the left edge of a trigger inside a centered modal", () => {
  expect(toolsMenuPlacement(
    {top: 600, bottom: 644, left: 540, right: 640},
    {top: 0, left: 0, width: 1440, height: 900},
    900,
  )).toMatchObject({left: "540px", width: "420px", bottom: "308px"});
});

it("keeps a menu near the right edge within the viewport", () => {
  expect(toolsMenuPlacement(
    {top: 600, bottom: 644, left: 1100, right: 1200},
    {top: 0, left: 0, width: 1280, height: 900},
    900,
  )).toMatchObject({left: "852px", width: "420px"});
});

it("uses the visible viewport when the keyboard leaves little room around the trigger", () => {
  expect(toolsMenuPlacement(
    {top: 350, bottom: 394, left: 200, right: 300},
    {top: 300, left: 0, width: 390, height: 200},
    844,
  )).toMatchObject({top: "308px", bottom: "auto", maxHeight: "184px"});
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

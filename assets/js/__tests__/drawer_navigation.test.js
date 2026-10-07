import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { createDrawerNavigation, syncDrawerAccessibility } from "../drawer_navigation.js";

let navigation, root, panel, trigger, close;
beforeEach(() => {
  vi.useFakeTimers();
  vi.stubGlobal("requestAnimationFrame", (callback) => setTimeout(callback, 0));
  vi.stubGlobal("cancelAnimationFrame", clearTimeout);
  vi.stubGlobal("CSS", { escape: (value) => value });
  document.body.innerHTML = `<div id="workspace">
    <button id="tools">Tools</button>
    <section id="right-panel" data-right-drawer tabindex="-1">
      <button data-panel-close>Close tools</button>
      <details id="details-configure"><summary>Answer level</summary><button>Simple</button></details>
    </section>
    <section id="presentation-drawer" data-right-drawer><button data-panel-close>Close setup</button></section>
    <input id="draft">
  </div>`;
  root = document.getElementById("workspace");
  panel = document.getElementById("right-panel");
  trigger = document.getElementById("tools");
  close = vi.fn((id) => {
    syncDrawerAccessibility(document.getElementById(id), false);
    navigation.close();
  });
  navigation = createDrawerNavigation(root, close);
});
afterEach(() => {
  navigation.destroy();
  vi.useRealTimers();
  vi.unstubAllGlobals();
});

function open(section = null) {
  trigger.focus();
  syncDrawerAccessibility(panel, true);
  navigation.open(panel, trigger, section);
  vi.runOnlyPendingTimers();
}

it("removes closed drawer controls from keyboard and accessibility navigation", () => {
  syncDrawerAccessibility(panel, false);
  expect(panel.inert).toBe(true);
  expect(panel.getAttribute("aria-hidden")).toBe("true");
  syncDrawerAccessibility(panel, true);
  expect(panel.inert).toBe(false);
  expect(panel.hasAttribute("aria-hidden")).toBe(false);
});

it("focuses the opened drawer and returns to its trigger on Escape", () => {
  open();
  expect(document.activeElement).toBe(panel.querySelector("[data-panel-close]"));
  const escape = new KeyboardEvent("keydown", { key: "Escape", bubbles: true, cancelable: true });
  document.activeElement.dispatchEvent(escape);
  expect(escape.defaultPrevented).toBe(true);
  expect(close).toHaveBeenCalledWith("right-panel");
  expect(document.activeElement).toBe(trigger);
});

it("focuses the requested settings section", () => {
  open("configure");
  expect(document.activeElement).toBe(panel.querySelector("summary"));
});

it("preserves the header trigger when switching between drawers", () => {
  open();
  const next = document.getElementById("presentation-drawer");
  navigation.open(next, document.activeElement);
  vi.runOnlyPendingTimers();
  navigation.close();
  expect(document.activeElement).toBe(trigger);
});

it("restores focus after drawer contents render without stealing it from the workspace", () => {
  open();
  panel.querySelector("[data-panel-close]").remove();
  expect(document.activeElement).toBe(document.body);
  const newClose = document.createElement("button");
  newClose.dataset.panelClose = "";
  panel.prepend(newClose);
  navigation.refresh();
  vi.runOnlyPendingTimers();
  expect(document.activeElement).toBe(newClose);
  const input = document.getElementById("draft");
  input.focus();
  navigation.refresh();
  vi.runOnlyPendingTimers();
  expect(document.activeElement).toBe(input);
});

it("leaves nested dialogs and typing outside the drawer in control of Escape", () => {
  open();
  const dialog = document.createElement("div");
  dialog.setAttribute("role", "dialog");
  const input = document.createElement("input");
  dialog.append(input);
  panel.append(dialog);
  input.focus();
  input.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
  document.getElementById("draft").dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
  expect(close).not.toHaveBeenCalled();
});

it("cancels pending focus and removes listeners on navigation", () => {
  trigger.focus();
  navigation.open(panel, trigger);
  navigation.destroy();
  vi.runOnlyPendingTimers();
  expect(document.activeElement).toBe(trigger);
  panel.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
  expect(close).not.toHaveBeenCalled();
});

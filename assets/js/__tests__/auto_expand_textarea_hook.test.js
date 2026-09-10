import { afterEach, beforeEach, expect, it, vi } from "vitest";
import AutoExpandTextareaHook from "../auto_expand_textarea_hook.js";

let hook;
let notifyResize;
let contentHeight;

beforeEach(() => {
  vi.useFakeTimers();
  vi.stubGlobal("ResizeObserver", class {
    constructor(callback) { notifyResize = callback; }
    observe() {}
    disconnect() {}
  });
  document.body.innerHTML = '<label><textarea style="min-height: 48px"></textarea></label>';
  const textarea = document.querySelector("textarea");
  contentHeight = 48;
  Object.defineProperty(textarea, "scrollHeight", { get: () => contentHeight });
  hook = { ...AutoExpandTextareaHook, el: textarea };
  hook.mounted();
});

afterEach(() => {
  hook.destroyed();
  vi.useRealTimers();
  vi.unstubAllGlobals();
  document.body.innerHTML = "";
});

it("fits wrapped content after a width change without reacting to its own height changes", () => {
  contentHeight = 120;
  notifyResize([{ contentRect: { width: 200, height: 48 } }]);
  expect(hook.el.style.height).toBe("48px");
  vi.advanceTimersByTime(20);
  expect(hook.el.style.height).toBe("120px");

  notifyResize([{ contentRect: { width: 200, height: 120 } }]);
  expect(vi.getTimerCount()).toBe(0);

  contentHeight = 48;
  notifyResize([{ contentRect: { width: 400, height: 120 } }]);
  vi.advanceTimersByTime(20);
  expect(hook.el.style.height).toBe("48px");
});

it("cancels a pending resize when the form is removed", () => {
  notifyResize([{ contentRect: { width: 200, height: 48 } }]);
  hook.destroyed();
  contentHeight = 120;
  vi.advanceTimersByTime(20);
  expect(hook.el.style.height).toBe("48px");
});

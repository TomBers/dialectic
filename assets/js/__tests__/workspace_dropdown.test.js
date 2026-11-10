import { afterEach, describe, expect, it, vi } from "vitest";
import WorkspaceDropdown from "../workspace_dropdown.js";

let hook;
afterEach(() => {
  hook?.destroyed();
  hook = null;
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
  document.body.replaceChildren();
});

function mount(native) {
  vi.stubGlobal("CSS", { supports: () => native });
  vi.stubGlobal("cancelAnimationFrame", vi.fn());
  document.body.innerHTML = '<div id="dropdown"><button id="trigger" popovertarget="options">Visibility</button><div id="options" popover="auto"><button aria-pressed="true" data-dropdown-choice>Public</button><button data-dropdown-choice>Private</button></div></div>';
  const panel = document.getElementById("options");
  panel.matches = () => true;
  panel.hidePopover = vi.fn();
  hook = {...WorkspaceDropdown, el: document.getElementById("dropdown")};
  hook.mounted();
  return hook;
}

function open(instance) {
  const event = new Event("toggle");
  event.newState = "open";
  instance.panel.dispatchEvent(event);
}

describe("workspace dropdown", () => {
  it("keeps keyboard navigation and Escape focus restoration with native positioning", () => {
    const instance = mount(true);
    const measure = vi.spyOn(instance.trigger, "getBoundingClientRect");
    open(instance);
    expect(document.activeElement).toBe(instance.panel.firstElementChild);
    instance.panel.dispatchEvent(new KeyboardEvent("keydown", {key: "ArrowDown", bubbles: true, cancelable: true}));
    expect(document.activeElement).toBe(instance.panel.lastElementChild);
    document.dispatchEvent(new Event("scroll"));
    instance.updated();
    expect(measure).not.toHaveBeenCalled();
    instance.panel.dispatchEvent(new KeyboardEvent("keydown", {key: "Escape", bubbles: true, cancelable: true}));
    expect(instance.panel.hidePopover).toHaveBeenCalledOnce();
    expect(document.activeElement).toBe(instance.trigger);
  });

  it("positions synchronously on opening and batches fallback scroll updates", () => {
    let frame;
    vi.stubGlobal("requestAnimationFrame", vi.fn(callback => {frame = callback; return 1;}));
    const instance = mount(false);
    const measure = vi.spyOn(instance.trigger, "getBoundingClientRect").mockReturnValue({top: 80, bottom: 120, right: 200});
    open(instance);
    expect(instance.panel.style.top).toBe("128px");
    expect(measure).toHaveBeenCalledOnce();
    document.dispatchEvent(new Event("scroll"));
    document.dispatchEvent(new Event("scroll"));
    expect(requestAnimationFrame).toHaveBeenCalledOnce();
    frame();
    expect(measure).toHaveBeenCalledTimes(2);
    instance.panel.lastElementChild.dispatchEvent(new MouseEvent("click", {bubbles: true}));
    expect(instance.panel.hidePopover).toHaveBeenCalledOnce();
    expect(document.activeElement).toBe(instance.trigger);
  });
});

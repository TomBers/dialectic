import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

let Markdown;
beforeEach(async () => {
  vi.resetModules();
  ({default: Markdown} = await import("../markdown_hook.js"));
});
afterEach(() => {
  vi.doUnmock("katex");
  vi.restoreAllMocks();
  document.body.replaceChildren();
});
function mount(source) {
  const el = document.createElement("div");
  el.dataset.md = source;
  el.dataset.enhanceFollowUpQuestions = "false";
  document.body.append(el);
  const hook = {el, pushEvent: vi.fn()};
  Markdown.mounted.call(hook);
  return hook;
}

describe("conditional math rendering", () => {
  it("renders ordinary Markdown immediately without scheduling math loading", () => {
    const hook = mount("## Plain heading\n\nText with **emphasis**.");
    expect(hook.el.querySelector("strong").textContent).toBe("emphasis");
    expect(hook.el.__mathPending).toBeUndefined();
  });

  it("keeps math source readable and then renders inline and block formulas", async () => {
    const hook = mount("Inline $x^2$ and a block:\n\n$$\nx + y = z\n$$");
    expect(hook.el.textContent).toContain("$x^2$");
    await hook.el.__mathPending;
    expect(hook.el.querySelectorAll(".katex")).toHaveLength(2);
    expect(hook.el.querySelector(".katex-display")).not.toBeNull();
  });

  it("renders the latest response instead of restoring stale text when loading finishes", async () => {
    const hook = mount("Old $x^2$");
    const pending = hook.el.__mathPending;
    hook.el.dataset.md = "New **response**";
    Markdown.updated.call(hook);
    await pending;
    expect(hook.el.textContent.trim()).toBe("New response");
    expect(hook.el.querySelector(".katex")).toBeNull();
  });

  it("does not mutate a destroyed Markdown hook when loading completes", async () => {
    const hook = mount("Formula $x^2$");
    Markdown.destroyed.call(hook);
    const before = hook.el.innerHTML;
    await hook.el.__mathPending;
    expect(hook.el.innerHTML).toBe(before);
  });

  it("leaves a readable response when the math chunk fails", async () => {
    vi.doMock("katex", () => {throw new Error("Download failed");});
    vi.spyOn(console, "warn").mockImplementation(() => {});
    const hook = mount("Still readable: $x^2$");
    await hook.el.__mathPending;
    expect(hook.el.textContent.trim()).toBe("Still readable: $x^2$");
    expect(hook.el.__mathPending).toBeNull();
  });
});

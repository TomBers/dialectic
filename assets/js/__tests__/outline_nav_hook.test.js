import { beforeEach, describe, expect, it, vi } from "vitest";
import OutlineNavHook from "../outline_nav_hook.js";

describe("OutlineNavHook", () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <div id="outline-scroll-shell">
        <aside id="outline-tree">
          <a id="outline-node-13" data-outline-selected="true">Selected</a>
        </aside>
      </div>
    `;
    vi.stubGlobal("requestAnimationFrame", (callback) => callback());
  });

  it("centers the selected row by scrolling only the outline", () => {
    const shell = document.getElementById("outline-scroll-shell");
    const outline = document.getElementById("outline-tree");
    const selected = document.getElementById("outline-node-13");

    shell.scrollTop = 0;
    outline.scrollTop = 100;
    Object.defineProperty(outline, "clientHeight", { value: 400 });
    outline.getBoundingClientRect = () => ({ top: 100 });
    selected.getBoundingClientRect = () => ({
      top: 500 - (outline.scrollTop - 100),
      height: 40,
    });
    selected.scrollIntoView = vi.fn();

    const hook = { ...OutlineNavHook, el: outline };
    hook.mounted();

    expect(outline.scrollTop).toBe(320);
    expect(shell.scrollTop).toBe(0);
    expect(selected.scrollIntoView).not.toHaveBeenCalled();
  });
});

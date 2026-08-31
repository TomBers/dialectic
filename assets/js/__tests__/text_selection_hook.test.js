import { beforeEach, describe, expect, it, vi } from "vitest";
import TextSelectionHook from "../text_selection_hook.js";

describe("TextSelectionHook highlight scrolling", () => {
  beforeEach(() => {
    document.body.innerHTML = `
      <div id="outline-layout" data-reduce-motion="true">
        <div id="scroll-container">
          <span id="highlight">Highlighted text</span>
        </div>
      </div>
    `;
  });

  it("uses instant document scrolling when reduced motion is enabled", () => {
    const span = document.getElementById("highlight");
    span.scrollIntoView = vi.fn();

    const hook = {
      ...TextSelectionHook,
      findScrollContainer: vi.fn(() => null),
    };

    hook.scrollHighlightIntoView(span);

    expect(span.scrollIntoView).toHaveBeenCalledWith({
      behavior: "auto",
      block: "center",
    });
  });

  it("uses instant container scrolling when reduced motion is enabled", () => {
    const container = document.getElementById("scroll-container");
    const span = document.getElementById("highlight");

    container.scrollTop = 40;
    container.getBoundingClientRect = () => ({ top: 100, height: 200 });
    container.scrollTo = vi.fn();
    span.getBoundingClientRect = () => ({ top: 250, height: 20 });

    const hook = {
      ...TextSelectionHook,
      findScrollContainer: vi.fn(() => container),
    };

    hook.scrollHighlightIntoView(span);

    expect(container.scrollTo).toHaveBeenCalledWith({
      top: 100,
      behavior: "auto",
    });
  });
});

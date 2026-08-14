import { describe, it, expect, vi } from "vitest";
import Markdown from "../markdown_hook.js";

function markdownElement() {
  const element = document.createElement("div");
  element.id = "outline-markdown-body-test";
  element.setAttribute(
    "data-md",
    "# Node title\n\nOpening paragraph.\n\n## A section\n\nRendered text.",
  );
  element.setAttribute("data-body-only", "true");
  element.setAttribute("data-enhance-follow-up-questions", "false");
  element.innerHTML = `
    <div data-role="server-markdown-fallback" class="whitespace-pre-wrap">
      Opening paragraph.\n\n## A section\n\nRendered text.
    </div>`;
  document.body.replaceChildren(element);
  return element;
}

describe("Markdown hook LiveView updates", () => {
  it("rerenders when LiveView restores the server fallback with unchanged Markdown", () => {
    const element = markdownElement();
    const hook = { el: element, pushEvent: vi.fn() };

    Markdown.mounted.call(hook);

    expect(element.querySelector('[data-role="server-markdown-fallback"]')).toBeNull();
    expect(element.querySelector("h2").textContent).toBe("A section");

    element.innerHTML = `
      <div data-role="server-markdown-fallback" class="whitespace-pre-wrap">
        Opening paragraph.\n\n## A section\n\nRendered text.
      </div>`;

    Markdown.updated.call(hook);

    expect(element.querySelector('[data-role="server-markdown-fallback"]')).toBeNull();
    expect(element.querySelector("h2").textContent).toBe("A section");
    expect(element.textContent).not.toContain("## A section");
  });
});

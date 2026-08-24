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
  it("preserves the first section heading in body-only mode", () => {
    const element = markdownElement();
    element.setAttribute(
      "data-md",
      "# Related ideas\n\n## A surprising connection\n\nUseful detail.",
    );
    const hook = { el: element, pushEvent: vi.fn() };

    Markdown.mounted.call(hook);

    expect(element.querySelector("h1")).toBeNull();
    expect(element.querySelector("h2")?.textContent).toBe(
      "A surprising connection",
    );
  });

  it("removes a duplicate heading after the title", () => {
    const element = markdownElement();
    element.setAttribute(
      "data-md",
      "# Related ideas\n\n## Related ideas\n\nUseful detail.",
    );
    const hook = { el: element, pushEvent: vi.fn() };

    Markdown.mounted.call(hook);

    expect(element.querySelector("h1, h2")).toBeNull();
    expect(element.textContent).toContain("Useful detail.");
  });

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

  it("rerenders when grounding metadata arrives after streamed content", () => {
    const element = markdownElement();
    const hook = { el: element, pushEvent: vi.fn() };

    Markdown.mounted.call(hook);
    expect(element.querySelector(".markdown-source-reference")).toBeNull();

    element.setAttribute(
      "data-grounding",
      JSON.stringify({
        google: {
          groundingChunks: [
            {
              web: {
                title: "Research",
                uri: "https://example.com/research",
              },
            },
          ],
          groundingSupports: [
            {
              groundingChunkIndices: [0],
              segment: {
                text: "Opening paragraph. A section Rendered text.",
                startIndex: 14,
                endIndex: 58,
              },
            },
          ],
        },
      }),
    );

    Markdown.updated.call(hook);

    expect(element.querySelector(".markdown-source-reference")).not.toBeNull();
    expect(element.querySelector(".markdown-source-link").textContent).toContain(
      "Research",
    );
  });
});

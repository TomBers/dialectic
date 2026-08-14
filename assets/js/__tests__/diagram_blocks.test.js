import { describe, it, expect } from "vitest";
import { removeDiagramBlocks } from "../markdown_hook.js";

function rootWith(content) {
  const root = document.createElement("div");
  root.innerHTML = `<pre><code>${content}</code></pre>`;
  document.body.replaceChildren(root);
  return root;
}

const diagram = `
┌───────────────┐
│ Central idea  │
└───────┬───────┘
        ▼
┌───────────────┐
│ Related idea  │
└───────────────┘`;

describe("removeDiagramBlocks", () => {
  it("removes box-drawing diagrams", () => {
    const root = rootWith(diagram);

    removeDiagramBlocks(root);

    expect(root.querySelector("pre")).toBeNull();
    expect(root.textContent).not.toContain("Central idea");
  });

  it("does not alter ordinary code blocks", () => {
    const root = rootWith("const answer = 42;\nconsole.log(answer);");

    removeDiagramBlocks(root);

    expect(root.querySelector("pre")).not.toBeNull();
    expect(root.textContent).toContain("const answer = 42");
  });
});

import { describe, expect, it } from "vitest";
import { enhanceBlockquoteAttributions } from "../markdown_hook.js";

function rootWith(html) {
  const root = document.createElement("div");
  root.innerHTML = html;
  return root;
}

describe("enhanceBlockquoteAttributions", () => {
  it("leaves inline emphasis inside a quote untouched", () => {
    const root = rootWith(`
      <blockquote>
        <p>The world appears superfluous (<em>de trop</em>).</p>
      </blockquote>
    `);

    enhanceBlockquoteAttributions(root);

    expect(root.querySelector("p").classList).not.toContain(
      "quote-attribution",
    );
  });

  it("marks a fully emphasized attribution line", () => {
    const root = rootWith(`
      <blockquote>
        <p>A quotation.</p>
        <p><em>— Martin Buber, I and Thou</em></p>
      </blockquote>
    `);

    enhanceBlockquoteAttributions(root);

    expect(root.querySelector("p:last-child").classList).toContain(
      "quote-attribution",
    );
  });

  it("does not treat fully emphasized prose as an attribution", () => {
    const root = rootWith(`
      <blockquote><p><em>An entirely emphasized quotation.</em></p></blockquote>
    `);

    enhanceBlockquoteAttributions(root);

    expect(root.querySelector("p").classList).not.toContain(
      "quote-attribution",
    );
  });
});

import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { initDisclosureNavigation } from "../disclosure_navigation.js";

let destroy;

beforeEach(() => {
  document.body.innerHTML = `
    <article id="ai-assistants-feature">
      <details id="feature-setup-cursor"><summary>Cursor</summary><p>Setup steps</p></details>
      <details id="feature-tool-directory"><summary>All tools</summary>
        <dl><div id="feature-tool-export_grid"><dt>Export</dt><dd>Saved content</dd></div></dl>
      </details>
    </article>`;
  document.querySelectorAll("[id]").forEach((element) => {
    element.scrollIntoView = vi.fn();
  });
});

afterEach(() => {
  destroy?.();
  window.history.replaceState(null, "", "/features/ai-assistants");
});

it("opens a direct link to an assistant guide and focuses its control", () => {
  window.history.replaceState(null, "", "/features/ai-assistants#feature-setup-cursor");
  destroy = initDisclosureNavigation(document.getElementById("ai-assistants-feature"));
  expect(document.getElementById("feature-setup-cursor").open).toBe(true);
  expect(document.getElementById("feature-tool-directory").open).toBe(false);
  expect(document.activeElement).toBe(document.querySelector("#feature-setup-cursor > summary"));
});

it("reveals a linked tool inside the closed reference and moves focus to it", () => {
  window.history.replaceState(null, "", "/features/ai-assistants#feature-tool-export_grid");
  destroy = initDisclosureNavigation(document.getElementById("ai-assistants-feature"));
  expect(document.getElementById("feature-tool-directory").open).toBe(true);
  expect(document.activeElement.id).toBe("feature-tool-export_grid");
  expect(document.activeElement.scrollIntoView).toHaveBeenCalledWith({ block: "start" });
});

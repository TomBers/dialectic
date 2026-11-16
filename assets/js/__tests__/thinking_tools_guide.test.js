import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { initThinkingToolsGuide } from "../thinking_tools_guide.js";

let destroy;

beforeEach(() => {
  window.history.replaceState(null, "", "/features/thinking-tools");
  document.body.innerHTML = `
    <article id="thinking-tools-guide">
      <a id="start" href="/features/thinking-tools#clarify">Start here</a>
      <details id="understand" name="thinking-goal" data-thinking-goal>
        <summary>Understand</summary>
        <article id="clarify" tabindex="-1" data-thinking-tool>
          <details id="thinking-example-clarify"><summary>Clarify</summary><p>An example</p></details>
        </article>
      </details>
      <details id="challenge" name="thinking-goal" data-thinking-goal>
        <summary>Challenge</summary>
        <article id="says_who" tabindex="-1" data-thinking-tool>
          <details id="thinking-example-says_who"><summary>Evidence</summary><p>An example</p></details>
        </article>
      </details>
    </article>
    <details id="outside"><summary>Unrelated</summary></details>`;
  document.querySelectorAll("[id]").forEach((element) => {
    element.scrollIntoView = vi.fn();
  });
});

afterEach(() => {
  destroy?.();
  destroy = undefined;
  vi.restoreAllMocks();
});

it("keeps the initial choice small until a reader chooses a goal", () => {
  destroy = initThinkingToolsGuide();
  expect(document.querySelectorAll("[data-thinking-goal][open]")).toHaveLength(0);
});

it("opens a directly linked tool and its group, then focuses the destination", () => {
  window.history.replaceState(null, "", "#says_who");
  destroy = initThinkingToolsGuide();
  expect(document.getElementById("challenge").open).toBe(true);
  expect(document.getElementById("thinking-example-says_who").open).toBe(true);
  expect(document.getElementById("understand").open).toBe(false);
  expect(document.activeElement.id).toBe("says_who");
});

it("follows fragment navigation between tools and whole groups", () => {
  window.history.replaceState(null, "", "#says_who");
  destroy = initThinkingToolsGuide();
  window.history.replaceState(null, "", "#understand");
  window.dispatchEvent(new HashChangeEvent("hashchange"));
  expect(document.getElementById("understand").open).toBe(true);
  expect(document.getElementById("challenge").open).toBe(false);
  expect(document.activeElement).toBe(document.querySelector("#understand > summary"));
});

it("reopens a closed tool when the reader follows the same link again", () => {
  window.history.replaceState(null, "", "#clarify");
  destroy = initThinkingToolsGuide();
  document.getElementById("understand").open = false;
  document.getElementById("thinking-example-clarify").open = false;
  const click = new MouseEvent("click", { bubbles: true, cancelable: true, button: 0 });
  document.getElementById("start").dispatchEvent(click);
  expect(document.getElementById("understand").open).toBe(true);
  expect(document.getElementById("thinking-example-clarify").open).toBe(true);
  expect(click.defaultPrevented).toBe(false);
});

it("ignores unknown or malformed fragments and targets outside the guide", () => {
  destroy = initThinkingToolsGuide();
  for (const hash of ["#missing", "#%E0%A4%A", "#outside"]) {
    window.history.replaceState(null, "", hash);
    window.dispatchEvent(new HashChangeEvent("hashchange"));
  }
  expect(document.querySelectorAll("details[open]")).toHaveLength(0);
});

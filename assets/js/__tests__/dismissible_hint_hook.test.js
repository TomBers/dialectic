import { afterEach, beforeEach, describe, expect, it } from "vitest";
import DismissibleHintHook from "../dismissible_hint_hook.js";

const STORAGE_KEY = "rg:dismissed:branch-from-text:test";
let hook;

function mountHook() {
  document.body.innerHTML = `
    <div id="branch-hint" data-dismiss-key="${STORAGE_KEY}" hidden>
      <button type="button" data-dismiss-hint>Dismiss</button>
    </div>
  `;

  hook = Object.create(DismissibleHintHook);
  hook.el = document.querySelector("#branch-hint");
  hook.mounted();
  return hook;
}

beforeEach(() => {
  localStorage.clear();
});

afterEach(() => {
  hook?.destroyed();
  hook = null;
  localStorage.clear();
  document.body.replaceChildren();
});

describe("DismissibleHintHook", () => {
  it("reveals a hint when no dismissal has been stored", () => {
    const instance = mountHook();

    expect(instance.el.hidden).toBe(false);
  });

  it("stores dismissal and hides the hint", () => {
    const instance = mountHook();

    instance.el.querySelector("[data-dismiss-hint]").click();

    expect(instance.el.hidden).toBe(true);
    expect(localStorage.getItem(STORAGE_KEY)).toBe("dismissed");
  });

  it("keeps a previously dismissed hint hidden on a later mount", () => {
    localStorage.setItem(STORAGE_KEY, "dismissed");

    const instance = mountHook();

    expect(instance.el.hidden).toBe(true);
  });
});

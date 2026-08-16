import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import GenerationStatusHook, {
  DETAIL_DELAY_MS,
  FINISHING_DELAY_MS,
} from "../generation_status_hook.js";

let hook;

function mountHook(responseLevel) {
  document.body.innerHTML = `
    <div id="generation-status" data-response-level="${responseLevel}">
      <span data-generation-status>Server fallback</span>
    </div>
  `;

  hook = Object.create(GenerationStatusHook);
  hook.el = document.querySelector("#generation-status");
  hook.mounted();
  return hook.el.querySelector("[data-generation-status]");
}

beforeEach(() => {
  vi.useFakeTimers();
});

afterEach(() => {
  hook?.destroyed();
  hook = null;
  document.body.replaceChildren();
  vi.useRealTimers();
});

describe("GenerationStatusHook", () => {
  it("shows staged Expert progress without a fake percentage", () => {
    const status = mountHook("expert");

    expect(status.textContent).toBe("Preparing response");

    vi.advanceTimersByTime(DETAIL_DELAY_MS);
    expect(status.textContent).toBe("Comparing evidence and perspectives");

    vi.advanceTimersByTime(FINISHING_DELAY_MS - DETAIL_DELAY_MS);
    expect(status.textContent).toBe("Finishing response");
  });

  it("uses source-oriented copy for Detailed responses", () => {
    const status = mountHook("university");

    vi.advanceTimersByTime(DETAIL_DELAY_MS);
    expect(status.textContent).toBe("Checking relevant sources");
  });

  it("uses concise copy for Standard responses", () => {
    const status = mountHook("high_school");

    vi.advanceTimersByTime(DETAIL_DELAY_MS);
    expect(status.textContent).toBe("Writing a clear response");
  });

  it("clears timers when the placeholder is removed", () => {
    const status = mountHook("expert");
    hook.destroyed();

    vi.advanceTimersByTime(FINISHING_DELAY_MS);
    expect(status.textContent).toBe("Preparing response");
  });
});

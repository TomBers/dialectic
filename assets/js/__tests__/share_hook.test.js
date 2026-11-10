import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import ShareHook from "../share_hook.js";

const url = "https://rationalgrid.ai/g/a-grid?node=2";

function mountShare() {
  document.body.innerHTML = `
    <div role="dialog" id="share-modal-hook">
      <input data-share-link-input readonly value="${url}">
      <button data-share-copy="${url}" data-share-toast="Link copied!">
        <span data-copy-icon></span><span data-copy-check class="hidden"></span>
        <span data-copy-label>Copy link</span>
      </button>
      <div data-native-share-container hidden>
        <button data-native-share data-share-title="A grid" data-share-text="Explore this" data-share-url="${url}"></button>
      </div>
      <p id="share-feedback" role="status"></p>
    </div>`;
  const hook = { ...ShareHook, el: document.getElementById("share-modal-hook") };
  hook.mounted();
  return hook;
}

beforeEach(() => {
  vi.useFakeTimers();
  vi.stubGlobal("navigator", { clipboard: { writeText: vi.fn().mockResolvedValue() } });
});

afterEach(() => {
  vi.clearAllTimers();
  vi.useRealTimers();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
  delete document.execCommand;
  document.body.innerHTML = "";
});

describe("grid sharing controls", () => {
  it("copies the current link and clears stale feedback when the target changes", async () => {
    const hook = mountShare();
    const button = hook.el.querySelector("[data-share-copy]");
    await hook._copyAndNotify(url, "Link copied!", button);
    expect(navigator.clipboard.writeText).toHaveBeenCalledWith(url);
    expect(button.querySelector("[data-copy-label]").textContent).toBe("Copied");
    expect(hook.el.querySelector("#share-feedback").textContent).toBe("Link copied!");

    button.dataset.shareCopy = url + "&path=3";
    hook.updated();
    expect(hook.el.querySelector("[data-share-link-input]").value).toBe(url + "&path=3");
    expect(button.querySelector("[data-copy-label]").textContent).toBe("Copy link");
    expect(hook.el.querySelector("#share-feedback").textContent).toBe("");
  });

  it("reports failed copying and selects the link for manual copying", async () => {
    navigator.clipboard.writeText.mockRejectedValue(new Error("Denied"));
    document.execCommand = vi.fn(() => false);
    const hook = mountShare();
    const input = hook.el.querySelector("[data-share-link-input]");
    const button = hook.el.querySelector("[data-share-copy]");
    await hook._copyAndNotify(url, "Link copied!", button);
    expect(hook.el.querySelector("#share-feedback").dataset.state).toBe("error");
    expect(hook.el.querySelector("#share-feedback").textContent).toContain("Could not copy");
    expect(document.activeElement).toBe(input);
    expect(input.selectionEnd - input.selectionStart).toBe(url.length);
    expect(button.querySelector("[data-copy-label]").textContent).toBe("Copy link");
  });

  it("keeps the selection-based clipboard fallback inside the active dialog", async () => {
    navigator.clipboard.writeText.mockRejectedValue(new Error("Denied"));
    const hook = mountShare();
    const button = hook.el.querySelector("[data-share-copy]");
    button.focus();
    document.execCommand = vi.fn(() => {
      expect(hook.el.contains(document.activeElement)).toBe(true);
      return true;
    });
    await hook._copyAndNotify(url, "Link copied!", button);
    expect(hook.el.querySelector("#share-feedback").dataset.state).toBe("success");
    expect(document.activeElement).toBe(button);
  });

  it("hides unsupported device sharing and uses the latest link when supported", async () => {
    const hook = mountShare();
    const container = hook.el.querySelector("[data-native-share-container]");
    expect(container.hidden).toBe(true);
    navigator.share = vi.fn().mockResolvedValue();
    navigator.canShare = vi.fn(() => true);
    hook.updated();
    expect(container.hidden).toBe(false);
    const button = hook.el.querySelector("[data-native-share]");
    button.dataset.shareUrl = url + "&path=3";
    button.click();
    await vi.waitFor(() => expect(button.disabled).toBe(false));
    expect(navigator.share).toHaveBeenCalledWith(expect.objectContaining({ url: url + "&path=3" }));
    navigator.canShare.mockReturnValue(false);
    hook.updated();
    expect(container.hidden).toBe(true);
  });

  it("treats cancellation quietly and reports other device sharing errors", async () => {
    navigator.share = vi.fn().mockRejectedValue(new DOMException("Cancelled", "AbortError"));
    const hook = mountShare();
    const button = hook.el.querySelector("[data-native-share]");
    button.click();
    await vi.waitFor(() => expect(button.disabled).toBe(false));
    expect(hook.el.querySelector("#share-feedback").textContent).toBe("");
    navigator.share.mockRejectedValue(new Error("Unavailable"));
    button.click();
    await vi.waitFor(() => expect(button.disabled).toBe(false));
    expect(hook.el.querySelector("#share-feedback").textContent).toContain("Copy the link");
  });
});

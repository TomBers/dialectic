import { afterEach, beforeEach, describe, expect, it } from "vitest";
import YouTubeFacadeHook from "../youtube_facade_hook.js";

let hook;

function mountHook() {
  document.body.innerHTML = `
    <div
      id="video"
      data-video-id="video/id"
      data-video-title="Product walkthrough"
    >
      <img src="/images/preview.webp" alt="Preview">
      <button type="button">Play</button>
    </div>
  `;

  hook = Object.create(YouTubeFacadeHook);
  hook.el = document.querySelector("#video");
  hook.mounted();
  return hook;
}

beforeEach(() => {
  mountHook();
});

afterEach(() => {
  hook?.destroyed();
  hook = null;
  document.body.replaceChildren();
});

describe("YouTubeFacadeHook", () => {
  it("loads a configured privacy-enhanced iframe after activation", () => {
    hook.playButton.click();

    const iframe = hook.el.querySelector("iframe");
    expect(iframe).not.toBeNull();
    expect(iframe.src).toBe(
      "https://www.youtube-nocookie.com/embed/video%2Fid?autoplay=1",
    );
    expect(iframe.title).toBe("Product walkthrough");
    expect(iframe.referrerPolicy).toBe("strict-origin-when-cross-origin");
    expect(iframe.allow).toContain("autoplay");
    expect(iframe.allowFullscreen).toBe(true);
    expect(hook.el.querySelector("button")).toBeNull();
  });

  it("removes the activation listener when destroyed before playback", () => {
    const playButton = hook.playButton;
    hook.destroyed();

    playButton.click();

    expect(hook.el.querySelector("iframe")).toBeNull();
    expect(hook.el.querySelector("button")).toBe(playButton);
  });
});

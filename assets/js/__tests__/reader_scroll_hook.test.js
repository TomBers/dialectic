import { afterEach, describe, expect, it, vi } from "vitest";
import ReaderScrollHook from "../reader_scroll_hook.js";

afterEach(() => {
  vi.unstubAllGlobals();
  window.history.replaceState({}, "", "/");
});

describe("ReaderScrollHook", () => {
  it("updates the viewed node and URL as document sections scroll", () => {
    document.body.innerHTML = `
      <main id="reader">
        <article id="reading-node-1"></article>
        <article id="reading-node-2"></article>
        <article id="reading-node-3"></article>
      </main>
    `;
    const element = document.getElementById("reader");
    const frames = [];
    const pushEvent = vi.fn();
    vi.stubGlobal("requestAnimationFrame", (callback) => {
      frames.push(callback);
      return frames.length;
    });
    window.history.replaceState({}, "", "/g/example?token=shared");

    element.getBoundingClientRect = () => ({ top: 0, bottom: 600, height: 600 });
    document.getElementById("reading-node-1").getBoundingClientRect = () => ({
      top: -220,
      bottom: 80,
    });
    document.getElementById("reading-node-2").getBoundingClientRect = () => ({
      top: 80,
      bottom: 380,
    });
    document.getElementById("reading-node-3").getBoundingClientRect = () => ({
      top: 380,
      bottom: 680,
    });

    const hook = { ...ReaderScrollHook, el: element, pushEvent };
    hook.mounted();
    element.dispatchEvent(new Event("scroll"));
    frames.shift()();

    expect(pushEvent).toHaveBeenCalledWith("reader_node_viewed", { id: "2" });
    expect(new URL(window.location.href).searchParams.get("node")).toBe("2");
    expect(new URL(window.location.href).searchParams.get("token")).toBe("shared");
  });

  it("jumps to a node selected explicitly from the outline", () => {
    document.body.innerHTML = `
      <main id="reader">
        <article id="reading-node-2"></article>
      </main>
    `;
    const element = document.getElementById("reader");
    const section = document.getElementById("reading-node-2");
    const frames = [];
    let scrollHandler;

    element.scrollTop = 200;
    element.getBoundingClientRect = () => ({ top: 100 });
    section.getBoundingClientRect = () => ({ top: 500, bottom: 700 });
    vi.stubGlobal("requestAnimationFrame", (callback) => {
      frames.push(callback);
      return frames.length;
    });

    const hook = {
      ...ReaderScrollHook,
      el: element,
      handleEvent: (event, callback) => {
        if (event === "scroll_to_reader_node") scrollHandler = callback;
      },
    };
    hook.mounted();
    scrollHandler({ id: "2" });
    frames.shift()();
    frames.shift()();

    expect(element.scrollTop).toBe(576);
    expect(hook.activeNodeId).toBe("2");
  });

  it("does not sync sections during highlight navigation and syncs when it completes", () => {
    document.body.innerHTML = `
      <main id="reader">
        <article id="reading-node-2"></article>
      </main>
    `;
    const element = document.getElementById("reader");
    const section = document.getElementById("reading-node-2");
    const frames = [];
    const pushEvent = vi.fn();

    element.getBoundingClientRect = () => ({ top: 0, bottom: 600, height: 600 });
    section.getBoundingClientRect = () => ({ top: 80, bottom: 380 });
    vi.stubGlobal("requestAnimationFrame", (callback) => {
      frames.push(callback);
      return frames.length;
    });

    const hook = { ...ReaderScrollHook, el: element, pushEvent };
    hook.mounted();
    window.__pendingHighlightScrollRequest = { status: "scrolling" };

    element.dispatchEvent(new Event("scroll"));
    expect(frames).toHaveLength(0);
    expect(pushEvent).not.toHaveBeenCalled();

    window.__pendingHighlightScrollRequest = { status: "handled" };
    element.dispatchEvent(new CustomEvent("highlight-scroll-complete"));

    expect(pushEvent).toHaveBeenCalledWith("reader_node_viewed", { id: "2" });
    delete window.__pendingHighlightScrollRequest;
  });

  it("preserves a visible document section as the scroll anchor", () => {
    document.body.innerHTML = `
      <main id="reader">
        <article id="reading-node-2"></article>
      </main>
    `;
    const element = document.getElementById("reader");
    const section = document.getElementById("reading-node-2");
    const frames = [];
    let sectionTop = 150;

    element.getBoundingClientRect = () => ({ top: 100 });
    section.getBoundingClientRect = () => ({ top: sectionTop, bottom: sectionTop + 100 });
    vi.stubGlobal("requestAnimationFrame", (callback) => frames.push(callback));

    const hook = { ...ReaderScrollHook, el: element };
    element.scrollTop = 420;
    hook.mounted();
    hook.beforeUpdate();

    sectionTop = 220;
    element.scrollTop = 0;
    hook.updated();
    frames[0]();

    expect(element.scrollTop).toBe(490);
  });

  it("restores the reader viewport after a LiveView patch", () => {
    document.body.innerHTML = '<main id="reader"></main>';
    const element = document.getElementById("reader");
    const frames = [];
    vi.stubGlobal("requestAnimationFrame", (callback) => frames.push(callback));

    const hook = { ...ReaderScrollHook, el: element };
    element.scrollTop = 420;
    element.scrollLeft = 12;
    hook.mounted();
    hook.beforeUpdate();

    element.scrollTop = 0;
    element.scrollLeft = 0;
    hook.updated();

    expect(element.scrollTop).toBe(420);
    expect(element.scrollLeft).toBe(12);

    element.scrollTop = 5;
    frames[0]();
    expect(element.scrollTop).toBe(420);
  });
});

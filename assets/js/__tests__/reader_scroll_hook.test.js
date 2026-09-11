import { afterEach, describe, expect, it, vi } from "vitest";
import ReaderScrollHook from "../reader_scroll_hook.js";

afterEach(() => {
  vi.unstubAllGlobals();
  sessionStorage.clear();
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

  it("moves focus for keyboard path navigation but leaves pointer focus alone", () => {
    document.body.innerHTML = `
      <div id="outline-layout">
        <a id="path-choice" data-phx-link="patch" href="/?node=2">Read this path</a>
        <main id="reader" data-reader-scroll-key="reader-position:test" data-selected-reader-node-id="2">
          <article id="reading-node-2" tabindex="-1"></article>
        </main>
      </div>`;
    vi.stubGlobal("requestAnimationFrame", (callback) => { callback(); return 1; });
    const hook = {...ReaderScrollHook, el: document.getElementById("reader")};
    hook.mounted();
    const link = document.getElementById("path-choice");
    link.addEventListener("click", (event) => event.preventDefault());
    link.focus();
    link.dispatchEvent(new MouseEvent("click", {bubbles: true, cancelable: true, detail: 1}));
    hook.scrollToNode("2");
    expect(document.activeElement).toBe(link);
    link.dispatchEvent(new MouseEvent("click", {bubbles: true, cancelable: true, detail: 0}));
    expect(window.history.state.readerReturnFocus.nodeId).toBe("2");
    hook.scrollToNode("2");
    expect(document.activeElement.id).toBe("reading-node-2");
    window.dispatchEvent(new PopStateEvent("popstate", {state: window.history.state}));
    hook.beforeUpdate();
    hook.updated();
    expect(document.activeElement).toBe(link);
    hook.destroyed();
  });

  it.each(["/?node=2", "/g/example"])("restores focus when Back remounts the reader at %s", (url) => {
    window.history.replaceState({readerReturnFocus: {key: "reader-position:test", id: "return-link", nodeId: "2"}}, "", url);
    document.body.innerHTML = `<div id="outline-tree"><a href="/?node=3" id="return-link">Path</a></div>
      <main id="reader" data-reader-scroll-key="reader-position:test" data-selected-reader-node-id="2">
        <article id="reading-node-2" tabindex="-1"></article>
      </main>`;
    const frames = [];
    vi.stubGlobal("requestAnimationFrame", (callback) => { frames.push(callback); return frames.length; });
    const hook = {...ReaderScrollHook, el: document.getElementById("reader")};
    hook.mounted();
    while (frames.length) frames.shift()();
    expect(document.activeElement.id).toBe("return-link");
    hook.destroyed();
  });

  it("opens at the node requested by the URL on a fresh page load", () => {
    document.body.innerHTML = `
      <main id="reader" data-reader-scroll-key="reader-position:example" data-selected-reader-node-id="9">
        <article id="reading-node-2"></article>
        <article id="reading-node-9"></article>
      </main>
    `;
    const element = document.getElementById("reader");
    const target = document.getElementById("reading-node-9");
    const frames = [];

    element.scrollTop = 0;
    element.getBoundingClientRect = () => ({ top: 100, bottom: 700, height: 600 });
    target.getBoundingClientRect = () => ({ top: 900, bottom: 1200 });
    vi.stubGlobal("requestAnimationFrame", (callback) => {
      frames.push(callback);
      return frames.length;
    });

    const hook = { ...ReaderScrollHook, el: element };
    hook.mounted();
    frames.shift()();
    frames.shift()();
    frames.shift()();

    expect(element.scrollTop).toBe(776);
    expect(hook.activeNodeId).toBe("9");
    expect(element.dataset.readerScrollRestoring).toBe("false");
  });

  it("restores the reader position after navigating to grid mode", () => {
    document.body.innerHTML = `
      <main id="reader" data-reader-scroll-key="reader-position:example" data-selected-reader-node-id="2">
        <article id="reading-node-2"></article>
        <a id="open-grid" data-view-transition-direction="graph"></a>
      </main>
    `;
    const element = document.getElementById("reader");
    const section = document.getElementById("reading-node-2");
    const frames = [];
    let sectionTop = 150;

    element.getBoundingClientRect = () => ({ top: 100, bottom: 700, height: 600 });
    section.getBoundingClientRect = () => ({ top: sectionTop, bottom: sectionTop + 300 });
    vi.stubGlobal("requestAnimationFrame", (callback) => {
      frames.push(callback);
      return frames.length;
    });

    const departingHook = { ...ReaderScrollHook, el: element };
    element.scrollTop = 420;
    element.scrollLeft = 8;
    departingHook.mounted();
    document.getElementById("open-grid").click();
    departingHook.destroyed();

    expect(sessionStorage.getItem("reader-position:example:restore")).toBe("true");

    element.scrollTop = 0;
    element.scrollLeft = 0;
    sectionTop = 220;
    const returningHook = { ...ReaderScrollHook, el: element };
    returningHook.mounted();
    frames.shift()();
    frames.shift()();

    expect(element.scrollTop).toBe(490);
    expect(element.scrollLeft).toBe(8);
    expect(element.dataset.readerScrollRestoring).toBe("false");
    expect(sessionStorage.getItem("reader-position:example:restore")).toBeNull();
  });

  it("uses the current reader URL node when switching immediately to grid mode", () => {
    document.body.innerHTML = `
      <main id="reader" data-reader-scroll-key="reader-position:example" data-selected-reader-node-id="2">
        <article id="reading-node-2"></article>
        <a id="open-grid" href="/g/example/graph?node=1" data-view-transition-direction="graph">Grid</a>
      </main>
    `;
    const element = document.getElementById("reader");
    const section = document.getElementById("reading-node-2");
    const graphLink = document.getElementById("open-grid");

    element.getBoundingClientRect = () => ({ top: 0, bottom: 600, height: 600 });
    section.getBoundingClientRect = () => ({ top: 40, bottom: 340 });
    window.history.replaceState({}, "", "/g/example?node=11");

    const hook = { ...ReaderScrollHook, el: element };
    hook.mounted();
    graphLink.dispatchEvent(new MouseEvent("click", { bubbles: true }));

    expect(new URL(graphLink.href).searchParams.get("node")).toBe("11");
    hook.destroyed();
  });

  it("opens the newly selected grid node instead of restoring an older reader node", () => {
    document.body.innerHTML = `
      <main id="reader" data-reader-scroll-key="reader-position:example" data-selected-reader-node-id="3">
        <article id="reading-node-2"></article>
        <article id="reading-node-3"></article>
      </main>
    `;
    const element = document.getElementById("reader");
    const target = document.getElementById("reading-node-3");
    const frames = [];

    element.scrollTop = 0;
    element.getBoundingClientRect = () => ({ top: 100, bottom: 700, height: 600 });
    target.getBoundingClientRect = () => ({ top: 900, bottom: 1200 });
    vi.stubGlobal("requestAnimationFrame", (callback) => {
      frames.push(callback);
      return frames.length;
    });
    sessionStorage.setItem(
      "reader-position:example",
      JSON.stringify({ top: 420, left: 0, nodeId: "2" }),
    );
    sessionStorage.setItem("reader-position:example:restore", "true");

    const hook = { ...ReaderScrollHook, el: element };
    hook.mounted();
    frames.shift()();
    frames.shift()();

    expect(element.scrollTop).toBe(776);
    expect(hook.activeNodeId).toBe("3");
    expect(sessionStorage.getItem("reader-position:example:restore")).toBeNull();
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

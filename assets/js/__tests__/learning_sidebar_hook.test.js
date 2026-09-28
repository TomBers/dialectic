import { afterEach, describe, expect, it, vi } from "vitest";
import LearningSidebar from "../learning_sidebar_hook.js";

let hook;
let media;
const byId = (id) => document.getElementById(id);

function setup(desktop = false) {
  document.body.innerHTML = `
    <header id="site-header"><a href="/">Home</a></header>
    <main>
      <header><button id="learning-browse-toggle">Browse</button></header>
      <div>
        <div id="learning-sidebar-shell">
          <div id="learning-sidebar-controller"></div>
          <div id="learning-sidebar-backdrop"></div>
          <aside id="learning-sidebar">
            <button id="learning-browse-close">Close</button>
            <button id="expand-folder">Expand folder</button>
            <a id="collection" href="/my/learning?collection=13">Economics</a>
            <form id="new-collection"><input id="collection-name" /></form>
          </aside>
        </div>
        <section id="results"><input id="search" /></section>
      </div>
    </main>`;
  media = new EventTarget();
  media.matches = desktop;
  vi.stubGlobal("matchMedia", vi.fn(() => media));
  hook = Object.create(LearningSidebar);
  hook.el = byId("learning-sidebar-controller");
  hook.js = () => ({ ignoreAttributes: vi.fn() });
  hook.mounted();
}

function resize(desktop) {
  media.matches = desktop;
  media.dispatchEvent(new Event("change"));
}

function open() {
  byId("learning-browse-toggle").click();
}

afterEach(() => {
  hook?.destroyed();
  hook = null;
  document.body.replaceChildren();
  vi.unstubAllGlobals();
});

describe("mobile learning sidebar", () => {
  it("opens as a modal and restores focus and access to results on close", () => {
    setup();
    expect(byId("learning-sidebar").inert).toBe(true);
    open();
    expect(byId("learning-sidebar").getAttribute("role")).toBe("dialog");
    expect(byId("learning-sidebar").inert).toBe(false);
    expect(byId("results").inert).toBe(true);
    expect(byId("site-header").inert).toBe(true);
    expect(document.activeElement).toBe(byId("learning-browse-close"));
    expect(document.documentElement.classList.contains("learning-sidebar-open")).toBe(true);
    byId("learning-browse-close").click();
    expect(byId("learning-browse-toggle").getAttribute("aria-expanded")).toBe("false");
    expect(byId("results").inert).toBeFalsy();
    expect(byId("site-header").inert).toBeFalsy();
    expect(document.activeElement).toBe(byId("learning-browse-toggle"));
    expect(document.documentElement.classList.contains("learning-sidebar-open")).toBe(false);
  });

  it("dismisses with Escape or by tapping the backdrop", () => {
    setup();
    open();
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
    expect(byId("learning-sidebar").inert).toBe(true);
    open();
    byId("learning-sidebar-backdrop").click();
    expect(byId("learning-sidebar").inert).toBe(true);
  });

  it("keeps folder expansion and collection editing inside the drawer until navigation", () => {
    setup();
    open();
    byId("expand-folder").click();
    byId("collection-name").value = "Revision";
    window.dispatchEvent(new CustomEvent("phx:page-loading-start", { detail: { kind: "element" } }));
    document.dispatchEvent(new Event("phx:update"));
    expect(byId("learning-browse-toggle").getAttribute("aria-expanded")).toBe("true");
    expect(byId("results").inert).toBe(true);
    window.dispatchEvent(new CustomEvent("phx:page-loading-start", { detail: { kind: "patch" } }));
    expect(byId("learning-sidebar").inert).toBe(true);
  });

  it("closes on a collection selection but allows opening links in a new tab", () => {
    setup();
    open();
    const link = byId("collection");
    const click = (options = {}) => link.dispatchEvent(new MouseEvent("click", { bubbles: true, ...options }));
    click({ ctrlKey: true });
    expect(byId("learning-sidebar").inert).toBe(false);
    click();
    expect(byId("learning-sidebar").inert).toBe(true);
  });

  it("becomes a regular sidebar on desktop and closes safely when returning to mobile", () => {
    setup();
    open();
    resize(true);
    expect(byId("learning-sidebar").inert).toBe(false);
    expect(byId("learning-sidebar").hasAttribute("aria-modal")).toBe(false);
    expect(byId("results").inert).toBeFalsy();
    expect(document.documentElement.classList.contains("learning-sidebar-open")).toBe(false);
    byId("collection").focus();
    resize(false);
    expect(byId("learning-sidebar").inert).toBe(true);
    expect(document.activeElement).toBe(byId("learning-browse-toggle"));
  });

  it("starts with accessible desktop navigation and cleans up when leaving the page", () => {
    setup(true);
    expect(byId("learning-sidebar").inert).toBe(false);
    open();
    expect(byId("learning-sidebar").hasAttribute("aria-modal")).toBe(false);
    resize(false);
    open();
    hook.destroyed();
    hook = null;
    expect(byId("results").inert).toBeFalsy();
    expect(document.documentElement.classList.contains("learning-sidebar-open")).toBe(false);
    open();
    expect(byId("learning-sidebar").inert).toBe(true);
  });
});

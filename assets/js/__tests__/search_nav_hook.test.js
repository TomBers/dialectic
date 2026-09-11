import { afterEach, describe, expect, it, vi } from "vitest";
import SearchNav from "../search_nav_hook.js";

let hook;
afterEach(() => {
  hook?.destroyed();
  hook = null;
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
  document.body.innerHTML = "";
});

function mount() {
  document.body.innerHTML = `
    <div id="background"><button id="open">Search</button><article id="reading-node-2" tabindex="-1"></article></div>
    <div id="panel" data-return-focus-id="open" data-focus-result-prefix="reading-node-">
      <div role="dialog" aria-modal="true">
        <input id="query" type="text"><button id="close">Close</button>
        <ul><li><button id="result" phx-click="search_result_clicked" phx-value-id="2">Result</button></li></ul>
      </div>
    </div>`;
  vi.spyOn(HTMLElement.prototype, "getClientRects").mockReturnValue([{}]);
  vi.stubGlobal("requestAnimationFrame", (callback) => { callback(); return 1; });
  vi.stubGlobal("cancelAnimationFrame", () => {});
  hook = { ...SearchNav, el: document.getElementById("panel") };
  hook.mounted();
}

function key(key, shiftKey = false) {
  document.dispatchEvent(new KeyboardEvent("keydown", { key, shiftKey, bubbles: true, cancelable: true }));
}

describe("SearchNav modal focus", () => {
  it("focuses search, contains Tab in both directions, and restores the opener", () => {
    mount();
    expect(document.activeElement.id).toBe("query");
    expect(document.getElementById("background").inert).toBe(true);
    key("Tab", true);
    expect(document.activeElement.id).toBe("result");
    key("Tab");
    expect(document.activeElement.id).toBe("query");
    hook.destroyed();
    hook = null;
    expect(document.getElementById("background").inert).toBeFalsy();
    expect(document.activeElement.id).toBe("open");
  });

  it("keeps arrow navigation within results and focuses the chosen response on close", () => {
    mount();
    key("ArrowDown");
    expect(document.activeElement.id).toBe("result");
    key("Enter");
    hook.destroyed();
    hook = null;
    expect(document.activeElement.id).toBe("reading-node-2");
  });
  it("waits for a selected response that arrives after the search closes", async () => {
    mount();
    document.getElementById("reading-node-2").remove();
    key("ArrowDown");
    key("Enter");
    hook.destroyed();
    hook = null;
    const response = document.createElement("article");
    response.id = "reading-node-2";
    response.tabIndex = -1;
    document.getElementById("background").append(response);
    await Promise.resolve();
    expect(document.activeElement).toBe(response);
  });

});

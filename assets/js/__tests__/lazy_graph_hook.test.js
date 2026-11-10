import { afterEach, describe, expect, it, vi } from "vitest";
import { lazyGraphHook } from "../lazy_graph_hook.js";

let hook;
function mount(load) {
  const el = document.createElement("div");
  el.id = "cy";
  el.dataset.div = "cy-inner";
  el.innerHTML = '<div id="cy-inner"></div>';
  document.body.append(el);
  const handlers = new Map();
  hook = {
    ...lazyGraphHook(load), el,
    handleEvent(name, callback) {
      const ref = {name, callback};
      handlers.set(ref, callback);
      return ref;
    },
    removeHandleEvent(ref) { handlers.delete(ref); },
    emit(name, payload) {
      for (const [ref, callback] of handlers) if (ref.name === name) callback(payload);
    },
  };
  hook.mounted();
  return hook;
}

afterEach(() => {
  hook?.destroyed();
  hook = null;
  document.body.replaceChildren();
  vi.restoreAllMocks();
});

describe("graph code loading", () => {
  it("replays server events and mounts with the latest data after a delayed download", async () => {
    let resolve;
    const mounted = vi.fn(function () {
      this.helper();
      expect(this.el.dataset.node).toBe("latest");
      this.handleEvent("center_node", payload => events.push(payload.id));
    });
    const events = [];
    const definition = {mounted, updated: vi.fn(), destroyed: vi.fn(), helper: vi.fn()};
    const instance = mount(() => new Promise(done => {resolve = done;}));
    instance.emit("center_node", {id: "first"});
    instance.emit("center_node", {id: "second"});
    instance.el.dataset.node = "latest";
    instance.updated();
    expect(mounted).not.toHaveBeenCalled();
    resolve({default: definition});
    await instance.graphLoad.promise;
    expect(mounted).toHaveBeenCalledOnce();
    expect(definition.helper).toHaveBeenCalledOnce();
    expect(events).toEqual(["first", "second"]);
    instance.emit("center_node", {id: "third"});
    expect(events).toEqual(["first", "second", "third"]);
    instance.updated();
    expect(definition.updated).toHaveBeenCalledOnce();
    instance.destroyed();
    hook = null;
    expect(definition.destroyed).toHaveBeenCalledOnce();
  });

  it("does not mount a grid after navigation destroys it during loading", async () => {
    let resolve;
    const instance = mount(() => new Promise(done => {resolve = done;}));
    const mounted = vi.fn();
    instance.destroyed();
    hook = null;
    instance.el.remove();
    resolve({default: {mounted}});
    await instance.graphLoad.promise;
    expect(mounted).not.toHaveBeenCalled();
    expect(instance.graphLoad.events).toEqual([]);
  });

  it("keeps the rest of the page available and offers reload when the chunk fails", async () => {
    vi.spyOn(console, "error").mockImplementation(() => {});
    const instance = mount(() => Promise.reject(new Error("Download failed")));
    await instance.graphLoad.promise;
    expect(instance.el.querySelector('[role="alert"] button').textContent).toBe("Reload grid");
    expect(instance.el.querySelector("#cy-inner").hasAttribute("aria-busy")).toBe(false);
    expect(instance.graphLoad.refs).toEqual([]);
  });
});

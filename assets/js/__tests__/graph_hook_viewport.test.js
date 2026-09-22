import cytoscape from "cytoscape";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import graphHook from "../graph_hook.js";

// Exercise the actual hook, layout and viewport code with Cytoscape's headless renderer.
vi.mock("../graph_renderer.js", () => ({
  createGraphRenderer: (options) => {
    const cy = cytoscape({
      ...options, container: undefined, headless: true, styleEnabled: true,
    });
    cy.stopAnimationLoop();
    return cy;
  },
}));

describe("graph viewport lifecycle", () => {
  let hook;
  let frames;

  const flushFrames = () => {
    for (let i = 0; frames.size && i < 20; i++) {
      const current = [...frames.values()];
      frames.clear();
      current.forEach((callback) => callback());
    }
    expect(frames.size).toBe(0);
  };

  const mount = () => {
    hook.mounted();
    flushFrames();
  };

  beforeEach(() => {
    localStorage.clear();
    sessionStorage.clear();
    frames = new Map();
    let nextFrame = 0;
    vi.stubGlobal("requestAnimationFrame", (callback) => {
      frames.set(++nextFrame, callback);
      return nextFrame;
    });
    vi.stubGlobal("cancelAnimationFrame", (id) => frames.delete(id));
    vi.stubGlobal("matchMedia", () => ({ matches: false }));
    const el = document.createElement("div");
    el.id = "cy";
    const container = document.createElement("div");
    container.id = "cy-inner";
    container.getBoundingClientRect = () => ({
      left: 0, top: 0, width: 1000, height: 700, right: 1000, bottom: 700,
    });
    el.append(container);
    document.body.append(el);
    const elements = Array.from({ length: 12 }, (_, i) => ({
      data: { id: String(i), content: `Idea ${i}` },
    }));
    for (let i = 1; i < 12; i++) {
      elements.push({ data: { id: `e${i}`, source: String(i - 1), target: String(i) } });
    }
    Object.assign(el.dataset, {
      graph: JSON.stringify(elements), node: "0", div: "cy-inner",
      graphId: "viewport-test", reduceMotion: "true", readerPathIds: "[]",
    });
    hook = {
      ...graphHook, el, pushEvent: vi.fn(),
      handleEvent: vi.fn((event) => event), removeHandleEvent: vi.fn(),
    };
  });

  afterEach(() => {
    const cy = hook.cy;
    hook.destroyed();
    if (cy) expect(cy.destroyed()).toBe(true);
    flushFrames();
    document.body.replaceChildren();
    window.history.replaceState({}, "", "/");
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
    vi.useRealTimers();
  });

  it("opens at a readable zoom with the starting idea above the centre", () => {
    mount();
    const first = hook.cy.getElementById("0");
    expect(first.renderedBoundingBox().y1).toBeGreaterThanOrEqual(32);
    expect(first.renderedPosition().y).toBeLessThan(700 / 3);
    expect(hook.cy.zoom()).toBe(0.85);
    expect(first.pstyle("label").value).toBe("Idea 0");
    expect(hook._container.dataset.graphReady).toBe("true");
    expect(hook._layoutRunning).toBe(false);
  });

  it("finishes teardown with viewport frames and pan timers pending", () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] });
    mount();
    const cy = hook.cy;
    cy.scheduleViewportClamp();
    const clampFrame = [...frames.keys()][0];
    cy.nodes().dirtyBoundingBoxCache();
    cy.pan({ x: 150, y: 100 });

    hook.destroyed();
    expect(frames.has(clampFrame)).toBe(false);
    vi.advanceTimersByTime(100);

    expect(() => flushFrames()).not.toThrow();
    expect(cy.destroyed()).toBe(true);
    expect(hook.cy).toBeNull();
  });

  it("ignores viewport measurements during and after renderer teardown", () => {
    mount();
    const cy = hook.cy;
    const results = [];
    cy.one("destroy", () => {
      cy.nodes().dirtyBoundingBoxCache();
      results.push(cy.constrainViewport());
      cy.scheduleViewportClamp({ immediate: true });
    });

    expect(() => cy.destroy()).not.toThrow();
    expect(results).toEqual([false]);
    expect(cy.constrainViewport()).toBe(false);
    expect(() => flushFrames()).not.toThrow();
  });

  it("finishes destroying the previous renderer when switching view modes", () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] });
    mount();
    const previous = hook.cy;
    previous.scheduleViewportClamp();
    previous.pan({ x: 150, y: 100 });

    hook.el.dispatchEvent(new CustomEvent("viewModeChanged", {
      detail: { view_mode: "compact" },
    }));
    vi.advanceTimersByTime(100);

    expect(() => flushFrames()).not.toThrow();
    expect(previous.destroyed()).toBe(true);
    expect(hook.cy).not.toBe(previous);
    expect(hook.cy.destroyed()).toBe(false);
    expect(hook.cy.getElementById("0").pstyle("label").value).toBe("Idea 0");
  });

  it("does not reload or rearrange nodes on the first unchanged LiveView update", () => {
    mount();
    const cy = hook.cy;
    const idea = cy.getElementById("2");
    idea.position({ x: 260, y: 380 });
    cy.viewport({ zoom: 0.6, pan: { x: 200, y: 150 } });
    flushFrames();
    const pan = { ...cy.pan() };
    const layout = vi.spyOn(cy, "layout");
    const json = vi.spyOn(cy, "json");

    hook.updated();
    flushFrames();

    expect(layout).not.toHaveBeenCalled();
    expect(json).not.toHaveBeenCalled();
    expect(idea.position()).toEqual({ x: 260, y: 380 });
    expect(cy.zoom()).toBe(0.6);
    expect(cy.pan()).toEqual(pan);
  });

  it("dismisses the graph hint on interaction and keeps it dismissed after server patches", () => {
    const hint = document.createElement("div");
    hint.dataset.graphHint = "";
    hook.el.append(hint);
    mount();
    expect(hint.hidden).toBe(false);

    hook.el.dispatchEvent(new Event("pointerdown", { bubbles: true }));
    expect(hint.hidden).toBe(true);

    hint.hidden = false;
    hook.updated();
    flushFrames();
    expect(hint.hidden).toBe(true);
    expect(hook.cy.zoom()).toBe(0.85);
  });

  it("restores the actual zoom display after LiveView patches its default text", () => {
    const indicator = document.createElement("span");
    indicator.dataset.zoomLevel = "";
    indicator.textContent = "100%";
    hook.el.append(indicator);
    mount();
    expect(indicator.textContent).toBe("85%");

    indicator.textContent = "100%";
    hook.updated();

    expect(indicator.textContent).toBe("85%");
    expect(hook.cy.zoom()).toBe(0.85);
  });

  it("keeps the disclosure node in place when collapsing and reopening a wide branch", () => {
    const elements = JSON.parse(hook.el.dataset.graph);
    for (let i = 0; i < 5; i++) {
      elements.push(
        { data: { id: `sibling${i}`, content: `Another branch ${i}` } },
        { data: { id: `branch${i}`, source: "1", target: `sibling${i}` } },
      );
    }
    hook.el.dataset.graph = JSON.stringify(elements);
    mount();
    const node = hook.cy.getElementById("1");
    const position = { ...node.renderedPosition() };
    const zoom = hook.cy.zoom();

    hook.cy.collapseNodeChildren(node);
    flushFrames();
    expect(hook.cy.getElementById("2").hasClass("depth-hidden")).toBe(true);
    expect(node.renderedPosition().x).toBeCloseTo(position.x);
    expect(node.renderedPosition().y).toBeCloseTo(position.y);

    hook.cy.expandNodeChildren(node);
    flushFrames();
    expect(hook.cy.getElementById("2").hasClass("depth-hidden")).toBe(false);
    expect(node.renderedPosition().x).toBeCloseTo(position.x);
    expect(node.renderedPosition().y).toBeCloseTo(position.y);
    expect(hook.cy.zoom()).toBe(zoom);
  });

  it("keeps the chosen viewport when switching to compact mode", () => {
    mount();
    hook.cy.viewport({ zoom: 0.6, pan: { x: 200, y: 150 } });
    flushFrames();
    const pan = { ...hook.cy.pan() };

    hook.el.dispatchEvent(new CustomEvent("viewModeChanged", {
      detail: { view_mode: "compact" },
    }));
    flushFrames();

    expect(hook.cy.zoom()).toBe(0.6);
    expect(hook.cy.pan()).toEqual(pan);
  });

  it("still adds and selects ideas when the first LiveView update changes the graph", () => {
    mount();
    const elements = JSON.parse(hook.el.dataset.graph);
    elements.push(
      { data: { id: "12", content: "New idea" } },
      { data: { id: "e12", source: "11", target: "12" } },
    );
    Object.assign(hook.el.dataset, {
      graph: JSON.stringify(elements), node: "12", operation: "ideas",
    });

    hook.updated();
    flushFrames();

    const idea = hook.cy.getElementById("12");
    expect(hook.cy.nodes()).toHaveLength(13);
    expect(idea.hasClass("selected")).toBe(true);
    expect(idea.position().y).toBeGreaterThan(hook.cy.getElementById("11").position().y);
    expect(hook._layoutRunning).toBe(false);
  });

  it("restores a saved viewport after the initial framing", () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] });
    sessionStorage.setItem("dialectic:graph-viewport:viewport-test", JSON.stringify({
      pathKey: "", zoom: 0.7, pan: { x: 250, y: 180 },
      anchor: { nodeId: "0", renderedPosition: { x: 300, y: 200 } },
    }));
    mount();
    vi.advanceTimersByTime(0);
    flushFrames();

    expect(hook.cy.zoom()).toBe(0.7);
    expect(hook.cy.getElementById("0").renderedPosition()).toEqual({ x: 300, y: 200 });
    expect(hook._container.dataset.graphReady).toBe("true");
  });

  it("opens an explicit reader path without waiting for a layout timeout", () => {
    hook.el.dataset.readerPathIds = JSON.stringify(["0", "1", "2"]);
    hook.el.dataset.readerPathEndpoint = "2";
    hook.el.dataset.node = "2";
    mount();

    const visible = hook.cy.nodes().not(".focus-hidden");
    expect(visible.map((node) => node.id())).toEqual(["0", "1", "2"]);
    expect(visible.renderedBoundingBox().y1).toBeGreaterThanOrEqual(32);
    expect(visible.renderedBoundingBox().y2).toBeLessThanOrEqual(668);
    expect(hook._container.style.opacity).toBe("1");
    expect(hook._readerPathFocusTimer).toBeFalsy();
  });

  it("the Fit control fits the focused path and keeps other branches hidden", () => {
    const fitButton = document.createElement("button");
    fitButton.dataset.zoomAction = "fit";
    document.body.append(fitButton);
    hook.el.dataset.readerPathIds = JSON.stringify(["0", "1", "2"]);
    hook.el.dataset.readerPathEndpoint = "2";
    hook.el.dataset.node = "2";
    mount();
    hook.cy.viewport({ zoom: 0.2, pan: { x: 50, y: 50 } });

    fitButton.click();
    flushFrames();

    const visible = hook.cy.nodes().not(".focus-hidden");
    expect(hook.cy.zoom()).toBeGreaterThan(0.2);
    expect(visible.map((node) => node.id())).toEqual(["0", "1", "2"]);
    expect(visible.renderedBoundingBox().y1).toBeGreaterThanOrEqual(32);
    expect(visible.renderedBoundingBox().y2).toBeLessThanOrEqual(668);
  });

  it("highlights hovered nodes and selects a visible idea without changing the zoom", () => {
    mount();
    const cy = hook.cy;
    const idea = cy.getElementById("1");
    const zoom = cy.zoom();
    const pan = { ...cy.pan() };

    idea.emit("mouseover");
    expect(idea.hasClass("node-hover")).toBe(true);
    expect(idea.connectedEdges().every((edge) => edge.hasClass("edge-hover"))).toBe(true);
    idea.emit("tap");
    expect(hook.pushEvent).toHaveBeenCalledWith("node_clicked", { id: "1" });
    expect(cy.nodes(".selected").map((node) => node.id())).toEqual(["1"]);
    expect(idea.connectedEdges().every((edge) => edge.hasClass("selected-edge"))).toBe(true);
    idea.emit("mouseout");
    expect(idea.hasClass("node-hover")).toBe(false);
    expect(cy.edges(".edge-hover")).toHaveLength(0);
    expect(idea.hasClass("selected")).toBe(true);
    expect(cy.zoom()).toBe(zoom);
    expect(cy.pan()).toEqual(pan);
  });
});

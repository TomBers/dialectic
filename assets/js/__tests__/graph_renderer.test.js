import cytoscape from "cytoscape";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AtlasCollection } from "../../node_modules/cytoscape/src/extensions/renderer/canvas/webgl/atlas.mjs";

vi.mock("cytoscape", () => ({ default: vi.fn() }));
// Atlas allocation does not need Cytoscape's development-only utility imports.
vi.mock("../../node_modules/cytoscape/src/util/index.mjs", () => ({}));

const emptyAtlasCollection = () => ({ _createAtlas: () => ({ enableWrapping: true }) });

const makeGraph = (webgl = true) => {
  const container = document.createElement("div");
  const canvas = document.createElement("canvas");
  const loseContext = vi.fn();
  const gl = {
    isContextLost: vi.fn(() => false),
    getExtension: vi.fn(() => ({ loseContext })),
  };
  canvas.dataset.id = "layer3-webgl";
  canvas.getContext = vi.fn(() => gl);
  if (webgl) container.append(canvas);
  let onDestroy;
  let destroyed = false;
  const renderer = {
    webgl,
    findNearestElements: vi.fn(),
    drawing: { atlasManager: {
      getRenderTypeOpts: () => ({ getKey: () => 123 }),
      getAtlasCollection: emptyAtlasCollection,
    } },
  };
  const cy = {
    container: () => container,
    renderer: () => renderer,
    destroyed: () => destroyed,
    one: (_, handler) => { onDestroy = handler; },
    destroy: () => {
      onDestroy?.();
      destroyed = true;
    },
  };
  return { cy, container, canvas, gl, loseContext };
};

describe("graph renderer recovery", () => {
  let createGraphRenderer;
  let frames;
  let initialize;
  let canvasTypes;
  let findNearestElements;

  beforeEach(async () => {
    vi.resetModules();
    initialize = vi.fn();
    findNearestElements = vi.fn();
    canvasTypes = ["2d", "2d", "2d", "webgl2"];
    cytoscape.mockImplementation((options) =>
      options === "renderer"
        ? { prototype: { CANVAS_TYPES: canvasTypes, findNearestElements } }
        : initialize(options),
    );
    frames = new Map();
    let nextFrame = 0;
    vi.stubGlobal("requestAnimationFrame", (callback) => {
      frames.set(++nextFrame, callback);
      return nextFrame;
    });
    vi.stubGlobal("cancelAnimationFrame", (id) => frames.delete(id));
    ({ createGraphRenderer } = await import("../graph_renderer.js"));
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  it("uses WebGL by default and releases its context when the graph is destroyed", () => {
    const graph = makeGraph();
    initialize.mockReturnValue(graph.cy);
    const cy = createGraphRenderer({ container: graph.container }, vi.fn());

    expect(initialize.mock.calls[0][0].renderer.webgl).toBe(true);
    expect(graph.container.dataset.renderer).toBe("webgl");
    cy.destroy();
    expect(graph.loseContext).toHaveBeenCalledOnce();
    graph.canvas.dispatchEvent(new Event("webglcontextlost"));
    expect(frames.size).toBe(0);
  });

  it("cleans up a failed initialization and stays on Canvas for subsequent graphs", () => {
    const graph = makeGraph(false);
    const partial = { destroy: vi.fn() };
    graph.container._cyreg = { cy: partial };
    vi.spyOn(console, "warn").mockImplementation(() => {});
    initialize.mockImplementationOnce(() => { throw new Error("WebGL unavailable"); });
    initialize.mockImplementation(() => {
      expect(canvasTypes[3]).toBe("2d");
      return graph.cy;
    });

    expect(createGraphRenderer({ container: graph.container }, vi.fn())).toBe(graph.cy);
    expect(canvasTypes[3]).toBe("webgl2");
    expect(partial.destroy).toHaveBeenCalledOnce();
    expect(graph.container.dataset.renderer).toBe("canvas");
    createGraphRenderer({ container: graph.container }, vi.fn());
    expect(initialize.mock.calls.map(([options]) => options.renderer.webgl)).toEqual([
      true, false, false,
    ]);
  });

  it("coalesces context loss and passes the current graph to recovery", () => {
    const graph = makeGraph();
    const recover = vi.fn();
    initialize.mockReturnValue(graph.cy);
    createGraphRenderer({ container: graph.container }, recover);
    const event = new Event("webglcontextlost", { cancelable: true });
    graph.canvas.dispatchEvent(event);
    graph.canvas.dispatchEvent(new Event("webglcontextlost"));

    expect(event.defaultPrevented).toBe(true);
    expect(recover).not.toHaveBeenCalled();
    expect(frames.size).toBe(1);
    frames.values().next().value();
    expect(recover).toHaveBeenCalledExactlyOnceWith(graph.cy);

    const fallback = makeGraph(false);
    initialize.mockReturnValue(fallback.cy);
    createGraphRenderer({ container: fallback.container }, recover);
    expect(initialize.mock.lastCall[0].renderer.webgl).toBe(false);
  });

  it("cancels pending recovery when navigation destroys the graph", () => {
    const graph = makeGraph();
    const recover = vi.fn();
    initialize.mockReturnValue(graph.cy);
    createGraphRenderer({ container: graph.container }, recover);
    graph.gl.isContextLost.mockReturnValue(true);
    graph.canvas.dispatchEvent(new Event("webglcontextlost"));
    const queuedFrame = frames.values().next().value;
    graph.cy.destroy();

    expect(frames.size).toBe(0);
    queuedFrame();
    expect(recover).not.toHaveBeenCalled();
    expect(graph.loseContext).not.toHaveBeenCalled();
  });

  it("does not swallow errors when Canvas initialization also fails", () => {
    const error = new Error("Canvas unavailable");
    initialize.mockImplementation(() => { throw error; });
    expect(() => createGraphRenderer({ webgl: false }, vi.fn())).toThrow(error);
    expect(initialize).toHaveBeenCalledOnce();
    expect(canvasTypes[3]).toBe("webgl2");
  });
});

describe("WebGL interaction rendering", () => {
  it("uses Canvas pointer tests without changing WebGL drawing or pending redraws", async () => {
    const { prepareWebglRenderer } = await import("../graph_renderer.js");
    const hit = [{ id: "idea" }];
    const canvasPicking = vi.fn(function () {
      expect(this).toBe(renderer);
      return hit;
    });
    cytoscape.mockReturnValue({ prototype: { findNearestElements: canvasPicking } });
    const gpuPicking = vi.fn(() => { throw new Error("GPU picking must not run"); });
    const renderer = {
      webgl: true,
      NODE: 2,
      DRAG: 1,
      data: { canvasNeedsRedraw: [false, true, true] },
      findNearestElements: gpuPicking,
      drawing: { atlasManager: {
        getRenderTypeOpts: () => ({ getKey: () => 123 }),
        getAtlasCollection: emptyAtlasCollection,
      } },
    };
    prepareWebglRenderer(renderer);

    expect(renderer.findNearestElements(10, 20, true, false)).toBe(hit);
    expect(canvasPicking).toHaveBeenCalledWith(10, 20, true, false);
    expect(renderer.webgl).toBe(true);
    expect(gpuPicking).not.toHaveBeenCalled();
    expect(renderer.data.canvasNeedsRedraw).toEqual([false, true, true]);
    renderer.data.canvasNeedsRedraw = [false, false, false];
    renderer.findNearestElements(10, 20, true, false);
    expect(renderer.data.canvasNeedsRedraw).toEqual([false, false, false]);
  });

  it("does not reuse dimmed label textures for opaque labels, including wrapped text", async () => {
    const { prepareWebglRenderer } = await import("../graph_renderer.js");
    cytoscape.mockReturnValue({ prototype: { findNearestElements: vi.fn() } });
    const types = new Map([
      ["label", { getKey: () => ["123_0", "123_1"] }],
      ["edge-source-label", { getKey: () => 456 }],
      ["edge-target-label", { getKey: () => 789 }],
    ]);
    const renderer = {
      findNearestElements: vi.fn(),
      drawing: { atlasManager: {
        getRenderTypeOpts: (type) => types.get(type),
        getAtlasCollection: emptyAtlasCollection,
      } },
    };
    prepareWebglRenderer(renderer);
    const element = (opacity, textOpacity = 1) => ({
      effectiveOpacity: () => opacity,
      pstyle: () => ({ value: textOpacity }),
    });
    for (const options of types.values()) {
      expect(options.getKey(element(1))).not.toEqual(options.getKey(element(0.15)));
      expect(options.getKey(element(1))).not.toEqual(options.getKey(element(1, 0.4)));
      expect(options.getKey(element(1))).toEqual(options.getKey(element(1)));
    }
    const keys = types.get("label").getKey(element(1));
    expect(keys.map((key) => Number(key.substring(key.indexOf("_") + 1)))).toEqual([0, 1]);
  });

  it("keeps complete textures in one row, including new atlases after compaction", async () => {
    const { prepareWebglRenderer } = await import("../graph_renderer.js");
    cytoscape.mockReturnValue({ prototype: { findNearestElements: vi.fn() } });
    const createCanvas = () => ({ clear: vi.fn(), context: {
      drawImage: vi.fn(), save: vi.fn(), restore: vi.fn(),
      translate: vi.fn(), scale: vi.fn(),
    } });
    const collections = new Map(["node", "label"].map((type) => [
      type, new AtlasCollection({}, 100, 4, createCanvas),
    ]));
    prepareWebglRenderer({ drawing: { atlasManager: {
      getAtlasCollection: (type) => collections.get(type),
      getRenderTypeOpts: () => ({ getKey: () => 123 }),
    } } });

    for (const collection of collections.values()) {
      collection.draw("obsolete", { w: 10, h: 25 });
      collection.draw("first", { w: 80, h: 25 });
      collection.draw("second", { w: 50, h: 25 });
      for (let generation = 0; generation < 2; generation++) {
        const atlas = collection.getAtlas("second");
        const [whole, remainder] = atlas.getOffsets("second");
        expect(whole).toMatchObject({ x: 0, y: 25, w: 50, h: 25 });
        expect(remainder.w).toBe(0);
        if (generation === 0) {
          collection.markKeyForGC("obsolete");
          collection.gc();
          expect(collection.getAtlas("second")).not.toBe(atlas);
          expect(collection.hasAtlas("obsolete")).toBe(false);
        }
      }
    }
  });
});

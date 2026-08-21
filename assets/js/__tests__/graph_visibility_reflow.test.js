import { afterEach, describe, expect, it, vi } from "vitest";
import {
  depthTogglePosition,
  reflowAfterVisibilityChange,
} from "../draw_graph.js";

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("graph visibility reflow", () => {
  it("positions branch controls just above their node", () => {
    expect(depthTogglePosition({ x1: 100, x2: 220, y1: 80 })).toEqual({
      x: 160,
      y: 74,
    });
  });

  it("waits for revealed nodes to render before starting layout", () => {
    const frames = [];
    const styleUpdate = vi.fn();
    const resize = vi.fn();
    const layoutRun = vi.fn();
    const onDone = vi.fn();
    let layoutStop;

    vi.stubGlobal("requestAnimationFrame", (callback) => {
      frames.push(callback);
      return frames.length;
    });

    const cy = {
      _reduceMotion: true,
      destroyed: () => false,
      style: () => ({ update: styleUpdate }),
      resize,
      one: (event, callback) => {
        if (event === "layoutstop") layoutStop = callback;
      },
      layout: vi.fn(() => ({ run: layoutRun })),
    };

    reflowAfterVisibilityChange(cy, onDone);

    expect(layoutRun).not.toHaveBeenCalled();
    expect(frames).toHaveLength(1);

    frames.shift()();

    expect(styleUpdate).toHaveBeenCalledOnce();
    expect(resize).toHaveBeenCalledOnce();
    expect(layoutRun).not.toHaveBeenCalled();
    expect(frames).toHaveLength(1);

    frames.shift()();

    expect(cy.layout).toHaveBeenCalledOnce();
    expect(layoutRun).toHaveBeenCalledOnce();
    expect(onDone).not.toHaveBeenCalled();

    layoutStop();
    expect(onDone).toHaveBeenCalledOnce();
  });

  it("coalesces multiple reveals into one layout", () => {
    const frames = [];
    const callbacks = [];
    const layoutRun = vi.fn();

    vi.stubGlobal("requestAnimationFrame", (callback) => {
      frames.push(callback);
      return frames.length;
    });

    const cy = {
      _reduceMotion: true,
      destroyed: () => false,
      style: () => ({ update: vi.fn() }),
      resize: vi.fn(),
      one: (_event, callback) => callbacks.push(callback),
      layout: vi.fn(() => ({ run: layoutRun })),
    };
    const firstDone = vi.fn();
    const secondDone = vi.fn();

    reflowAfterVisibilityChange(cy, firstDone);
    reflowAfterVisibilityChange(cy, secondDone);
    frames.shift()();
    frames.shift()();

    expect(layoutRun).toHaveBeenCalledOnce();
    callbacks[0]();
    expect(firstDone).toHaveBeenCalledOnce();
    expect(secondDone).toHaveBeenCalledOnce();
  });
});

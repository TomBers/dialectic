import cytoscape from "cytoscape";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  clearBranchFocus,
  depthTogglePosition,
  focusBranch,
  focusPath,
  reflowAfterVisibilityChange,
  visibilityControlPositions,
  visibleLayoutElements,
} from "../draw_graph.js";

afterEach(() => {
  vi.unstubAllGlobals();
  window.history.replaceState({}, "", "/");
});

describe("graph visibility reflow", () => {
  it("positions disclosure controls to the right of the node", () => {
    const bounds = { x1: 100, x2: 220, y1: 80, y2: 140 };

    expect(depthTogglePosition(bounds)).toEqual({
      x: 228,
      y: 110,
      translateX: "0",
      translateY: "-50%",
    });
  });

  it("anchors paired visibility controls to the upper and lower right", () => {
    const bounds = { x1: 100, x2: 220, y1: 80, y2: 160 };

    const positions = visibilityControlPositions(bounds, 0.8);

    expect(positions.x).toBe(228);
    expect(positions.focusY).toBeCloseTo(92);
    expect(positions.disclosureY).toBeCloseTo(148);
    expect(positions.span).toBeCloseTo(56);
  });

  it("applies and clears an exact reader path", () => {
    vi.stubGlobal("requestAnimationFrame", vi.fn());
    window.history.replaceState({}, "", "/g/example/graph?node=2&path=2");
    const pushEvent = vi.fn();
    const cy = cytoscape({
      headless: true,
      elements: [
        { data: { id: "root" } },
        { data: { id: "path-node" } },
        { data: { id: "sibling" } },
        { data: { id: "root-path", source: "root", target: "path-node" } },
        { data: { id: "root-sibling", source: "root", target: "sibling" } },
      ],
    });
    cy._ownerHook = { pushEvent };

    expect(focusPath(cy, ["root", "path-node"], null)).toBe(true);
    expect(cy._readerPathFocus).toBe(true);
    expect(cy._focusedBranchId).toBe("path-node");
    expect(cy.getElementById("root").hasClass("focus-hidden")).toBe(false);
    expect(cy.getElementById("path-node").hasClass("focus-hidden")).toBe(false);
    expect(cy.getElementById("sibling").hasClass("focus-hidden")).toBe(true);

    expect(clearBranchFocus(cy, null)).toBe(true);
    expect(pushEvent).toHaveBeenCalledWith("clear_reader_path", {});
    expect(new URL(window.location.href).searchParams.has("path")).toBe(false);
    expect(cy.$(".focus-hidden")).toHaveLength(0);

    cy.destroy();
  });

  it("focuses one exact path and restores all paths", () => {
    vi.stubGlobal("requestAnimationFrame", vi.fn());
    window.history.replaceState({}, "", "/g/example/graph?node=branch-a");
    const pushEvent = vi.fn();
    const cy = cytoscape({
      headless: true,
      elements: [
        { data: { id: "root" } },
        { data: { id: "branch-a" } },
        { data: { id: "branch-b" } },
        { data: { id: "leaf-a" } },
        { data: { id: "leaf-b" } },
        { data: { id: "root-a", source: "root", target: "branch-a" } },
        { data: { id: "root-b", source: "root", target: "branch-b" } },
        { data: { id: "a-leaf", source: "branch-a", target: "leaf-a" } },
        { data: { id: "b-leaf", source: "branch-b", target: "leaf-b" } },
      ],
    });
    cy._ownerHook = { pushEvent };

    expect(focusBranch(cy, cy.getElementById("branch-a"), null)).toBe(true);
    expect(pushEvent).toHaveBeenCalledWith("set_reader_path", { id: "branch-a" });
    expect(new URL(window.location.href).searchParams.get("path")).toBe("branch-a");
    expect(cy.getElementById("root").hasClass("focus-hidden")).toBe(false);
    expect(cy.getElementById("branch-a").hasClass("focus-hidden")).toBe(false);
    expect(cy.getElementById("leaf-a").hasClass("focus-hidden")).toBe(true);
    expect(cy.getElementById("branch-b").hasClass("focus-hidden")).toBe(true);
    expect(cy.getElementById("leaf-b").hasClass("focus-hidden")).toBe(true);
    expect(cy.getElementById("root-b").hasClass("focus-hidden")).toBe(true);
    expect(visibleLayoutElements(cy).nodes().map((node) => node.id())).toEqual([
      "root",
      "branch-a",
    ]);

    expect(clearBranchFocus(cy, null)).toBe(true);
    expect(cy.$(".focus-hidden")).toHaveLength(0);

    cy.destroy();
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

  it("reflows the focused subgraph after visibility settles", () => {
    const frames = [];
    vi.stubGlobal("requestAnimationFrame", (callback) => {
      frames.push(callback);
      return frames.length;
    });

    const cy = cytoscape({
      headless: true,
      elements: [
        { data: { id: "root" }, position: { x: 0, y: 0 } },
        { data: { id: "branch-a" }, position: { x: 0, y: 0 } },
        { data: { id: "branch-b" }, position: { x: 0, y: 0 } },
        { data: { id: "leaf-a" }, position: { x: 0, y: 0 } },
        { data: { id: "leaf-b" }, position: { x: 0, y: 0 } },
        { data: { id: "root-a", source: "root", target: "branch-a" } },
        { data: { id: "root-b", source: "root", target: "branch-b" } },
        { data: { id: "a-leaf", source: "branch-a", target: "leaf-a" } },
        { data: { id: "b-leaf", source: "branch-b", target: "leaf-b" } },
      ],
    });
    cy._reduceMotion = true;
    const container = document.createElement("div");
    document.body.appendChild(container);
    const fitSpy = vi.spyOn(cy, "fit");
    cy.zoom(1.4);
    cy.pan({ x: 35, y: 48 });
    const selectedScreenPosition = cy
      .getElementById("branch-a")
      .renderedPosition();

    focusBranch(cy, cy.getElementById("branch-a"), container);
    expect(frames).toHaveLength(1);
    frames.shift()();
    expect(frames).toHaveLength(1);
    frames.shift()();

    const positions = ["root", "branch-a", "leaf-a"].map((id) =>
      cy.getElementById(id).position(),
    );

    expect(positions.every((position) => position.x === 0 && position.y === 0)).toBe(
      false,
    );
    expect(new Set(positions.map((position) => `${position.x}:${position.y}`)).size).toBe(
      3,
    );
    expect(fitSpy).not.toHaveBeenCalled();
    expect(cy.zoom()).toBeCloseTo(1.4);
    expect(cy.getElementById("branch-a").renderedPosition().x).toBeCloseTo(
      selectedScreenPosition.x,
    );
    expect(cy.getElementById("branch-a").renderedPosition().y).toBeCloseTo(
      selectedScreenPosition.y,
    );

    cy.destroy();
    container.remove();
  });

  it("can disable focus animation for reader-path transitions", () => {
    const frames = [];
    vi.stubGlobal("requestAnimationFrame", (callback) => {
      frames.push(callback);
      return frames.length;
    });

    const cy = {
      _reduceMotion: false,
      destroyed: () => false,
      style: () => ({ update: vi.fn() }),
      resize: vi.fn(),
      one: vi.fn(),
      layout: vi.fn(() => ({ run: vi.fn() })),
    };

    reflowAfterVisibilityChange(cy, null, { animate: false });
    frames.shift()();
    frames.shift()();

    expect(cy.layout).toHaveBeenCalledWith(
      expect.objectContaining({ animate: false, animationDuration: 0 }),
    );
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

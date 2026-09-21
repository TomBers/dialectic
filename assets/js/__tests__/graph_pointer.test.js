import cytoscape from "cytoscape";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { prepareWebglRenderer } from "../graph_renderer.js";

describe("pointer detection with WebGL drawing", () => {
  let cy;
  let renderer;

  beforeEach(() => {
    cy = cytoscape({
      headless: true,
      styleEnabled: true,
      layout: { name: "preset", fit: false },
      style: [
        { selector: "node", style: { width: 240, height: 80, shape: "roundrectangle" } },
        { selector: ".hidden", style: { display: "none" } },
      ],
      elements: [
        { data: { id: "a" }, position: { x: 200, y: 150 } },
        { data: { id: "b" }, position: { x: 700, y: 450 } },
      ],
    });
    renderer = Object.create(cytoscape("renderer", "canvas").prototype);
    renderer.cy = cy;
    renderer.registerNodeShapes();
    renderer.registerArrowShapes();
    renderer.findContainerClientCoords = () => [30, 50, 1000, 700, 1];
    renderer.findNearestElements = vi.fn(() => { throw new Error("GPU picking"); });
    renderer.drawing = { atlasManager: {
      getRenderTypeOpts: () => ({ getKey: () => 123 }),
      getAtlasCollection: () => ({ _createAtlas: () => ({ enableWrapping: true }) }),
    } };
    prepareWebglRenderer(renderer);
  });

  afterEach(() => cy.destroy());

  const hitAt = (node, isTouch = false, dx = 0) => {
    const p = node.renderedPosition();
    const [x, y] = renderer.projectIntoViewport(p.x + 30 + dx, p.y + 50);
    return renderer.findNearestElement(x, y, true, isTouch);
  };

  it.each([0.15, 0.85, 1, 3])("finds the correct node at %s zoom after panning", (zoom) => {
    cy.viewport({ zoom, pan: { x: 110, y: 75 } });
    expect(hitAt(cy.getElementById("a"))?.id()).toBe("a");
    expect(hitAt(cy.getElementById("b"))?.id()).toBe("b");
  });

  it("tracks a node after it is dragged", () => {
    const node = cy.getElementById("a");
    node.position({ x: 300, y: 500 });
    expect(renderer.findNearestElement(200, 150, true, false)?.id()).toBeUndefined();
    expect(hitAt(node)?.id()).toBe("a");
  });

  it("does not let hidden or noninteractive nodes intercept selection", () => {
    const a = cy.getElementById("a");
    const b = cy.getElementById("b");
    b.position(a.position());
    b.addClass("hidden");
    expect(hitAt(a)?.id()).toBe("a");
    b.removeClass("hidden").style("events", "no");
    renderer.invalidateCachedZSortedEles();
    expect(hitAt(a)?.id()).toBe("a");
  });

  it("retains the larger touch target around small nodes", () => {
    cy.zoom(0.2);
    const node = cy.getElementById("a");
    const dx = node.outerWidth() * cy.zoom() / 2 + 5;
    expect(hitAt(node, false, dx)?.id()).toBeUndefined();
    expect(hitAt(node, true, dx)?.id()).toBe("a");
  });
});

import cytoscape from "cytoscape";
import { afterEach, expect, it, vi } from "vitest";
import { refreshGraphLabels } from "../graph_renderer.js";

let cy;
afterEach(() => { vi.restoreAllMocks(); cy?.destroy(); });

it("remeasures wrapped titles and rebuilds textures when a web font finishes loading", () => {
  cy = cytoscape({
    headless: true,
    styleEnabled: true,
    layout: { name: "preset", fit: false },
    style: [{ selector: "node", style: {
      label: "data(content)", width: 280, height: 80,
      "font-size": 16, "text-wrap": "wrap", "text-max-width": 252,
    } }],
    elements: [{ data: {
      id: "5", content: "Lacanian Psychoanalysis: The Linguistic Turn in Subjectivity",
    }, position: { x: 100, y: 200 } }],
  });
  const renderer = Object.create(cytoscape("renderer", "canvas").prototype);
  renderer.cy = cy;
  renderer.webgl = true;
  renderer.notify = vi.fn();
  renderer.labelCalcCanvas = {};
  let characterWidth = 5;
  renderer.labelCalcCanvasContext = {
    measureText: (text) => ({ width: text.length * characterWidth }),
  };
  const invalidate = vi.fn();
  renderer.drawing = { atlasManager: { invalidate } };
  vi.spyOn(cy, "window").mockReturnValue(window);
  vi.spyOn(cy, "renderer").mockReturnValue(renderer);
  const forceRender = vi.spyOn(cy, "forceRender").mockImplementation(() => cy);
  const node = cy.getElementById("5");
  renderer.recalculateRenderedStyle(cy.elements());
  const oldLines = [...node._private.rscratch.labelWrapCachedLines];
  const oldWidth = node._private.rscratch.labelWidth;

  characterWidth = 9;
  // The normal render pass sees a clean label and keeps the old metrics.
  renderer.recalculateRenderedStyle(cy.elements());
  expect(node._private.rscratch.labelWidth).toBe(oldWidth);

  cy.viewport({ zoom: 0.85, pan: { x: 250, y: 100 } });
  refreshGraphLabels(cy);

  const lines = node._private.rscratch.labelWrapCachedLines;
  expect(lines.length).toBeGreaterThan(oldLines.length);
  expect(lines.join(" ").replace(/\s+/g, " ").trim()).toBe(node.data("content"));
  expect(node._private.rscratch.labelWidth).not.toBe(oldWidth);
  expect(invalidate).toHaveBeenCalledOnce();
  const options = invalidate.mock.calls[0][1];
  expect(options.forceRedraw).toBe(true);
  expect(options.filterType("label")).toBe(true);
  expect(options.filterType("node-body")).toBe(false);
  expect(forceRender).toHaveBeenCalledOnce();
  expect(cy.zoom()).toBe(0.85);
  expect(cy.pan()).toEqual({ x: 250, y: 100 });
});

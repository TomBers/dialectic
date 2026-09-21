import cytoscape from "cytoscape";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { fitVisibleGraph, frameReadingGraph } from "../draw_graph.js";

const rect = (left, top, width, height) => ({
  left, top, width, height, right: left + width, bottom: top + height,
});

describe("graph overview", () => {
  let container;
  let cy;

  beforeEach(() => {
    container = document.createElement("div");
    container.getBoundingClientRect = () => rect(100, 80, 1000, 700);
    document.body.append(container);
  });

  afterEach(() => {
    cy?.destroy();
    document.body.replaceChildren();
  });

  const graph = (positions) => cytoscape({
    headless: true,
    styleEnabled: true,
    style: [{ selector: "node", style: { width: 240, height: 80 } }],
    minZoom: 0.05,
    maxZoom: 4,
    layout: { name: "preset", fit: false },
    elements: positions.map(([x, y], i) => ({
      data: { id: String(i) }, position: { x, y },
    })),
  });

  const expectInside = (nodes, { left = 56, top = 56, right = 944, bottom = 644 } = {}) => {
    const bounds = nodes.renderedBoundingBox();
    expect(bounds.x1).toBeGreaterThanOrEqual(left - 0.001);
    expect(bounds.y1).toBeGreaterThanOrEqual(top - 0.001);
    expect(bounds.x2).toBeLessThanOrEqual(right + 0.001);
    expect(bounds.y2).toBeLessThanOrEqual(bottom + 0.001);
  };

  it.each([
    ["tall", [[0, 0], [-200, 900], [200, 1800]]],
    ["wide", [[0, 0], [-2000, 200], [2000, 200]]],
  ])("shows the whole %s graph without centring the selected root", (_, positions) => {
    cy = graph(positions);
    cy.getElementById("0").addClass("selected");

    expect(fitVisibleGraph(cy, container)).toBe(true);

    expectInside(cy.nodes());
    const bounds = cy.nodes().renderedBoundingBox();
    expect((bounds.x1 + bounds.x2) / 2).toBeCloseTo(500);
    expect((bounds.y1 + bounds.y2) / 2).toBeCloseTo(350);
    expect(cy.getElementById("0").renderedPosition().y).toBeLessThan(350);
    expect(cy.getElementById("0").hasClass("selected")).toBe(true);
    expect(cy.zoom()).toBeLessThan(0.85);
  });

  it.each([1, 2])("keeps a %i-node grid at natural size", (count) => {
    cy = graph([[0, 0], [0, 180]].slice(0, count));
    fitVisibleGraph(cy, container);
    expect(cy.zoom()).toBe(1);
    expectInside(cy.nodes());
  });

  it("fits beside an open drawer and above the bottom toolbar", () => {
    const drawer = document.createElement("aside");
    drawer.dataset.rightDrawer = "";
    drawer.getBoundingClientRect = () => rect(800, 80, 300, 700);
    const toolbar = document.createElement("div");
    toolbar.id = "bottom-menu";
    toolbar.getBoundingClientRect = () => rect(100, 680, 1000, 100);
    document.body.append(drawer, toolbar);
    cy = graph([[-1200, -800], [1200, 800]]);

    fitVisibleGraph(cy, container);

    expectInside(cy.nodes(), { right: 644, bottom: 544 });
    const bounds = cy.nodes().renderedBoundingBox();
    expect((bounds.x1 + bounds.x2) / 2).toBeCloseTo(350);
    expect((bounds.y1 + bounds.y2) / 2).toBeCloseTo(300);
  });

  it("fits on a narrow phone canvas", () => {
    container.getBoundingClientRect = () => rect(0, 120, 390, 600);
    cy = graph([[-800, 0], [800, 0], [0, 600]]);
    fitVisibleGraph(cy, container);
    expectInside(cy.nodes(), { right: 334, bottom: 544 });
  });

  it.each(["hidden", "depth-hidden", "focus-hidden", "presentation-hidden", "presentation-hidden-parent"])(
    "excludes %s nodes from the overview",
    (hiddenClass) => {
      cy = graph([[0, 0], [0, 180], [10000, 10000]]);
      cy.getElementById("2").addClass(hiddenClass);
      fitVisibleGraph(cy, container);
      expect(cy.zoom()).toBe(1);
      expectInside(cy.nodes().not("#2"));
      expect(cy.getElementById("2").hasClass(hiddenClass)).toBe(true);
    },
  );

  it.each(["empty", "hidden", "unmeasurable", "destroyed"])(
    "leaves the viewport alone when the graph is %s",
    (state) => {
      cy = graph(state === "empty" ? [] : [[0, 0]]);
      cy.viewport({ zoom: 0.6, pan: { x: 100, y: 150 } });
      if (state === "hidden") cy.nodes().addClass("depth-hidden");
      if (state === "unmeasurable") container.getBoundingClientRect = () => rect(0, 0, 0, 0);
      if (state === "destroyed") cy.destroy();

      expect(fitVisibleGraph(cy, container)).toBe(false);
      expect(cy.zoom()).toBe(0.6);
      expect(cy.pan()).toEqual({ x: 100, y: 150 });
    },
  );

  it.each(["spaced", "compact"])("keeps %s titles readable when the whole graph cannot fit", (mode) => {
    cy = graph([[0, 0], [-2000, 900], [2000, 1800]]);

    expect(frameReadingGraph(cy, container, "0", mode)).toBe(true);

    expect(cy.zoom()).toBe(mode === "compact" ? 0.82 : 0.85);
    const root = cy.getElementById("0");
    expectInside(root);
    expect(root.renderedPosition().x).toBeCloseTo(500);
    expect(root.renderedPosition().y).toBeLessThan(700 / 3);
    expect(cy.nodes().renderedBoundingBox().y2).toBeGreaterThan(700);
  });

  it.each([
    ["TB", "y", 200], ["BT", "y", 500], ["LR", "x", 250], ["RL", "x", 750],
  ])("leaves room ahead of the selected idea in %s direction", (direction, axis, boundary) => {
    cy = graph([[0, 0], [1000, 1000], [2000, 2000]]);
    frameReadingGraph(cy, container, "1", "spaced", direction);
    const node = cy.getElementById("1");
    expectInside(node);
    if (["TB", "LR"].includes(direction)) {
      expect(node.renderedPosition()[axis]).toBeLessThan(boundary);
    } else {
      expect(node.renderedPosition()[axis]).toBeGreaterThan(boundary);
    }
  });

  it("keeps the selected title inside a phone viewport", () => {
    container.getBoundingClientRect = () => rect(0, 120, 320, 600);
    cy = graph([[0, 0], [800, 1500]]);
    frameReadingGraph(cy, container, "1");
    expectInside(cy.getElementById("1"), { right: 264, bottom: 544 });
  });

  it("keeps the reading anchor clear of an open drawer and bottom toolbar", () => {
    const drawer = document.createElement("aside");
    drawer.dataset.rightDrawer = "";
    drawer.getBoundingClientRect = () => rect(800, 80, 300, 700);
    const toolbar = document.createElement("div");
    toolbar.id = "bottom-menu";
    toolbar.getBoundingClientRect = () => rect(100, 680, 1000, 100);
    document.body.append(drawer, toolbar);
    cy = graph([[0, 0], [800, 1500]]);
    frameReadingGraph(cy, container, "0");
    expectInside(cy.getElementById("0"), { right: 644, bottom: 544 });
    expect(cy.getElementById("0").renderedPosition().x).toBeCloseTo(350);
    expect(cy.zoom()).toBe(0.85);
  });

  it("falls back to a visible node when an old selection is hidden", () => {
    cy = graph([[0, 0], [800, 1500]]);
    cy.getElementById("1").addClass("depth-hidden");
    frameReadingGraph(cy, container, "1");
    expectInside(cy.getElementById("0"));
    expect(cy.zoom()).toBe(1);
  });
});

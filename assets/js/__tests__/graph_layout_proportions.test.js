import { describe, expect, it } from "vitest";
import { graphStyle } from "../graph_style.js";
import { layoutConfig } from "../layout_config.js";

const styleFor = (styles, selector) =>
  styles.find((entry) => entry.selector === selector)?.style;

describe("graph layout proportions", () => {
  it("keeps graph levels more separated than sibling branches", () => {
    for (const layout of [
      layoutConfig.baseLayout,
      layoutConfig.compactLayout,
      layoutConfig.expandLayout,
    ]) {
      expect(layout.rankSep).toBeGreaterThan(layout.nodeSep);
    }
  });

  it("uses narrower spaced nodes while retaining readable text padding", () => {
    const nodeStyle = styleFor(graphStyle("spaced", "Example"), "node");
    const nodeWidth = nodeStyle.width({});

    expect(nodeWidth).toBeLessThan(312);
    expect(nodeStyle["text-max-width"]({})).toBeLessThan(nodeWidth);
  });

  it("uses larger text without counting node padding twice", () => {
    const nodeStyle = styleFor(graphStyle("spaced", "Example"), "node");
    const oneLineNode = { data: () => "A short node title" };

    expect(nodeStyle["font-size"]).toBe(18);
    expect(nodeStyle["font-weight"]).toBe(500);
    expect(nodeStyle.height(oneLineNode)).toBe(26);
    expect(nodeStyle.padding).toBe("14px");
  });

  it("keeps graph labels concise in reading and overview modes", () => {
    const longTitle = "A".repeat(140);
    const node = { data: () => longTitle };
    const spacedStyle = styleFor(graphStyle("spaced", "Example"), "node");
    const compactStyle = styleFor(graphStyle("compact", "Example"), "node");

    expect(spacedStyle.label(node)).toBe(`${"A".repeat(84)}…`);
    expect(compactStyle.label(node)).toBe(`${"A".repeat(56)}…`);
    expect(compactStyle["font-size"]).toBe(11);
  });
});

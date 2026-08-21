import cytoscape from "cytoscape";
import dagre from "cytoscape-dagre";
import { describe, expect, it } from "vitest";
import { graphStyle } from "../graph_style.js";
import { layoutConfig } from "../layout_config.js";

cytoscape.use(dagre);

const styleFor = (styles, selector) =>
  styles.find((entry) => entry.selector === selector)?.style;

describe("graph layout proportions", () => {
  const dagreLayouts = [
    layoutConfig.baseLayout,
    layoutConfig.compactLayout,
    layoutConfig.expandLayout,
  ];

  it("keeps graph levels separated and leaves room between sibling branches", () => {
    for (const layout of dagreLayouts) {
      expect(layout.rankSep).toBeGreaterThan(layout.nodeSep);
      expect(layout.nodeSep).toBeGreaterThan(layout.edgeSep);
    }
  });

  it("uses label dimensions and stable node ordering without curved routing", () => {
    for (const layout of dagreLayouts) {
      expect(layout.nodeDimensionsIncludeLabels).toBe(true);
      expect(layout).not.toHaveProperty("useDagreEdgeControlPoints");
      expect(layout).not.toHaveProperty("automaticDagreEdgeStyle");
      expect(layout).not.toHaveProperty("dagreEdgeStyle");
      expect(layout.sort({ id: () => "node-2" }, { id: () => "node-10" })).toBe(1);
    }
  });

  it("does not pass unsupported options to Dagre", () => {
    for (const layout of dagreLayouts) {
      expect(layout).not.toHaveProperty("weaveToward");
      expect(layout).not.toHaveProperty("gravity");
      expect(layout).not.toHaveProperty("nestingFactor");
    }
  });

  it("renders real Cytoscape edges with orthogonal relationship routing", () => {
    const cy = cytoscape({
      headless: true,
      styleEnabled: true,
      style: graphStyle("spaced", ""),
      elements: [
        { data: { id: "a" } },
        { data: { id: "b" } },
        { data: { id: "c" } },
        {
          classes: "selected-edge",
          data: { id: "a-b", source: "a", target: "b", relation: "clarify" },
        },
        { data: { id: "b-c", source: "b", target: "c" } },
        { data: { id: "a-c", source: "a", target: "c" } },
      ],
    });

    cy.layout({
      ...layoutConfig.baseLayout,
      animate: false,
      fit: false,
    }).run();

    expect(cy.getElementById("a-b").pstyle("label").value).toBe("clarifies");
    expect(cy.getElementById("a-b").pstyle("line-fill").value).toBe("solid");
    expect(cy.getElementById("b-c").pstyle("line-fill").value).toBe(
      "linear-gradient",
    );
    expect(cy.getElementById("b-c").pstyle("curve-style").value).toBe(
      "round-taxi",
    );
    expect(cy.getElementById("b-c").pstyle("taxi-direction").value).toBe(
      "vertical",
    );

    cy.destroy();
  });

  it("uses narrower spaced nodes while retaining readable text padding", () => {
    const nodeStyle = styleFor(graphStyle("spaced", "Example"), "node");
    const nodeWidth = nodeStyle.width({});

    expect(nodeWidth).toBeLessThan(312);
    expect(nodeStyle["text-max-width"]({})).toBeLessThan(nodeWidth);
  });

  it("uses compact idea labels without counting node padding twice", () => {
    const nodeStyle = styleFor(graphStyle("spaced", "Example"), "node");
    const oneLineNode = { data: () => "A short node title" };

    expect(nodeStyle["font-size"]).toBe(16);
    expect(nodeStyle["font-weight"]).toBe(500);
    expect(nodeStyle["text-metrics"]).toBe("glyph");
    expect(nodeStyle.height(oneLineNode)).toBe(22);
    expect(nodeStyle.padding).toBe("10px");
    expect(nodeStyle.ghost).toBe("no");
  });

  it("keeps taxi routing aligned with the graph direction", () => {
    const styles = graphStyle("spaced", "Example");
    const edgeStyle = styleFor(styles, "edge");

    const edgeA = { id: () => "edge-a" };
    const edgeB = { id: () => "edge-b" };

    expect(edgeStyle["curve-style"]).toBe("round-taxi");

    localStorage.setItem("graph_direction", "TB");
    expect(edgeStyle["taxi-direction"]()).toBe("vertical");
    localStorage.setItem("graph_direction", "LR");
    expect(edgeStyle["taxi-direction"]()).toBe("horizontal");
    localStorage.removeItem("graph_direction");
    expect(edgeStyle["taxi-turn"](edgeA)).toMatch(/^(38|42|46|50|54|58|62)%$/);
    expect(edgeStyle["taxi-turn"](edgeA)).not.toBe(edgeStyle["taxi-turn"](edgeB));
    expect(edgeStyle["taxi-turn-min-distance"]).toBe(18);
    expect(edgeStyle["taxi-radius"]).toBe(12);
    expect(edgeStyle["edge-distances"]).toBe("intersection");
    expect(edgeStyle["line-fill"]).toBe("linear-gradient");
    expect(edgeStyle["line-gradient-stop-positions"]).toBe("0% 100%");
  });

  it("reveals generation relationships only for contextual edges", () => {
    const styles = graphStyle("spaced", "Example");
    const edgeStyle = styleFor(styles, "edge");
    const hoverStyle = styleFor(styles, ".edge-hover");
    const selectedStyle = styleFor(styles, "edge.selected-edge");
    const relationEdge = {
      data: (key) => (key === "relation" ? "counterexample" : undefined),
      target: () => ({ classes: () => [] }),
    };
    const legacyEdge = {
      data: () => undefined,
      target: () => ({ classes: () => ["clarify"] }),
    };
    const unknownEdge = {
      data: () => "new_relation",
      target: () => ({ classes: () => [] }),
    };

    expect(edgeStyle.label).toBe("");
    expect(hoverStyle.label(relationEdge)).toBe("tests with a counterexample");
    expect(selectedStyle.label(relationEdge)).toBe("tests with a counterexample");
    expect(hoverStyle.label(legacyEdge)).toBe("clarifies");
    expect(hoverStyle.label(unknownEdge)).toBe("leads to");
    expect(hoverStyle["text-rotation"]).toBe("none");
    expect(selectedStyle["text-rotation"]).toBe("none");
  });

  it("keeps graph labels concise in reading and overview modes", () => {
    const longTitle = "A".repeat(140);
    const node = { data: () => longTitle };
    const spacedStyle = styleFor(graphStyle("spaced", "Example"), "node");
    const compactStyle = styleFor(graphStyle("compact", "Example"), "node");

    expect(spacedStyle.label(node)).toBe(`${"A".repeat(52)}…`);
    expect(compactStyle.label(node)).toBe(`${"A".repeat(36)}…`);
    expect(compactStyle["font-size"]).toBe(11);
  });
});

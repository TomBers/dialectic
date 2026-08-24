import { describe, expect, it } from "vitest";
import { graphStyle } from "../graph_style.js";

const styleFor = (styles, selector) =>
  styles.find((entry) => entry.selector === selector)?.style;

describe("graph accessibility styles", () => {
  it("strengthens node colour, borders, and edges in high contrast mode", () => {
    const regular = graphStyle("spaced", "Example");
    const highContrast = graphStyle("spaced", "Example", {
      highContrast: true,
    });

    expect(styleFor(highContrast, "node.question")["background-color"]).not.toBe(
      styleFor(regular, "node.question")["background-color"],
    );
    expect(styleFor(highContrast, "node.question")["border-width"]).toBeGreaterThan(
      styleFor(regular, "node.question")["border-width"],
    );
    expect(styleFor(highContrast, "edge").opacity).toBeGreaterThan(
      styleFor(regular, "edge").opacity,
    );
    expect(styleFor(highContrast, "edge")["line-gradient-stop-colors"]).not.toBe(
      styleFor(regular, "edge")["line-gradient-stop-colors"],
    );
  });

  it("keeps highlighted relationships readable on a solid accent colour", () => {
    const styles = graphStyle("spaced", "Example");
    const highContrast = graphStyle("spaced", "Example", {
      highContrast: true,
    });

    expect(styleFor(styles, ".edge-hover")["line-fill"]).toBe("solid");
    expect(styleFor(styles, "edge.selected-edge")["line-fill"]).toBe("solid");
    expect(styleFor(styles, "edge.presentation-edge")["line-fill"]).toBe("solid");
    expect(styleFor(styles, "edge.presentation-edge-active")["line-fill"]).toBe(
      "solid",
    );
    expect(
      styleFor(highContrast, "edge.selected-edge")["text-background-opacity"],
    ).toBe(1);
    expect(styleFor(highContrast, "edge.selected-edge")["text-border-width"]).toBe(
      1,
    );
  });

  it("removes Cytoscape style transitions when reduced motion is enabled", () => {
    const reducedMotion = graphStyle("spaced", "Example", {
      reduceMotion: true,
    });

    expect(styleFor(reducedMotion, "node")["transition-duration"]).toBe("0ms");
    expect(styleFor(reducedMotion, "edge")["transition-duration"]).toBe("0ms");
  });
});

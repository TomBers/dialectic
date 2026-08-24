import { describe, expect, it } from "vitest";
import {
  balanceCanvasLines,
  fitCanvasText,
  wrapCanvasText,
} from "../share_hook.js";

function measuredContext() {
  return {
    font: "",
    measureText(text) {
      const size = Number(this.font.match(/(\d+(?:\.\d+)?)px/)?.[1] || 16);
      return { width: Array.from(text).length * size * 0.55 };
    },
  };
}

describe("share card canvas typography", () => {
  it("wraps using measured text width", () => {
    const ctx = measuredContext();
    ctx.font = "700 40px Georgia";

    const lines = wrapCanvasText(
      ctx,
      "Discuss the fairness and public ethics around reserving shared seats",
      280,
    );

    expect(lines.length).toBeGreaterThan(1);
    expect(lines.every((line) => ctx.measureText(line).width <= 280)).toBe(true);
  });

  it("shrinks and truncates so every line stays inside both bounds", () => {
    const ctx = measuredContext();
    const text = Array(30).fill("unusuallylongdiscussion").join(" ");
    const layout = fitCanvasText(ctx, text, 320, 150, {
      maxFontSize: 72,
      minFontSize: 30,
    });

    expect(layout.lines.length * layout.lineHeight).toBeLessThanOrEqual(150);
    expect(layout.lines.every((line) => ctx.measureText(line).width <= 320)).toBe(true);
    expect(layout.lines.at(-1)).toMatch(/…$/);
  });

  it("balances awkward final lines without changing the measured bounds", () => {
    const ctx = measuredContext();
    ctx.font = "600 40px Georgia";

    const lines = balanceCanvasLines(
      ctx,
      ["A deliberately longer opening line", "with a short ending"],
      900,
    );

    const difference = Math.abs(
      ctx.measureText(lines[0]).width - ctx.measureText(lines[1]).width,
    );
    const originalDifference = Math.abs(
      ctx.measureText("A deliberately longer opening line").width -
        ctx.measureText("with a short ending").width,
    );

    expect(difference).toBeLessThan(originalDifference);
    expect(lines.every((line) => ctx.measureText(line).width <= 900)).toBe(true);
  });
});

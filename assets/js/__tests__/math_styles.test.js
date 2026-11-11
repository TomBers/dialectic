import {afterEach, beforeEach, expect, it, vi} from "vitest";

let loadMathStyles;
beforeEach(async () => {
  vi.resetModules();
  ({loadMathStyles} = await import("../math_styles.js"));
  document.body.dataset.katexStylesheet = "/assets/katex-0123456789abcdef0123456789abcdef.css?vsn=d";
});
afterEach(() => {
  document.head.querySelectorAll("link[data-math-styles]").forEach(link => link.remove());
  delete document.body.dataset.katexStylesheet;
});

it("shares the versioned stylesheet load between answers and waits until it is ready", async () => {
  const first = loadMathStyles();
  const second = loadMathStyles();
  expect(first).toBe(second);
  expect(document.head.querySelectorAll("link[data-math-styles]")).toHaveLength(1);
  const link = document.head.querySelector("link[data-math-styles]");
  expect(link.getAttribute("href")).toBe(document.body.dataset.katexStylesheet);
  expect(link.rel).toBe("stylesheet");
  link.dispatchEvent(new Event("load"));
  await first;
});

it("removes a failed stylesheet and allows the next request to retry", async () => {
  const first = loadMathStyles();
  const rejected = expect(first).rejects.toThrow("Math stylesheet could not load");
  document.head.querySelector("link[data-math-styles]").dispatchEvent(new Event("error"));
  await rejected;
  expect(document.head.querySelector("link[data-math-styles]")).toBeNull();
  const retry = loadMathStyles();
  document.head.querySelector("link[data-math-styles]").dispatchEvent(new Event("load"));
  await retry;
});

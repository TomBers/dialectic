import { describe, expect, it } from "vitest";
import {
  appearanceFromDataset,
  syncGraphAppearanceStorage,
} from "../appearance_preferences.js";

const memoryStorage = (initial = {}) => {
  const values = new Map(Object.entries(initial));

  return {
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => values.set(key, value),
  };
};

describe("appearance preferences", () => {
  it("reads validated server-rendered values", () => {
    expect(
      appearanceFromDataset({
        readingDensity: "large",
        readingFont: "serif",
        graphViewMode: "compact",
        graphDirection: "LR",
        reduceMotion: "true",
        highContrast: "true",
      }),
    ).toEqual({
      readingDensity: "large",
      readingFont: "serif",
      graphViewMode: "compact",
      graphDirection: "LR",
      reduceMotion: true,
      highContrast: true,
    });
  });

  it("falls back to guest defaults for missing or invalid values", () => {
    expect(appearanceFromDataset({ graphDirection: "diagonal" })).toEqual({
      readingDensity: "comfortable",
      readingFont: "serif",
      graphViewMode: "spaced",
      graphDirection: "TB",
      reduceMotion: false,
      highContrast: false,
    });
  });

  it("replaces stale graph layout values with server preferences", () => {
    const storage = memoryStorage({
      graph_view_mode: "compact",
      graph_direction: "RL",
    });

    syncGraphAppearanceStorage(
      { graphViewMode: "spaced", graphDirection: "TB" },
      storage,
    );

    expect(storage.getItem("graph_view_mode")).toBe("spaced");
    expect(storage.getItem("graph_direction")).toBe("TB");
  });
});

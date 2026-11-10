import { describe, expect, it, vi } from "vitest";
import { cachedHighlight, nodeHighlights, subscribeHighlights } from "../highlight_cache.js";

const item = (id, node_id) => ({id, node_id, selection_start: 0, selection_end: 5, links: []});
const send = (graph_id, highlights) => window.dispatchEvent(new CustomEvent("phx:highlights_loaded", {detail: {graph_id, highlights}}));

describe("shared highlight updates", () => {
  it("notifies only changed nodes and keeps different graphs separate", () => {
    const first = vi.fn(), second = vi.fn(), other = vi.fn();
    const unsubscribes = [subscribeHighlights("a", "1", first), subscribeHighlights("a", "2", second), subscribeHighlights("b", "1", other)];
    try {
      send("a", [item(1, "1"), item(2, "2")]);
      expect(first).toHaveBeenCalledTimes(1);
      expect(second).toHaveBeenCalledTimes(1);
      expect(other).not.toHaveBeenCalled();
      send("a", [item(2, "2"), {...item(1, "1"), links: [{node_id: "3", link_type: "explain"}]}]);
      expect(first).toHaveBeenCalledTimes(2);
      expect(second).toHaveBeenCalledTimes(1);
      expect(nodeHighlights("a", "1")[0].links).toHaveLength(1);
      expect(nodeHighlights("b", "1")).toEqual([]);
      expect(cachedHighlight("a", 2).node_id).toBe("2");
      send("a", [item(2, "2")]);
      expect(first).toHaveBeenCalledTimes(3);
      expect(nodeHighlights("a", "1")).toEqual([]);
    } finally { unsubscribes.forEach(unsubscribe => unsubscribe()); }
    expect(nodeHighlights("a", "2")).toEqual([]);
  });

  it("keeps updates for remaining subscribers and clears stale data on remount", () => {
    const one = subscribeHighlights("a", "1", () => {});
    const callback = vi.fn();
    const two = subscribeHighlights("a", "1", callback);
    one();
    send("a", [item(1, "1")]);
    expect(callback).toHaveBeenCalledTimes(1);
    two();
    const three = subscribeHighlights("a", "1", callback);
    expect(nodeHighlights("a", "1")).toEqual([]);
    three();
  });
});

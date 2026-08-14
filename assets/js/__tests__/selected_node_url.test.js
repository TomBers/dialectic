import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { syncSelectedNodeUrl } from "../selected_node_url.js";

beforeEach(() => {
  window.history.replaceState({}, "", "/g/test-topic/graph?node=1&token=share#detail");
});

afterEach(() => {
  window.history.replaceState({}, "", "/");
});

describe("syncSelectedNodeUrl", () => {
  it("replaces the selected node while preserving other URL state", () => {
    syncSelectedNodeUrl("32");

    expect(window.location.pathname).toBe("/g/test-topic/graph");
    expect(window.location.search).toBe("?node=32&token=share");
    expect(window.location.hash).toBe("#detail");
  });

  it("does not change non-graph pages", () => {
    window.history.replaceState({}, "", "/g/test-topic?node=1");

    syncSelectedNodeUrl("32");

    expect(window.location.href).toBe("http://localhost:3000/g/test-topic?node=1");
  });

  it("does not add an empty node", () => {
    syncSelectedNodeUrl("");

    expect(window.location.search).toBe("?node=1&token=share");
  });
});

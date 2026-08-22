import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { syncSelectedNodeUrl } from "../selected_node_url.js";

beforeEach(() => {
  document.body.innerHTML = "";
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

  it("synchronizes the reader link with the current node and path", () => {
    document.body.innerHTML = `
      <a id="graph-workspace-bar-reader" href="/g/test-topic?node=1&token=share">Read</a>
    `;
    window.history.replaceState(
      {},
      "",
      "/g/test-topic/graph?node=1&token=share&path=9",
    );

    syncSelectedNodeUrl("32");

    const readerUrl = new URL(
      document.getElementById("graph-workspace-bar-reader").href,
    );
    expect(readerUrl.pathname).toBe("/g/test-topic");
    expect(readerUrl.searchParams.get("node")).toBe("32");
    expect(readerUrl.searchParams.get("path")).toBe("9");
    expect(readerUrl.searchParams.get("token")).toBe("share");
  });

  it("removes a stale path from the reader link", () => {
    document.body.innerHTML = `
      <a id="graph-workspace-bar-reader" href="/g/test-topic?node=1&path=9">Read</a>
    `;

    syncSelectedNodeUrl("1");

    const readerUrl = new URL(
      document.getElementById("graph-workspace-bar-reader").href,
    );
    expect(readerUrl.searchParams.has("path")).toBe(false);
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

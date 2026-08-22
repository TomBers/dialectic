export function syncSelectedNodeUrl(nodeId) {
  if (nodeId === null || nodeId === undefined || nodeId === "") return;

  const url = new URL(window.location.href);
  if (!/\/graph\/?$/.test(url.pathname)) return;

  const selectedNode = String(nodeId);

  if (url.searchParams.get("node") !== selectedNode) {
    url.searchParams.set("node", selectedNode);
    window.history.replaceState(
      window.history.state,
      "",
      `${url.pathname}${url.search}${url.hash}`,
    );
  }

  const readerLink = document.getElementById("graph-workspace-bar-reader");
  if (!readerLink) return;

  const readerUrl = new URL(readerLink.getAttribute("href"), window.location.origin);
  readerUrl.searchParams.set("node", selectedNode);

  const pathEndpoint = url.searchParams.get("path");
  if (pathEndpoint) {
    readerUrl.searchParams.set("path", pathEndpoint);
  } else {
    readerUrl.searchParams.delete("path");
  }

  readerLink.setAttribute(
    "href",
    `${readerUrl.pathname}${readerUrl.search}${readerUrl.hash}`,
  );
}

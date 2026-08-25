export function syncSelectedNodeUrl(nodeId, pathEndpoint) {
  if (nodeId === null || nodeId === undefined || nodeId === "") return;

  const url = new URL(window.location.href);
  if (!/\/graph\/?$/.test(url.pathname)) return;

  const selectedNode = String(nodeId);
  let urlChanged = false;

  if (pathEndpoint !== undefined && pathEndpoint !== null && pathEndpoint !== "") {
    const selectedPath = String(pathEndpoint);
    if (url.searchParams.get("path") !== selectedPath) {
      url.searchParams.set("path", selectedPath);
      urlChanged = true;
    }
  }

  if (url.searchParams.get("node") !== selectedNode) {
    url.searchParams.set("node", selectedNode);
    urlChanged = true;
  }

  if (urlChanged) {
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

  const activePathEndpoint = url.searchParams.get("path");
  if (activePathEndpoint) {
    readerUrl.searchParams.set("path", activePathEndpoint);
  } else {
    readerUrl.searchParams.delete("path");
  }

  readerLink.setAttribute(
    "href",
    `${readerUrl.pathname}${readerUrl.search}${readerUrl.hash}`,
  );
}

export function syncSelectedNodeUrl(nodeId) {
  if (nodeId === null || nodeId === undefined || nodeId === "") return;

  const url = new URL(window.location.href);
  if (!/\/graph\/?$/.test(url.pathname)) return;

  const selectedNode = String(nodeId);
  if (url.searchParams.get("node") === selectedNode) return;

  url.searchParams.set("node", selectedNode);
  window.history.replaceState(
    window.history.state,
    "",
    `${url.pathname}${url.search}${url.hash}`,
  );
}

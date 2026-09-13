export function preserveAuthReturn(event) {
  const link = event.target.closest?.("a[href]");
  if (!link || !/^\/g\/[^/]+(?:\/graph)?$/.test(window.location.pathname)) return;

  const destination = new URL(link.href, window.location.href);
  if (destination.origin !== window.location.origin ||
      !["/users/log_in", "/users/register", "/auth/google"].includes(destination.pathname)) return;

  const returnTo = new URL(window.location.href);
  const nodeId = link.closest("[data-auth-return-node]")?.dataset.authReturnNode;
  if (nodeId) {
    returnTo.searchParams.set("node", nodeId);
    if (!returnTo.pathname.endsWith("/graph")) returnTo.hash = `reading-node-${nodeId}`;
  }
  destination.searchParams.set("return_to", returnTo.pathname + returnTo.search + returnTo.hash);
  link.href = destination.href;
  // A full request stores the destination before entering the authentication flow.
  link.removeAttribute("data-phx-link");
  link.removeAttribute("data-phx-link-state");
}

export function initAuthReturn() {
  document.addEventListener("pointerdown", preserveAuthReturn, true);
  document.addEventListener("focusin", preserveAuthReturn, true);
  document.addEventListener("click", preserveAuthReturn, true);
  document.addEventListener("auxclick", preserveAuthReturn, true);
}

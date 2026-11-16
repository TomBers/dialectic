// Keep fragment links useful when their destinations are in closed disclosures.
export function initDisclosureNavigation(root, { revealTarget = () => {} } = {}) {
  if (!root) return;

  const reveal = (hash) => {
    let id;
    try {
      id = decodeURIComponent(hash.slice(1));
    } catch {
      return;
    }

    const target = document.getElementById(id);
    if (!target || !root.contains(target)) return;
    revealTarget(target);

    const disclosures = [];
    for (let element = target; element !== root; element = element.parentElement) {
      if (element.tagName === "DETAILS") disclosures.unshift(element);
    }
    disclosures.forEach((element) => { element.open = true; });

    const focusTarget = target.tagName === "DETAILS"
      ? target.querySelector("summary") : target;
    if (focusTarget.tabIndex < 0 && !focusTarget.hasAttribute("tabindex")) {
      focusTarget.setAttribute("tabindex", "-1");
    }
    focusTarget.focus({ preventScroll: true });
    target.scrollIntoView({ block: "start" });
  };

  const onHashChange = () => reveal(window.location.hash);
  const onClick = (event) => {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey ||
        event.shiftKey || event.altKey) return;
    const link = event.target.closest("a[href]");
    if (!link || link.hasAttribute("download") || (link.target && link.target !== "_self")) return;
    const url = new URL(link.href);
    // A repeated link must reopen a disclosure the reader has since closed.
    if (url.href === window.location.href) reveal(url.hash);
  };

  window.addEventListener("hashchange", onHashChange);
  root.addEventListener("click", onClick);
  onHashChange();

  return () => {
    window.removeEventListener("hashchange", onHashChange);
    root.removeEventListener("click", onClick);
  };
}

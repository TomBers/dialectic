export function syncDrawerAccessibility(panel, open) {
  panel.inert = !open;
  if (open) panel.removeAttribute("aria-hidden");
  else panel.setAttribute("aria-hidden", "true");
}

export function createDrawerNavigation(root, onClose) {
  let panel = null;
  let returnFocus = null;
  let focusFrame = null;
  let focusSection = null;

  const keydown = (event) => {
    if (!panel || event.defaultPrevented || event.key !== "Escape" ||
        !(event.target instanceof Element)) return;
    if (!panel.contains(event.target) && event.target !== returnFocus) return;
    if (event.target.closest('[role="dialog"], [aria-modal="true"]')) return;
    event.preventDefault();
    event.stopPropagation();
    onClose(panel.id);
  };
  root.addEventListener("keydown", keydown);

  const cancelFocus = () => {
    if (focusFrame !== null) cancelAnimationFrame(focusFrame);
    focusFrame = null;
  };

  const focusPanel = () => {
    focusFrame = requestAnimationFrame(() => {
      focusFrame = null;
      if (!panel?.isConnected || panel.inert) return;
      const sectionHeading = focusSection === "reading-style" ? "#reading-style-heading" :
        focusSection ? `#details-${CSS.escape(focusSection)} > summary` : null;
      const destination = (sectionHeading && panel.querySelector(sectionHeading)) ||
        panel.querySelector('[data-panel-close], button[aria-label^="Close"]') || panel;
      if (!destination.hasAttribute("tabindex") && destination === panel) destination.tabIndex = -1;
      destination.focus({ preventScroll: true });
    });
  };

  return {
    open(nextPanel, trigger, section = null) {
      cancelFocus();
      const candidate = trigger instanceof HTMLElement ? trigger : document.activeElement;
      if (candidate instanceof HTMLElement && !candidate.closest("[data-right-drawer]")) {
        returnFocus = candidate;
      }
      panel = nextPanel;
      focusSection = section;
      focusPanel();
    },
    refresh() {
      if (panel && document.activeElement === document.body) {
        cancelFocus();
        focusPanel();
      }
    },
    close() {
      cancelFocus();
      if (!panel) return;
      const restore = panel.contains(document.activeElement) || document.activeElement === document.body;
      panel = null;
      if (restore && returnFocus?.isConnected && !returnFocus.closest("[inert]")) {
        returnFocus.focus({ preventScroll: true });
      }
      returnFocus = null;
    },
    destroy() {
      cancelFocus();
      root.removeEventListener("keydown", keydown);
      panel = null;
      returnFocus = null;
    },
  };
}

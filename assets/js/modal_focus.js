export const containModalFocus = (element, { onEscape } = {}) => {
  const siblings = [];
  let branch = element;
  while (branch.parentElement && branch !== document.body) {
    for (const sibling of branch.parentElement.children) {
      if (sibling === branch || sibling.id.endsWith("-backdrop")) continue;
      siblings.push([sibling, sibling.inert]);
      sibling.inert = true;
    }
    branch = branch.parentElement;
  }

  const items = () => Array.from(element.querySelectorAll('input, button, select, textarea, a[href], [tabindex="0"]'))
    .filter((el) => !el.disabled && el.tabIndex >= 0 && el.getClientRects().length > 0 && !el.closest('[aria-hidden="true"], [inert]'));

  const keydown = (event) => {
    if (event.key === "Escape" && onEscape) {
      event.preventDefault();
      event.stopImmediatePropagation();
      onEscape();
    }
    if (event.key !== "Tab") return;
    const focusable = items();
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    if (!first) return;
    if (!element.contains(document.activeElement) || (event.shiftKey && document.activeElement === first)) {
      event.preventDefault();
      (event.shiftKey ? last : first).focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  };
  document.addEventListener("keydown", keydown, true);
  return {
    focusFirst: () => items()[0]?.focus({ preventScroll: true }),
    refresh: () => siblings.forEach(([sibling]) => { sibling.inert = true; }),
    destroy: () => {
      document.removeEventListener("keydown", keydown, true);
      siblings.forEach(([sibling, inert]) => { sibling.inert = inert; });
    },
  };
};

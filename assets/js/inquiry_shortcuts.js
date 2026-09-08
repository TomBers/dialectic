export function syncInquiryShortcutLabels(root) {
  const mac = /Mac|iPhone|iPad|iPod/i.test(navigator.userAgentData?.platform || navigator.platform);
  root.dataset.shortcutPlatform = mac ? "mac" : "windows";
  root.querySelectorAll("[data-reader-shortcut]").forEach((button) => {
    const key = button.dataset.readerShortcut.toUpperCase();
    button.setAttribute("aria-keyshortcuts", `Alt+Shift+${key}`);
    button.title = `${mac ? "Option" : "Alt"}+Shift+${key} (when not typing)`;
  });
}

export function handleInquiryShortcut(event, root) {
  const target = event.target;
  if (!root?.contains(target) || event.defaultPrevented || event.isComposing ||
      event.repeat || !event.altKey || !event.shiftKey || event.metaKey || event.ctrlKey ||
      target.matches("input, textarea, select") || target.isContentEditable) return false;

  const key = /^Key[A-Z]$/.test(event.code) ? event.code.slice(3).toLowerCase() : event.key.toLowerCase();
  if (!["a", "c", "r", "e", "h"].includes(key)) return false;
  const button = root.querySelector(`[data-reader-shortcut="${key}"]`);
  if (!button || button.disabled) return false;

  event.preventDefault();
  event.stopPropagation();
  button.focus({ preventScroll: true });
  button.scrollIntoView({ block: "nearest" });
  button.click();
  return true;
}

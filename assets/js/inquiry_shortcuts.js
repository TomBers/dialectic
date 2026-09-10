function macPlatform() {
  return /Mac|iPhone|iPad|iPod/i.test(navigator.userAgentData?.platform || navigator.platform);
}

export function syncInquiryShortcutLabels(root) {
  const mac = macPlatform();
  root.dataset.shortcutPlatform = mac ? "mac" : "windows";
  root.querySelectorAll("[data-reader-shortcut]").forEach((button) => {
    const key = button.dataset.readerShortcut.toUpperCase();
    const unmodified = button.dataset.readerShortcutModifier === "none";
    button.setAttribute("aria-keyshortcuts", `${unmodified ? "" : mac ? "Meta+" : "Control+"}${key}`);
    button.title = `${unmodified ? "" : mac ? "Command+" : "Ctrl+"}${key} (when not typing)`;
  });
}

export function handleInquiryShortcut(event, root) {
  const target = event.target;
  if (!root?.contains(target) || event.defaultPrevented || event.isComposing ||
      event.repeat || event.altKey || event.shiftKey ||
      target.matches("input, textarea, select") || target.isContentEditable) return false;

  const key = /^Key[A-Z]$/.test(event.code) ? event.code.slice(3).toLowerCase() : event.key.toLowerCase();
  if (!["a", "c", "r", "b", "e", "h", "t"].includes(key)) return false;
  if (key === "c" && window.getSelection()?.toString()) return false;
  const button = root.querySelector(`[data-reader-shortcut="${key}"]`);
  if (!button || button.disabled) return false;
  const modifierMatches = button.dataset.readerShortcutModifier === "none"
    ? !event.metaKey && !event.ctrlKey
    : macPlatform() ? event.metaKey && !event.ctrlKey : event.ctrlKey && !event.metaKey;
  if (!modifierMatches) return false;

  event.preventDefault();
  event.stopPropagation();
  button.focus({ preventScroll: true });
  button.scrollIntoView({ block: "nearest" });
  button.click();
  return true;
}

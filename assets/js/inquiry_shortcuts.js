export function syncInquiryShortcutLabels(root) {
  const mac = /Mac|iPhone|iPad|iPod/i.test(navigator.userAgentData?.platform || navigator.platform);
  root.dataset.shortcutPlatform = mac ? "mac" : "windows";
  root.querySelectorAll("[data-reader-shortcut]").forEach((button) => {
    const key = button.dataset.readerShortcut.toUpperCase();
    const shift = button.dataset.shortcutShift === "true" ? "Shift+" : "";
    button.setAttribute("aria-keyshortcuts", `${mac ? "Meta" : "Control"}+${shift}${key}`);
    button.title = `${mac ? "⌘" : "Ctrl"}+${shift}${key} (when not typing)`;
  });
}

export function handleInquiryShortcut(event, root) {
  const target = event.target;
  if (!root?.contains(target) || event.defaultPrevented || event.isComposing ||
      event.repeat || event.altKey || !(event.metaKey || event.ctrlKey) ||
      target.matches("input, textarea, select") || target.isContentEditable) return false;

  const key = event.key.toLowerCase();
  if (!["a", "c", "r", "e", "h"].includes(key)) return false;
  const button = root.querySelector(`[data-reader-shortcut="${key}"]`);
  if (!button || button.disabled || event.shiftKey !== (button.dataset.shortcutShift === "true")) return false;

  event.preventDefault();
  event.stopPropagation();
  button.focus({ preventScroll: true });
  button.scrollIntoView({ block: "nearest" });
  button.click();
  return true;
}

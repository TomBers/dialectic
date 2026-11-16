import { initDisclosureNavigation } from "./disclosure_navigation.js";

export function initThinkingToolsGuide() {
  const root = document.getElementById("thinking-tools-guide");
  if (!root) return;

  return initDisclosureNavigation(root, {
    revealTarget(target) {
      const group = target.closest("[data-thinking-goal]");
      if (group) {
        root.querySelectorAll("[data-thinking-goal]").forEach((other) => {
          if (other !== group) other.open = false;
        });
      }
      if (target.matches("[data-thinking-tool]")) {
        target.querySelector("details").open = true;
      }
    },
  });
}

/**
 * Node Type Badges - Displays small badge overlays on Cytoscape nodes
 * to indicate their type (thesis, antithesis, synthesis, etc.)
 */

// Type abbreviations and display config
const TYPE_CONFIG = {
  thesis: {
    abbrev: "Pro",
    label: "Thesis",
    bg: "#d1fae5",
    border: "#34d399",
    text: "#064e3b",
  },
  antithesis: {
    abbrev: "Con",
    label: "Antithesis",
    bg: "#fee2e2",
    border: "#f87171",
    text: "#7f1d1d",
  },
  synthesis: {
    abbrev: "Blend",
    label: "Synthesis",
    bg: "#f3e8ff",
    border: "#a78bfa",
    text: "#581c87",
  },
  question: {
    abbrev: "Qn",
    label: "Question",
    bg: "#e0f2fe",
    border: "#0ea5e9",
    text: "#0c4a6e",
  },
  user: {
    abbrev: "U",
    label: "User",
    bg: "#bbf7d0",
    border: "#16a34a",
    text: "#14532d",
  },
  deepdive: {
    abbrev: "DD",
    label: "Deep Dive",
    bg: "#cffafe",
    border: "#22d3ee",
    text: "#164e63",
  },
  origin: {
    abbrev: "O",
    label: "Origin",
    bg: "#e2e8f0",
    border: "#64748b",
    text: "#1e293b",
  },
  ideas: {
    abbrev: "ID",
    label: "Ideas",
    bg: "#ffedd5",
    border: "#fb923c",
    text: "#7c2d12",
  },
  answer: {
    abbrev: "Ans",
    label: "Answer",
    bg: "#f3f4f6",
    border: "#9ca3af",
    text: "#374151",
  },
  explain: {
    abbrev: "EX",
    label: "Explain",
    bg: "#f3f4f6",
    border: "#9ca3af",
    text: "#374151",
  },
  clarify: {
    abbrev: "CL",
    label: "Clarify",
    bg: "#f3f4f6",
    border: "#9ca3af",
    text: "#374151",
  },
  assumption: {
    abbrev: "AS",
    label: "Assumption",
    bg: "#fef9c3",
    border: "#facc15",
    text: "#713f12",
  },
  premise: {
    abbrev: "PR",
    label: "Premise",
    bg: "#dbeafe",
    border: "#3b82f6",
    text: "#1e3a8a",
  },
  conclusion: {
    abbrev: "CO",
    label: "Conclusion",
    bg: "#fce7f3",
    border: "#ec4899",
    text: "#831843",
  },
};

let stylesInjected = false;

/**
 * Inject CSS styles for type badges
 */
function _injectTypeBadgeStyles() {
  if (stylesInjected) return;
  stylesInjected = true;

  const s = document.createElement("style");
  s.id = "node-type-badge-styles";
  s.textContent = `
/* Container for all type badges */
.type-badge-overlay {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
  z-index: 1;
  overflow: visible;
}

/* Individual type badge */
.type-badge {
  position: absolute;
  pointer-events: auto;
  font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
  font-size: 9px;
  font-weight: 600;
  line-height: 1;
  padding: 2px 4px;
  border-radius: 4px;
  border: 1px solid;
  white-space: nowrap;
  cursor: default;
  user-select: none;
  opacity: 0.9;
  transition: opacity 0.15s ease, transform 0.15s ease;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
  transform-origin: center center;
}

.type-badge:hover {
  opacity: 1;
  z-index: 2;
}

/* Badge positioning - badges float outside node bounds */
.type-badge.badge-dir-tb,
.type-badge.badge-dir-lr {
  transform: translate(0, -100%);
}

.type-badge.badge-dir-bt {
  transform: translate(0, 0);
}

.type-badge.badge-dir-rl {
  transform: translate(-100%, -100%);
}

/* Hide badges when zoomed out too far for readability */
.type-badge.badge-hidden {
  display: none;
}
`;
  document.head.appendChild(s);
}

/**
 * Get the node type from its classes
 */
function getNodeType(node) {
  const classes = node.classes();
  for (const cls of classes) {
    if (TYPE_CONFIG[cls]) {
      return cls;
    }
  }
  return null;
}

/**
 * Get badge configuration for a type
 */
function getBadgeConfig(type) {
  return TYPE_CONFIG[type] || null;
}

/**
 * Build all type badge overlays for visible nodes
 */
export function rebuildTypeBadgeOverlays(cy, container) {
  if (!container) return;

  _injectTypeBadgeStyles();

  // Create or reuse the overlay container
  let overlay = container.querySelector(".type-badge-overlay");
  if (!overlay) {
    overlay = document.createElement("div");
    overlay.className = "type-badge-overlay";
    // Ensure the graph container is a positioning context
    const pos = getComputedStyle(container).position;
    if (pos === "static") container.style.position = "relative";
    container.appendChild(overlay);
  }

  // Clear old badges
  overlay.innerHTML = "";

  // Store refs on the cy instance for position updates
  cy._typeBadgeOverlay = overlay;
  cy._typeBadges = new Map();

  // Find visible, non-compound nodes
  const visible = cy
    .nodes()
    .filter(
      (n) =>
        !n.isParent() && !n.hasClass("depth-hidden") && !n.hasClass("hidden"),
    );

  visible.forEach((n) => {
    const type = getNodeType(n);
    if (!type) return; // No recognized type

    const config = getBadgeConfig(type);
    if (!config) return;

    const badge = document.createElement("div");
    badge.className = "type-badge";
    badge.textContent = config.abbrev;
    badge.title = config.label;
    badge.dataset.nodeId = n.id();
    badge.dataset.nodeType = type;

    // Apply type-specific colors
    badge.style.backgroundColor = config.bg;
    badge.style.borderColor = config.border;
    badge.style.color = config.text;

    overlay.appendChild(badge);
    cy._typeBadges.set(n.id(), badge);
  });

  updateTypeBadgePositions(cy);
}

/**
 * Update positions of all type badges based on node positions
 * Called on pan/zoom/render
 */
export function updateTypeBadgePositions(cy) {
  if (!cy._typeBadges) return;

  const zoom = cy.zoom();
  const dir = localStorage.getItem("graph_direction") || "TB";

  // Hide badges when zoomed out too far (below 0.4 zoom)
  const showBadges = zoom >= 0.3;

  cy._typeBadges.forEach((badge, nodeId) => {
    const node = cy.getElementById(nodeId);
    if (
      !node ||
      node.length === 0 ||
      node.hasClass("depth-hidden") ||
      node.hasClass("hidden")
    ) {
      badge.style.display = "none";
      return;
    }

    if (!showBadges) {
      badge.classList.add("badge-hidden");
      return;
    }

    badge.classList.remove("badge-hidden");
    badge.style.display = "";

    // Get node bounding box in rendered coordinates
    const bb = node.renderedBoundingBox({ includeLabels: false });

    // Update direction class
    badge.classList.remove(
      "badge-dir-tb",
      "badge-dir-bt",
      "badge-dir-lr",
      "badge-dir-rl",
    );
    badge.classList.add(`badge-dir-${dir.toLowerCase()}`);

    // Position badge completely outside the node bounds
    // Use larger offset to ensure badges don't overlap node content
    const offset = 8; // pixels outside the node
    let left, top;

    switch (dir) {
      case "TB": // Top to bottom - badge above top-right corner
        left = bb.x2;
        top = bb.y1 - offset;
        break;
      case "BT": // Bottom to top - badge below bottom-right corner
        left = bb.x2;
        top = bb.y2 + offset;
        break;
      case "LR": // Left to right - badge above top-right corner
        left = bb.x2;
        top = bb.y1 - offset;
        break;
      case "RL": // Right to left - badge above top-left corner
        left = bb.x1;
        top = bb.y1 - offset;
        break;
      default:
        left = bb.x2;
        top = bb.y1 - offset;
    }

    badge.style.left = `${left}px`;
    badge.style.top = `${top}px`;
  });
}

/**
 * Clean up badge overlays when graph is destroyed
 */
export function destroyTypeBadgeOverlays(cy) {
  if (cy._typeBadgeOverlay) {
    cy._typeBadgeOverlay.remove();
    cy._typeBadgeOverlay = null;
  }
  if (cy._typeBadges) {
    cy._typeBadges.clear();
    cy._typeBadges = null;
  }
}

/**
 * Check if type badges are enabled (can be toggled via localStorage)
 */
export function areBadgesEnabled() {
  const setting = localStorage.getItem("show_type_badges");
  // Default to true if not set
  return setting !== "false";
}

/**
 * Toggle type badges on/off
 */
export function toggleTypeBadges(cy, container, enabled) {
  localStorage.setItem("show_type_badges", enabled ? "true" : "false");

  if (enabled) {
    rebuildTypeBadgeOverlays(cy, container);
  } else {
    destroyTypeBadgeOverlays(cy);
  }
}

// Export config for external use if needed
export { TYPE_CONFIG };

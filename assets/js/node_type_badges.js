/**
 * Node Type Badges - Uses Cytoscape's native background-image styling
 * to display type badges on nodes. Badges render as part of the canvas,
 * avoiding z-index issues with HTML overlays.
 */

// Type abbreviations and display config
const TYPE_CONFIG = {
  thesis: {
    abbrev: "Pro",
    label: "Thesis",
    bg: "#6ee7b7",
    border: "#059669",
    text: "#064e3b",
  },
  antithesis: {
    abbrev: "Con",
    label: "Antithesis",
    bg: "#fca5a5",
    border: "#dc2626",
    text: "#7f1d1d",
  },
  synthesis: {
    abbrev: "Blend",
    label: "Synthesis",
    bg: "#c4b5fd",
    border: "#7c3aed",
    text: "#581c87",
  },
  question: {
    abbrev: "Qn",
    label: "Question",
    bg: "#7dd3fc",
    border: "#0284c7",
    text: "#0c4a6e",
  },
  user: {
    abbrev: "U",
    label: "User",
    bg: "#86efac",
    border: "#16a34a",
    text: "#14532d",
  },
  deepdive: {
    abbrev: "DD",
    label: "Deep Dive",
    bg: "#67e8f9",
    border: "#0891b2",
    text: "#164e63",
  },
  origin: {
    abbrev: "O",
    label: "Origin",
    bg: "#94a3b8",
    border: "#475569",
    text: "#1e293b",
  },
  ideas: {
    abbrev: "ID",
    label: "Ideas",
    bg: "#fdba74",
    border: "#ea580c",
    text: "#7c2d12",
  },
  answer: {
    abbrev: "Ans",
    label: "Answer",
    bg: "#d1d5db",
    border: "#6b7280",
    text: "#1f2937",
  },
  explain: {
    abbrev: "EX",
    label: "Explain",
    bg: "#d1d5db",
    border: "#6b7280",
    text: "#1f2937",
  },
  clarify: {
    abbrev: "CL",
    label: "Clarify",
    bg: "#d1d5db",
    border: "#6b7280",
    text: "#1f2937",
  },
  assumption: {
    abbrev: "AS",
    label: "Assumption",
    bg: "#fde047",
    border: "#ca8a04",
    text: "#713f12",
  },
  premise: {
    abbrev: "PR",
    label: "Premise",
    bg: "#93c5fd",
    border: "#2563eb",
    text: "#1e3a8a",
  },
  conclusion: {
    abbrev: "CO",
    label: "Conclusion",
    bg: "#f9a8d4",
    border: "#db2777",
    text: "#831843",
  },
};

// Badge dimension constants
const BADGE_CHAR_WIDTH = 10;
const BADGE_PADDING = 20;
const BADGE_HEIGHT = 18;

// Cache for generated SVG data URLs
const svgCache = new Map();

/**
 * Generate an SVG badge as a base64 data URL
 */
function generateBadgeSvg(type) {
  const config = TYPE_CONFIG[type];
  if (!config) return null;

  if (svgCache.has(type)) {
    return svgCache.get(type);
  }

  const text = config.abbrev;
  const width = text.length * BADGE_CHAR_WIDTH + BADGE_PADDING;
  const height = BADGE_HEIGHT;

  // Simple SVG with text centered
  const svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}">
  <rect x="1" y="1" width="${width - 2}" height="${height - 2}" rx="4" ry="4" fill="${config.bg}" stroke="${config.border}" stroke-width="1"/>
  <text x="${width / 2}" y="${height / 2 + 4}" font-family="Arial, sans-serif" font-size="10" font-weight="bold" fill="${config.text}" text-anchor="middle">${text}</text>
</svg>`;

  // Use base64 encoding for reliability
  const dataUrl = "data:image/svg+xml;base64," + btoa(svg);
  const result = { url: dataUrl, width, height };
  svgCache.set(type, result);
  return result;
}

/**
 * Generate Cytoscape style rules for type badges
 * Badges are positioned OUTSIDE the node at the top-right corner
 */
export function generateBadgeStyles() {
  const styles = [];

  for (const type of Object.keys(TYPE_CONFIG)) {
    const badge = generateBadgeSvg(type);
    if (!badge) continue;

    const { url, width, height } = badge;

    styles.push({
      selector: `node.${type}`,
      style: {
        "background-image": url,
        "background-width": `${width}px`,
        "background-height": `${height}px`,
        "background-fit": "none",
        "background-clip": "none",
        "background-image-containment": "over",
        "background-position-x": "100%",
        "background-position-y": "0%",
        "background-offset-x": width / 2,
        "background-offset-y": -height / 2,
        "bounds-expansion": height,
      },
    });
  }

  return styles;
}

/**
 * Apply badge styles to an existing Cytoscape instance
 */
export function applyBadgeStyles(cy) {
  if (!cy) return;

  const badgeStyles = generateBadgeStyles();

  badgeStyles.forEach((styleObj) => {
    cy.style().selector(styleObj.selector).style(styleObj.style);
  });

  cy.style().update();
}

/**
 * Remove badge styles from a Cytoscape instance
 */
export function removeBadgeStyles(cy) {
  if (!cy) return;

  for (const type of Object.keys(TYPE_CONFIG)) {
    cy.style().selector(`node.${type}`).style({
      "background-image": "none",
      "bounds-expansion": 0,
    });
  }

  cy.style().update();
}

/**
 * Check if type badges are enabled (synced with uniform style setting)
 */
export function areBadgesEnabled() {
  const setting = localStorage.getItem("show_type_badges");
  return setting === "true";
}

/**
 * Toggle type badges on/off
 */
export function toggleTypeBadges(cy, enabled) {
  localStorage.setItem("show_type_badges", enabled ? "true" : "false");

  if (enabled) {
    applyBadgeStyles(cy);
  } else {
    removeBadgeStyles(cy);
  }
}

export { TYPE_CONFIG };

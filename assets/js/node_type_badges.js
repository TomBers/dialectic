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

// Cache for generated SVG data URLs
const svgCache = new Map();

/**
 * Generate an SVG badge as a data URL
 */
function generateBadgeSvg(type) {
  const config = TYPE_CONFIG[type];
  if (!config) return null;

  const cacheKey = type;
  if (svgCache.has(cacheKey)) {
    return svgCache.get(cacheKey);
  }

  const text = config.abbrev;
  // Estimate width based on text length
  const charWidth = 7;
  const padding = 8;
  const width = text.length * charWidth + padding * 2;
  const height = 18;
  const radius = 4;

  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}">
    <rect x="0.5" y="0.5" width="${width - 1}" height="${height - 1}" rx="${radius}" ry="${radius}"
          fill="${config.bg}" stroke="${config.border}" stroke-width="1"/>
    <text x="${width / 2}" y="${height / 2 + 1}"
          font-family="ui-sans-serif, system-ui, -apple-system, sans-serif"
          font-size="10" font-weight="600"
          fill="${config.text}"
          text-anchor="middle" dominant-baseline="middle">${text}</text>
  </svg>`;

  const dataUrl = "data:image/svg+xml," + encodeURIComponent(svg);
  svgCache.set(cacheKey, dataUrl);
  return dataUrl;
}

/**
 * Generate Cytoscape style rules for type badges
 * These styles use background-image to render badges as part of the node
 */
export function generateBadgeStyles() {
  const styles = [];

  for (const [type, config] of Object.entries(TYPE_CONFIG)) {
    const svgUrl = generateBadgeSvg(type);
    if (!svgUrl) continue;

    // Estimate badge dimensions for positioning
    const charWidth = 7;
    const padding = 8;
    const badgeWidth = config.abbrev.length * charWidth + padding * 2;
    const badgeHeight = 18;

    styles.push({
      selector: `node.${type}`,
      style: {
        "background-image": svgUrl,
        "background-width": badgeWidth,
        "background-height": badgeHeight,
        "background-position-x": "100%",
        "background-position-y": "0%",
        "background-offset-x": -2,
        "background-offset-y": 2,
        "background-clip": "none",
        "background-image-containment": "over",
        "bounds-expansion": badgeHeight,
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

  // Add badge styles to the existing stylesheet
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

  // Reset background-image for all typed nodes
  for (const type of Object.keys(TYPE_CONFIG)) {
    cy.style().selector(`node.${type}`).style({
      "background-image": "none",
      "bounds-expansion": 0,
    });
  }

  cy.style().update();
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
export function toggleTypeBadges(cy, enabled) {
  localStorage.setItem("show_type_badges", enabled ? "true" : "false");

  if (enabled) {
    applyBadgeStyles(cy);
  } else {
    removeBadgeStyles(cy);
  }
}

// Export config for external use if needed
export { TYPE_CONFIG };

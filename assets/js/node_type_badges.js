/* Node Type Badges - Uses Cytoscape's native background-image styling
 * to display type badges on nodes. Badges render as part of the canvas,
 * avoiding z-index issues with HTML overlays.
 */

// Type-specific badge copy. Colors are resolved from a shared palette when available
// so badge styling stays aligned with graph type coloring.
const TYPE_META = {
  thesis: {
    abbrev: "Pro",
    label: "Thesis",
  },
  antithesis: {
    abbrev: "Con",
    label: "Antithesis",
  },
  synthesis: {
    abbrev: "Blend",
    label: "Synthesis",
  },
  question: {
    abbrev: "Qn",
    label: "Question",
  },
  user: {
    abbrev: "U",
    label: "User",
  },
  deepdive: {
    abbrev: "DD",
    label: "Deep Dive",
  },
  origin: {
    abbrev: "O",
    label: "Origin",
  },
  ideas: {
    abbrev: "ID",
    label: "Ideas",
  },
  answer: {
    abbrev: "Ans",
    label: "Answer",
  },
  explain: {
    abbrev: "EX",
    label: "Explain",
  },
  clarify: {
    abbrev: "CL",
    label: "Clarify",
  },
  assumption: {
    abbrev: "AS",
    label: "Assumption",
  },
  premise: {
    abbrev: "PR",
    label: "Premise",
  },
  conclusion: {
    abbrev: "CO",
    label: "Conclusion",
  },
};

// Backward-compatible fallback badge palette used when no shared palette is exposed.
const DEFAULT_TYPE_PALETTE = {
  thesis: { bg: "#6ee7b7", border: "#059669", text: "#064e3b" },
  antithesis: { bg: "#fca5a5", border: "#dc2626", text: "#7f1d1d" },
  synthesis: { bg: "#c4b5fd", border: "#7c3aed", text: "#581c87" },
  question: { bg: "#7dd3fc", border: "#0284c7", text: "#0c4a6e" },
  user: { bg: "#86efac", border: "#16a34a", text: "#14532d" },
  deepdive: { bg: "#67e8f9", border: "#0891b2", text: "#164e63" },
  origin: { bg: "#94a3b8", border: "#475569", text: "#1e293b" },
  ideas: { bg: "#fdba74", border: "#ea580c", text: "#7c2d12" },
  answer: { bg: "#d1d5db", border: "#6b7280", text: "#1f2937" },
  explain: { bg: "#d1d5db", border: "#6b7280", text: "#1f2937" },
  clarify: { bg: "#d1d5db", border: "#6b7280", text: "#1f2937" },
  assumption: { bg: "#fde047", border: "#ca8a04", text: "#713f12" },
  premise: { bg: "#93c5fd", border: "#2563eb", text: "#1e3a8a" },
  conclusion: { bg: "#f9a8d4", border: "#db2777", text: "#831843" },
};

function getSharedTypePalette() {
  if (typeof globalThis === "undefined") {
    return null;
  }
  return (
    globalThis.NODE_TYPE_PALETTE ||
    globalThis.TYPE_PALETTE ||
    globalThis.GRAPH_TYPE_PALETTE ||
    null
  );
}

function normalizePaletteEntry(entry, fallback) {
  if (typeof entry === "string") {
    return {
      bg: entry,
      border: fallback.border,
      text: fallback.text,
    };
  }
  if (!entry || typeof entry !== "object") {
    return fallback;
  }
  return {
    bg: entry.bg || entry.fill || entry.color || fallback.bg,
    border: entry.border || entry.stroke || fallback.border,
    text: entry.text || fallback.text,
  };
}

function buildTypeConfig() {
  const sharedPalette = getSharedTypePalette();
  const config = {};
  Object.keys(TYPE_META).forEach((type) => {
    const fallbackPalette = DEFAULT_TYPE_PALETTE[type];
    const palette = normalizePaletteEntry(
      sharedPalette && sharedPalette[type],
      fallbackPalette,
    );
    config[type] = {
      ...TYPE_META[type],
      ...palette,
    };
  });
  return config;
}

// Type abbreviations and display config
const TYPE_CONFIG = buildTypeConfig();

// Badge dimension constants
const BADGE_FONT_SIZE = 10;
const BADGE_FONT_WEIGHT = 700;
const BADGE_FONT_FAMILY = "Arial, sans-serif";
const BADGE_HORIZONTAL_PADDING = 10;
const BADGE_MIN_WIDTH = 28;
const BADGE_HEIGHT = 18;

// Cache for generated SVG data URLs
const svgCache = new Map();
let badgeMeasureContext = null;

function getBadgeMeasureContext() {
  if (badgeMeasureContext) {
    return badgeMeasureContext;
  }

  if (typeof document === "undefined") {
    return null;
  }

  const canvas = document.createElement("canvas");
  badgeMeasureContext = canvas.getContext("2d");
  return badgeMeasureContext;
}

function getBadgeDimensions(text) {
  const context = getBadgeMeasureContext();

  if (!context) {
    return {
      width: Math.max(
        BADGE_MIN_WIDTH,
        text.length * BADGE_FONT_SIZE + BADGE_HORIZONTAL_PADDING * 2,
      ),
      height: BADGE_HEIGHT,
    };
  }

  context.font = `${BADGE_FONT_WEIGHT} ${BADGE_FONT_SIZE}px ${BADGE_FONT_FAMILY}`;
  const textWidth = Math.ceil(context.measureText(text).width);

  return {
    width: Math.max(BADGE_MIN_WIDTH, textWidth + BADGE_HORIZONTAL_PADDING * 2),
    height: BADGE_HEIGHT,
  };
}

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
  const { width, height } = getBadgeDimensions(text);

  // Simple SVG with text centered
  const svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}">
  <rect x="1" y="1" width="${width - 2}" height="${height - 2}" rx="4" ry="4" fill="${config.bg}" stroke="${config.border}" stroke-width="1"/>
  <text x="${width / 2}" y="${height / 2 + 4}" font-family="${BADGE_FONT_FAMILY}" font-size="${BADGE_FONT_SIZE}" font-weight="${BADGE_FONT_WEIGHT}" fill="${config.text}" text-anchor="middle">${text}</text>
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
        "background-width": width,
        "background-height": height,
        "background-fit": "none",
        "background-clip": "none",
        "background-image-containment": "over",
        "background-position-x": "100%",
        "background-position-y": "0%",
        "background-offset-x": width / 2,
        "background-offset-y": -height / 2,
        "bounds-expansion": Math.max(width, height),
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
  const stylesheet = cy.style();

  badgeStyles.forEach((styleObj) => {
    stylesheet.selector(styleObj.selector).style(styleObj.style);
  });

  stylesheet.update();
}

/**
 * Remove badge styles from a Cytoscape instance
 */
export function removeBadgeStyles(cy) {
  if (!cy) return;

  const stylesheet = cy.style();

  for (const type of Object.keys(TYPE_CONFIG)) {
    stylesheet.selector(`node.${type}`).style({
      "background-image": "none",
      "bounds-expansion": 0,
    });
  }

  stylesheet.update();
}

/**
 * Check if type badges are enabled (synced with uniform style setting)
 */
export function areBadgesEnabled() {
  const uniformStyleEnabled =
    localStorage.getItem("uniform_node_style") === "true";
  // Badges are only available when uniform node style is enabled.
  if (!uniformStyleEnabled) {
    return false;
  }
  const setting = localStorage.getItem("show_type_badges");
  // Backward compatibility: if the badge-specific setting is absent,
  // treat it as enabled when uniform style is enabled.
  if (setting === null) {
    return true;
  }
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

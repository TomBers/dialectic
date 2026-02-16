const defaultNodeStyle = {
  text: "#1f2937", // gray-800
  background: "#ffffff",
  border: "#d1d5db", // gray-300 (strengthened from gray-200 for better node definition)
  hoverBackground: "#f3f4f6", // gray-100 — gentle lift on hover
  hoverBorder: "#9ca3af", // gray-400
  selectedText: "#1f2937", // keep dark text for readability
  selectedBackground: "#e5e7eb", // gray-200 — visible tint, high contrast (11.86:1)
  selectedBorder: "#4b5563", // gray-600 — stronger selection indicator
};

// Modern color palette — backgrounds at *-100 for visible type tinting,
// selected backgrounds at *-200 for WCAG AAA-level contrast (7:1+)
const cols = {
  question: {
    text: "#0c4a6e", // sky-900
    background: "#e0f2fe", // sky-100
    border: "#0ea5e9", // sky-500
    hoverBackground: "#bae6fd", // sky-200
    hoverBorder: "#0284c7", // sky-600
    selectedText: "#0c4a6e", // keep dark text
    selectedBackground: "#bae6fd", // sky-200 (7.13:1 contrast)
    selectedBorder: "#0369a1", // sky-700
  },
  user: {
    text: "#0c4a6e",
    background: "#e0f2fe", // sky-100
    border: "#0ea5e9",
    hoverBackground: "#bae6fd",
    hoverBorder: "#0284c7",
    selectedText: "#0c4a6e",
    selectedBackground: "#bae6fd", // sky-200 (7.13:1)
    selectedBorder: "#0369a1",
  },

  antithesis: {
    text: "#7f1d1d", // red-900
    background: "#fee2e2", // red-100
    border: "#f87171", // red-400
    hoverBackground: "#fecaca", // red-200
    hoverBorder: "#dc2626", // red-600
    selectedText: "#7f1d1d",
    selectedBackground: "#fecaca", // red-200 (6.93:1)
    selectedBorder: "#b91c1c", // red-700
  },
  synthesis: {
    text: "#581c87", // purple-900
    background: "#f3e8ff", // purple-100
    border: "#a78bfa", // purple-400
    hoverBackground: "#e9d5ff", // purple-200
    hoverBorder: "#7c3aed", // purple-600
    selectedText: "#581c87",
    selectedBackground: "#e9d5ff", // purple-200 (7.99:1)
    selectedBorder: "#6d28d9", // purple-700
  },
  thesis: {
    text: "#064e3b", // emerald-900
    background: "#d1fae5", // emerald-100
    border: "#34d399", // emerald-400
    hoverBackground: "#a7f3d0", // emerald-200
    hoverBorder: "#059669", // emerald-600
    selectedText: "#064e3b",
    selectedBackground: "#a7f3d0", // emerald-200 (7.58:1 — was 6.38 with emerald-300)
    selectedBorder: "#047857", // emerald-700
  },

  ideas: {
    text: "#7c2d12", // orange-900
    background: "#ffedd5", // orange-100
    border: "#fb923c", // orange-400
    hoverBackground: "#fed7aa", // orange-200
    hoverBorder: "#ea580c", // orange-600
    selectedText: "#7c2d12",
    selectedBackground: "#fed7aa", // orange-200 (6.92:1)
    selectedBorder: "#c2410c", // orange-700
  },
  deepdive: {
    text: "#164e63", // cyan-900
    background: "#cffafe", // cyan-100
    border: "#22d3ee", // cyan-400
    hoverBackground: "#a5f3fc", // cyan-200
    hoverBorder: "#0891b2", // cyan-600
    selectedText: "#164e63",
    selectedBackground: "#a5f3fc", // cyan-200 (7.30:1 — was 6.29 with cyan-300)
    selectedBorder: "#0e7490", // cyan-700
  },
  origin: {
    text: "#1e293b", // slate-800
    background: "#e2e8f0", // slate-200
    border: "#64748b", // slate-500
    hoverBackground: "#cbd5e1", // slate-300
    hoverBorder: "#475569", // slate-600
    selectedText: "#1e293b",
    selectedBackground: "#cbd5e1", // slate-300 (9.85:1 — was 5.71 with slate-400)
    selectedBorder: "#334155", // slate-700
  },
  answer: defaultNodeStyle,
  explain: defaultNodeStyle,
};

const cutoff = 140;

export function graphStyle(viewMode = "spaced") {
  const isCompact = viewMode === "compact";

  const base_style = [
    {
      selector: "node",
      style: {
        /* sizing ---------------------------------------------------------- */
        width: (n) => {
          if (!isCompact) return 260;
          return getCompactNodeWidth(n);
        },
        height: (n) => {
          const processedContent = processNodeContent(
            n.data("content") || "",
            false,
          );

          // Normalize content and convert <br> tags to newlines for measurement
          const content = (processedContent || "").replace(/<br\s*\/?>/g, "\n");

          // Remove zero-width spaces used for wrapping when measuring length
          const measureText = content.replace(/\u200B/g, "");

          if (!isCompact) {
            // Spaced mode: use fixed width calculation
            const approxCharsPerLine = 20;
            const parts = measureText.split("\n");
            let lines = 0;
            for (const part of parts) {
              const len = part.trim().length;
              lines += Math.max(1, Math.ceil(len / approxCharsPerLine));
            }
            const bulletCount = (measureText.match(/•/g) || []).length;
            const bulletExtra = bulletCount * 6;
            const lineHeight = 20;
            const basePadding = 20;
            const computed = basePadding + lines * lineHeight + bulletExtra;
            return Math.max(35, computed);
          }

          // Compact mode: calculate based on actual dynamic width
          const lines_arr = measureText.split("\n");

          const charWidth = 7.5;
          const padding = 8;
          // Calculate actual node width
          const nodeWidth = getCompactNodeWidth(n);
          const textWidth = nodeWidth - padding;

          // Calculate chars per line based on actual width
          const approxCharsPerLine = Math.floor(textWidth / charWidth);

          // Estimate total wrapped lines
          let lines = 0;
          for (const part of lines_arr) {
            const len = part.trim().length;
            lines += Math.max(1, Math.ceil(len / approxCharsPerLine));
          }

          // Bullet points add extra vertical spacing
          const bulletCount = (measureText.match(/•/g) || []).length;
          const bulletExtra = bulletCount * 2;

          // Compute height: 10px font * 1.2 line-height = 12px per line
          const lineHeight = 12;
          const basePadding = 8; // 4px top + 4px bottom
          const computed = basePadding + lines * lineHeight + bulletExtra;

          return Math.max(22, computed);
        },
        "min-width": isCompact ? 50 : 55,
        "min-height": isCompact ? 22 : 35,
        padding: isCompact ? "4px" : "10px",
        "text-wrap": "wrap",
        "text-max-width": (n) => {
          if (!isCompact) return 200;
          return getCompactNodeWidth(n) - 8;
        },

        /* label ----------------------------------------------------------- */
        label: (ele) => {
          const text = processNodeContent(ele.data("content") || "");
          return text;
        },

        /* font & layout --------------------------------------------------- */
        "font-family":
          'ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif',
        "font-size": isCompact ? 10 : 14,
        "font-weight": isCompact ? 400 : 500,
        "text-halign": "center",
        "text-valign": "center",
        "line-height": isCompact ? 1.2 : 1.4,

        /* aesthetics ------------------------------------------------------ */
        shape: "rectangle",
        "corner-radius": isCompact ? 6 : 12,
        "border-width": isCompact ? 0.75 : 1.5,
        "border-color": "#d1d5db", // gray-300 (strengthened from gray-200)
        "background-color": "#ffffff",
        color: "#1f2937",

        /* drop shadow via ghost — gives nodes a floating-card feel */
        ghost: "yes",
        "ghost-offset-x": isCompact ? 1 : 2,
        "ghost-offset-y": isCompact ? 1 : 2,
        "ghost-opacity": 0.08,

        /* smooth transitions for hover / select state changes */
        "transition-property":
          "background-color border-color border-width shadow-blur shadow-color shadow-offset-x shadow-offset-y",
        "transition-duration": "150ms",
        "transition-timing-function": "ease-in-out-sine",
      },
    },
    {
      selector: "node:active",
      style: {
        "border-width": 3,
        "border-color": "#3b82f6",
        "background-color": "#eff6ff",
      },
    },
    {
      selector: "node[compound]",
      style: {
        label: "data(id)", // ← use the id field
        "text-halign": () => {
          const dir = localStorage.getItem("graph_direction") || "TB";
          return dir === "RL" ? "right" : dir === "LR" ? "left" : "center";
        },
        "text-valign": () => {
          const dir = localStorage.getItem("graph_direction") || "TB";
          return dir === "BT" ? "bottom" : "top";
        },
        "text-margin-y": () => {
          const dir = localStorage.getItem("graph_direction") || "TB";
          return dir === "BT" ? -8 : 8;
        },
        "font-family":
          'ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif',
        "font-size": 12,
        "font-weight": 700,
        "text-transform": "uppercase",
        "text-outline-width": 3,
        "text-outline-color": "#ffffff",
        "text-opacity": 1,
        padding: isCompact ? "12px" : "32px",

        "background-opacity": 0.5,
        "background-color": "#ffffff", // white
        "border-width": isCompact ? 1 : 2,
        "border-style": "dashed",
        "border-color": "#cbd5e1", // slate-300
        shape: "roundrectangle",
        "corner-radius": isCompact ? 12 : 24,
      },
    },
    { selector: ".hidden", style: { display: "none" } },
    { selector: ".depth-hidden", style: { display: "none" } },

    /* Visual indicator for nodes whose children are collapsed */
    {
      selector: ".node-collapsed",
      style: {
        "border-style": "double",
        "border-width": isCompact ? 2.5 : 3.5,
      },
    },

    /* draw the parent differently when it's collapsed --- */
    {
      selector: 'node[compound][collapsed = "true"]',
      style: {
        /* dynamic badge size based on label length */
        width: (n) => {
          if (!isCompact) return 220;
          return getCompactCollapsedWidth(n);
        },
        height: isCompact ? 28 : 48,

        /* look & feel: pill shape */
        shape: "roundrectangle",
        "corner-radius": isCompact ? 14 : 24,
        "background-opacity": 1,
        "background-color": "#ffffff",
        "border-width": isCompact ? 1.5 : 2,
        "border-color": "#e2e8f0",
        "border-style": "solid",

        /* chevron indicator (right side) */
        "background-fit": "none",
        "background-clip": "node",
        "background-width": isCompact ? 8 : 12,
        "background-height": isCompact ? 8 : 12,
        "background-position-x": "92%",
        "background-position-y": "50%",

        /* text centred inside the card */
        label: "data(id)",
        "text-valign": "center",
        "text-halign": "center",
        "text-margin-x": 0,
        "font-family":
          'ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif',
        "font-size": isCompact ? 10 : 14,
        "font-weight": isCompact ? 500 : 600,
        "text-wrap": "ellipsis",
        "text-max-width": (n) => {
          if (!isCompact) return 180;
          return getCompactCollapsedWidth(n) - 25;
        },
        color: "#1e293b",
      },
    },
    // Edge styling — darkened for better visibility (4.76:1 contrast)
    {
      selector: "edge",
      style: {
        width: isCompact ? 1 : 1.5,
        "line-color": "#64748b", // slate-500 (darkened from slate-400 for readability)
        "edge-distances": "node-position",
        "curve-style": "bezier",
        "target-arrow-shape": "triangle-backcurve", // more elegant arrow
        "target-arrow-color": "#64748b", // slate-500
        "arrow-scale": isCompact ? 0.6 : 0.8,
        "control-point-step-size": isCompact ? 25 : 40,
        "control-point-weight": 0.5,
        opacity: 0.65, // raised from 0.55 for better edge visibility
        /* smooth transition so hover fade-in feels polished */
        "transition-property": "line-color target-arrow-color width opacity",
        "transition-duration": "150ms",
        "transition-timing-function": "ease-in-out-sine",
      },
    },
    {
      selector: ".edge-hover",
      style: {
        width: isCompact ? 2 : 3,
        "line-color": "#3b82f6", // blue-500
        "target-arrow-color": "#3b82f6",
        "z-index": 9998,
        opacity: 1,
      },
    },
  ];

  for (const nodeType of Object.keys(cols)) {
    base_style.push({
      selector: `node.${nodeType}`, // ← has the class
      style: {
        "border-color": cols[nodeType].border,
        "background-color": cols[nodeType].background,
        "border-width": isCompact ? 1.5 : 2,
        "border-opacity": 1,
        color: cols[nodeType].text,
      },
    });

    /* hover — gentle lift: slightly deeper tint + border boost */
    base_style.push({
      selector: `node.${nodeType}.node-hover`,
      style: {
        "background-color":
          cols[nodeType].hoverBackground || cols[nodeType].background,
        "border-color": cols[nodeType].hoverBorder || cols[nodeType].border,
        "border-width": isCompact ? 2 : 2.5,
        "border-style": "solid",
        color: cols[nodeType].text, // keep dark text on hover
        "ghost-opacity": 0.14, // deepen shadow slightly on hover
      },
    });

    /* selected — prominent border + wide underlay halo */
    base_style.push({
      selector: `node.${nodeType}.selected`,
      style: {
        "background-color": cols[nodeType].selectedBackground,
        "border-color": cols[nodeType].selectedBorder,
        "border-width": isCompact ? 3 : 4,
        "border-style": "solid",
        color: cols[nodeType].selectedText,
        /* wide halo well outside the border so it reads as a glow, not a second border */
        "underlay-color": cols[nodeType].selectedBorder,
        "underlay-opacity": 0.12,
        "underlay-padding": isCompact ? 10 : 14,
        "underlay-shape": "roundrectangle",
        "ghost-opacity": 0.22,
      },
    });

    /* per-type accent border for collapsed compound "cards" */
    base_style.push({
      selector: `node[compound][collapsed = "true"].${nodeType}`,
      style: {
        "border-color": cols[nodeType].border,
      },
    });
  }

  base_style.push({
    selector:
      'node[compound], node[compound].selected, node[compound][collapsed = "true"]',
    style: {
      events: "no",
    },
  });
  return base_style;
}

// Function to process node content for display and size calculation
function processNodeContent(content, addEllipsis = true) {
  let fullContent = content || "";
  fullContent = fullContent.replace(/\*\*/g, ""); // Remove all **

  // Get only the first line
  const firstLineCandidate = (fullContent || "").split("\n")[0] || "";

  // Strip leading Markdown heading hashes (e.g., "## ")
  const noHeading = firstLineCandidate.replace(/^\s*#{1,6}\s*/, "");

  // Remove "Title:" prefix if present (case-insensitive)
  const firstLineOnly = noHeading.replace(/^Title:\s*/i, "");

  // Slice to cutoff for measurement and display purposes
  const raw = firstLineOnly;
  const sliced = raw.slice(0, cutoff);
  const suffix = addEllipsis && raw.length > cutoff ? "…" : "";

  // Add break opportunities to help wrapping with long slash/dash sequences
  // - Insert zero-width space after '/', '-', '–', '—'
  const withBreaks = sliced
    .replace(/\//g, "/\u200B")
    .replace(/([\-–—‑])/g, "$1\u200B");

  return `${withBreaks}${suffix}`;
}

function getCompactNodeWidth(n) {
  const processedContent = processNodeContent(n.data("content") || "", false);
  const content = (processedContent || "").replace(/<br\s*\/?>/g, "\n");
  const measureText = content.replace(/\u200B/g, "");

  // Get the longest line to determine width
  const lines = measureText.split("\n");
  let maxLineLength = 0;
  for (const line of lines) {
    maxLineLength = Math.max(maxLineLength, line.trim().length);
  }

  // Estimate width: ~7.5px per character at 10px font + padding
  // 8px total padding (4px left + 4px right)
  const charWidth = 7.5;
  const padding = 8;
  const computed = Math.ceil(maxLineLength * charWidth) + padding;

  // Min 50px, max 140px to keep compact
  return Math.max(50, Math.min(140, computed));
}

function getCompactCollapsedWidth(n) {
  const label = n.data("id") || "";
  // Estimate width: ~7px per character at 10px font + padding for chevron
  const charWidth = 7;
  const padding = 30; // Extra padding for chevron and margins
  const computed = Math.ceil(label.length * charWidth) + padding;

  // Min 70px, max 150px
  return Math.max(70, Math.min(150, computed));
}

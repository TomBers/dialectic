const defaultNodeStyle = {
  text: "#1f2937", // gray-800
  background: "#ffffff",
  border: "#e5e7eb", // gray-200
  selectedText: "#ffffff",
  selectedBackground: "#9ca3af", // gray-400
  selectedBorder: "#6b7280", // gray-500
};

// Modern color palette with subtle backgrounds
const cols = {
  question: {
    text: "#0c4a6e", // sky-900
    background: "#f0f9ff", // sky-50
    border: "#0ea5e9", // sky-500
    selectedText: "#ffffff",
    selectedBackground: "#0ea5e9",
    selectedBorder: "#0369a1",
  },
  user: {
    text: "#0c4a6e",
    background: "#f0f9ff",
    border: "#0ea5e9",
    selectedText: "#ffffff",
    selectedBackground: "#0ea5e9",
    selectedBorder: "#0369a1",
  },

  antithesis: {
    text: "#7f1d1d", // red-900
    background: "#fef2f2", // red-50
    border: "#f87171", // red-400 (softer than before)
    selectedText: "#ffffff",
    selectedBackground: "#ef4444",
    selectedBorder: "#b91c1c",
  },
  synthesis: {
    text: "#581c87", // purple-900
    background: "#faf5ff", // purple-50
    border: "#a78bfa", // purple-400
    selectedText: "#ffffff",
    selectedBackground: "#8b5cf6",
    selectedBorder: "#6d28d9",
  },
  thesis: {
    text: "#064e3b", // emerald-900
    background: "#ecfdf5", // emerald-50
    border: "#34d399", // emerald-400
    selectedText: "#ffffff",
    selectedBackground: "#10b981",
    selectedBorder: "#047857",
  },

  ideas: {
    text: "#7c2d12", // orange-900
    background: "#fff7ed", // orange-50
    border: "#fb923c", // orange-400
    selectedText: "#ffffff",
    selectedBackground: "#f97316",
    selectedBorder: "#c2410c",
  },
  deepdive: {
    text: "#164e63", // cyan-900
    background: "#ecfeff", // cyan-50
    border: "#22d3ee", // cyan-400
    selectedText: "#ffffff",
    selectedBackground: "#06b6d4",
    selectedBorder: "#0e7490",
  },
  origin: {
    text: "#1e293b", // slate-800
    background: "#f1f5f9", // slate-100
    border: "#64748b", // slate-500
    selectedText: "#ffffff",
    selectedBackground: "#475569", // slate-600
    selectedBorder: "#334155", // slate-700
  },
  answer: defaultNodeStyle,
  explain: defaultNodeStyle,
};

const cutoff = 140;

export function graphStyle() {
  const base_style = [
    {
      selector: "node",
      style: {
        /* sizing ---------------------------------------------------------- */
        width: 260,
        height: (n) => {
          const processedContent = processNodeContent(
            n.data("content") || "",
            false,
          );

          // Normalize content and convert <br> tags to newlines for measurement
          const content = (processedContent || "").replace(/<br\s*\/?>/g, "\n");

          // Remove zero-width spaces used for wrapping when measuring length
          const measureText = content.replace(/\u200B/g, "");

          // Heuristic: characters that fit on one line at 200px width, 14px font
          const approxCharsPerLine = 20;

          // Estimate total wrapped lines across explicit lines
          const parts = measureText.split("\n");
          let lines = 0;
          for (const part of parts) {
            const len = part.trim().length;
            // Ensure at least one line per part
            lines += Math.max(1, Math.ceil(len / approxCharsPerLine));
          }

          // Bullet points add extra vertical spacing
          const bulletCount = (measureText.match(/•/g) || []).length;
          const bulletExtra = bulletCount * 6; // pixels

          // Compute height from estimated lines
          const lineHeight = 20; // px per line (14px * 1.4)
          const basePadding = 20; // px padding/spacing allowance
          const computed = basePadding + lines * lineHeight + bulletExtra;

          return Math.max(35, computed);
        },
        "min-width": 55,
        "min-height": 35,
        padding: "10px",
        "text-wrap": "wrap",
        "text-max-width": 200, // interior width incl. padding

        /* label ----------------------------------------------------------- */
        label: (ele) => {
          return processNodeContent(ele.data("content") || "");
        },

        /* font & layout --------------------------------------------------- */
        "font-family":
          'ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif',
        "font-size": 14,
        "font-weight": 500,
        "text-halign": "center",
        "text-valign": "center",
        "line-height": 1.4,

        /* aesthetics ------------------------------------------------------ */
        shape: "roundrectangle",
        "corner-radius": 12,
        "border-width": 1.5,
        "border-color": "#e5e7eb",
        "background-color": "#ffffff",
        color: "#1f2937",
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
        "text-halign": "center",
        "text-valign": "top",
        "text-margin-y": 8,
        "font-family":
          'ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif',
        "font-size": 12,
        "font-weight": 700,
        "text-transform": "uppercase",
        "text-outline-width": 3,
        "text-outline-color": "#ffffff",
        "text-opacity": 1,
        padding: "32px",

        "background-opacity": 0.5,
        "background-color": "#f8fafc", // slate-50
        "border-width": 2,
        "border-style": "dashed",
        "border-color": "#cbd5e1", // slate-300
        shape: "roundrectangle",
        "corner-radius": 24,
      },
    },
    { selector: ".hidden", style: { display: "none" } },

    /* draw the parent differently when it’s collapsed --- */
    {
      selector: 'node[compound][collapsed = "true"]',
      style: {
        /* fixed badge size */
        width: 220,
        height: 48,

        /* look & feel: pill shape */
        shape: "roundrectangle",
        "corner-radius": 24,
        "background-opacity": 1,
        "background-color": "#ffffff",
        "border-width": 2,
        "border-color": "#e2e8f0",
        "border-style": "solid",

        /* chevron indicator (right side) */
        "background-fit": "none",
        "background-clip": "node",
        "background-width": 12,
        "background-height": 12,
        "background-position-x": "92%",
        "background-position-y": "50%",

        /* text centred inside the card */
        label: "data(id)",
        "text-valign": "center",
        "text-halign": "center",
        "text-margin-x": 0,
        "font-family":
          'ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif',
        "font-size": 14,
        "font-weight": 600,
        "text-wrap": "ellipsis",
        "text-max-width": 180,
        color: "#1e293b",
      },
    },
    // Edge styling
    {
      selector: "edge",
      style: {
        width: 2,
        "line-color": "#cbd5e1", // slate-300
        "edge-distances": "node-position",
        "curve-style": "bezier",
        "target-arrow-shape": "triangle",
        "target-arrow-color": "#cbd5e1",
        "arrow-scale": 0.8,
        "control-point-step-size": 40,
        "control-point-weight": 0.5,
        opacity: 0.8,
      },
    },
    {
      selector: ".edge-hover",
      style: {
        width: 3,
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
        //  NOT "css"
        "border-color": cols[nodeType].border,
        "background-color": cols[nodeType].background,
        "border-width": 2,
        "border-opacity": 1,
        color: cols[nodeType].text,
      },
    });

    base_style.push({
      selector: `node.${nodeType}.selected, node.${nodeType}.node-hover`,
      style: {
        shape: "roundrectangle",
        "border-color": cols[nodeType].selectedBorder,
        color: cols[nodeType].selectedText,
        "background-color": cols[nodeType].selectedBackground,
        "border-width": 2,
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

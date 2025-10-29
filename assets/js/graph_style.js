const defaultNodeStyle = {
  text: "#374151",
  background: "white",
  border: "#e5e7eb", // light gray (gray-200)
  selectedText: "#ffffff", // white text on selection for consistency
  selectedBackground: "#bec3cc", // use border color on selection
  selectedBorder: "#a1a8b5", // gray-300 for gentle emphasis
};

const cols = {
  question: {
    text: "#374151",
    background: "white",
    border: "#0ea5e9", // Strong blue for answers
    selectedText: "#ffffff",
    selectedBackground: "#0ea5e9",
    selectedBorder: "#0284c7",
  },
  user: {
    text: "#374151",
    background: "white",
    border: "#0ea5e9",
    selectedText: "#ffffff",
    selectedBackground: "#0ea5e9",
    selectedBorder: "#0284c7",
  },

  antithesis: {
    text: "#374151",
    background: "white",
    border: "#ef4444", // Vibrant red for antithesis/opposing viewpoints
    selectedText: "#ffffff",
    selectedBackground: "#ef4444",
    selectedBorder: "#dc2626",
  },
  synthesis: {
    text: "#374151",
    background: "white",
    border: "#8b5cf6", // Rich purple for synthesis (combined ideas)
    selectedText: "#ffffff",
    selectedBackground: "#8b5cf6",
    selectedBorder: "#7c3aed",
  },
  thesis: {
    text: "#374151",
    background: "white",
    border: "#10b981", // Emerald green for thesis/main arguments
    selectedText: "#ffffff",
    selectedBackground: "#10b981",
    selectedBorder: "#059669",
  },

  ideas: {
    text: "#374151",
    background: "white",
    border: "#f97316", // Warm orange for ideas
    selectedText: "#ffffff",
    selectedBackground: "#f97316",
    selectedBorder: "#ea580c",
  },
  deepdive: {
    text: "#374151",
    background: "white",
    border: "#06b6d4", // Cyan for deep dive
    selectedText: "#ffffff",
    selectedBackground: "#06b6d4",
    selectedBorder: "#0891b2",
  },
  origin: {
    text: "#374151",
    background: "white",
    border: "#111827", // Distinct dark border for origin node
    selectedText: "#ffffff",
    selectedBackground: "#111827",
    selectedBorder: "#030712",
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
        width: 230,
        height: (n) => {
          const processedContent = processNodeContent(
            n.data("content") || "",
            false,
          );

          // Normalize content and convert <br> tags to newlines for measurement
          const content = (processedContent || "").replace(/<br\s*\/?>/g, "\n");

          // Remove zero-width spaces used for wrapping when measuring length
          const measureText = content.replace(/\u200B/g, "");

          // Heuristic: characters that fit on one line at 210px width, 13px font
          const approxCharsPerLine = 28;

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
          const lineHeight = 16; // px per line at 13px font size
          const basePadding = 14; // px padding/spacing allowance
          const computed = basePadding + lines * lineHeight + bulletExtra;

          return Math.max(35, computed);
        },
        "min-width": 55,
        "min-height": 35,
        padding: "10px",
        "text-wrap": "wrap",
        "text-max-width": 210, // interior width incl. padding

        /* label ----------------------------------------------------------- */
        label: (ele) => {
          return processNodeContent(ele.data("content") || "");
        },

        /* font & layout --------------------------------------------------- */
        "font-family": "sans-serif",
        "font-size": 13,
        "font-weight": 400,
        "text-halign": "center",
        "text-valign": "center",

        /* aesthetics ------------------------------------------------------ */
        shape: "roundrectangle",
        "border-width": 1,
        "border-color": "#e5e7eb",
        "background-color": "#f9fafb",
        color: "#374151",

        "transition-property":
          "background-color, border-color, color, border-width",
        "transition-duration": "150ms",
        "transition-timing-function": "ease-in-out",
      },
    },
    {
      selector: "node:active",
      style: {
        "border-width": 2.5,
        "border-color": "#60a5fa",
        "background-color": "#ffffff",
        "underlay-color": "#60a5fa",
        "underlay-padding": 6,
        "underlay-opacity": 0.35,
      },
    },
    {
      selector: "node[compound]",
      style: {
        label: "data(id)", // ← use the id field
        "text-halign": "center",
        "text-valign": "top",
        "text-margin-y": 8,
        "font-size": 13,
        "font-weight": 600,
        "text-outline-width": 2,
        "text-outline-color": "#f9fafb",
        "text-opacity": 1, // make sure it isn't zero
        padding: "24px",

        "background-opacity": 1,
        "background-color": "white",
        "border-width": 1,
        "border-style": "dashed",
        "border-color": "#4B5563",
      },
    },
    {
      selector: "node[compound].selected",
      style: {
        // Make selection visually inert for compound nodes
        label: "data(id)",
        "text-halign": "center",
        "text-valign": "top",
        "text-margin-y": 8,
        "font-size": 13,
        "font-weight": 600,
        "text-outline-width": 2,
        "text-outline-color": "#f9fafb",
        "text-opacity": 1,
        padding: "24px",
        "background-opacity": 1,
        "background-color": "#f9fafb",
        "border-width": 1,
        "border-style": "dashed",
        "border-color": "#4B5563",
      },
    },
    { selector: ".hidden", style: { display: "none" } },

    /* draw the parent differently when it’s collapsed --- */
    {
      selector: 'node[compound][collapsed = "true"]',
      style: {
        /* fixed badge size */
        width: 230,
        height: 40,

        /* look & feel: square card with accent border and chevron */
        shape: "rectangle",
        "background-opacity": 1,
        "background-color": "#ffffff",
        "border-width": 2,
        "border-color": "#9ca3af",
        "border-style": "solid",

        /* subtle shadow to suggest interactivity */

        /* chevron indicator (right side) */

        "background-fit": "none",
        "background-clip": "node",
        "background-width": 12,
        "background-height": 12,
        "background-position-x": "96%",
        "background-position-y": "50%",

        /* text centred inside the card */
        label: "data(id)",
        "text-valign": "center",
        "text-halign": "center",
        "text-margin-x": -6,
        "font-size": 13,
        "font-weight": 600,
        "text-wrap": "wrap",
        "text-max-width": 190,
        color: "#374151",
      },
    },
    {
      selector: ".preview",
      style: {
        "border-width": 3,
        opacity: 1,
      },
    },

    // Edge styling
    {
      selector: "edge",
      style: {
        width: 1.5,
        "line-color": "#c0c6d0",
        "edge-distances": "node-position",
        "curve-style": "bezier",
        "control-point-step-size": 25,
        "control-point-weight": 0.35,
        opacity: 0.8,
      },
    },
    {
      selector: ".edge-hover",
      style: {
        width: 4, // Increased thickness for better visibility
        "line-color": "#4ade80", // More refined green color
        "z-index": 9998,
        opacity: 1,
        "target-arrow-color": "#4ade80", // Matching arrow color
        "target-arrow-shape": "triangle", // Add arrow shape for highlighted edges
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
      selector: `node.${nodeType}.selected`, // ← has both classes
      style: {
        shape: "roundrectangle",
        "font-weight": "500",
        "border-color": cols[nodeType].selectedBorder,
        color: cols[nodeType].selectedText,
        "background-color": cols[nodeType].selectedBackground,
        "border-width": 2,
      },
    });
    // Hover should preview the selected color scheme for the node type
    base_style.push({
      selector: `node.${nodeType}.node-hover`,
      style: {
        shape: "roundrectangle",
        "font-weight": "500",
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

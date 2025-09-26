const selectState = {
  shape: "roundrectangle",
  "font-weight": "500",
  "border-color": (ele) => darkenColor(getTypeColors(ele).border, 0.2),
  color: (ele) => readableTextColor(getTypeColors(ele).border),
  "background-color": (ele) => getTypeColors(ele).border,
  "border-width": 3,
};

const cols = {
  user: {
    text: "#374151",
    background: "white",
    border: "#d1d5db", // Subtle medium gray for user messages
  },
  answer: {
    text: "#374151",
    background: "white",
    border: "#0ea5e9", // Strong blue for answers
  },
  antithesis: {
    text: "#374151",
    background: "white",
    border: "#ef4444", // Vibrant red for antithesis/opposing viewpoints
  },
  synthesis: {
    text: "#374151",
    background: "white",
    border: "#8b5cf6", // Rich purple for synthesis (combined ideas)
  },
  thesis: {
    text: "#374151",
    background: "white",
    border: "#10b981", // Emerald green for thesis/main arguments
  },
  examples: {
    text: "#374151",
    background: "white",
    border: "#f97316", // Warm orange for examples
  },
  ideas: {
    text: "#374151",
    background: "white",
    border: "#f97316", // Warm orange for ideas
    // border: "#0ea5e9", // Bright sky blue for ideas
  },
  details: {
    text: "#374151",
    background: "white",
    border: "#84cc16", // Lime green for details
  },
  explain: {
    text: "#374151",
    background: "white",
    border: "#F2F0EF", // Subtle pale amber for explanations
  },
  origin: {
    text: "#374151",
    background: "white",
    border: "#111827", // Distinct dark border for origin node
  },
};

function normalizeToHex(c) {
  const named = { white: "#ffffff", black: "#000000" };
  if (!c) return "#000000";
  c = c.toString().trim().toLowerCase();
  if (named[c]) return named[c];
  if (c.startsWith("#")) {
    let hex = c.slice(1);
    if (hex.length === 3) {
      hex = hex
        .split("")
        .map((ch) => ch + ch)
        .join("");
    }
    if (hex.length === 6) {
      return `#${hex}`;
    }
  }
  return c;
}

function invertColor(c) {
  const hex = normalizeToHex(c).replace("#", "");
  if (!/^[0-9a-f]{6}$/i.test(hex)) {
    return "#000000";
  }
  const r = 255 - parseInt(hex.substring(0, 2), 16);
  const g = 255 - parseInt(hex.substring(2, 4), 16);
  const b = 255 - parseInt(hex.substring(4, 6), 16);
  const toHex = (n) => n.toString(16).padStart(2, "0");
  return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
}

function readableTextColor(c) {
  const hex = normalizeToHex(c).replace("#", "");
  if (!/^[0-9a-f]{6}$/i.test(hex)) {
    return "#000000";
  }
  const r = parseInt(hex.substring(0, 2), 16);
  const g = parseInt(hex.substring(2, 4), 16);
  const b = parseInt(hex.substring(4, 6), 16);
  const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  return luminance > 0.6 ? "#000000" : "#ffffff";
}

function darkenColor(c, amount = 0.2) {
  const hex = normalizeToHex(c).replace("#", "");
  if (!/^[0-9a-f]{6}$/i.test(hex)) {
    return c;
  }
  const r = Math.max(
    0,
    Math.floor(parseInt(hex.substring(0, 2), 16) * (1 - amount)),
  );
  const g = Math.max(
    0,
    Math.floor(parseInt(hex.substring(2, 4), 16) * (1 - amount)),
  );
  const b = Math.max(
    0,
    Math.floor(parseInt(hex.substring(4, 6), 16) * (1 - amount)),
  );
  const toHex = (n) => n.toString(16).padStart(2, "0");
  return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
}
function getTypeColors(ele) {
  for (const type of Object.keys(cols)) {
    if (ele.hasClass(type)) {
      return cols[type];
    }
  }
  return { text: "#374151", background: "white", border: "#e5e7eb" };
}

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

          // Base height calculation
          const base = Math.max(
            Math.min(processedContent.length, cutoff) - 65,
            35,
          );

          // Get the original content for counting elements that affect height
          const content = processedContent || "";

          // Count newlines for vertical spacing
          const newlineCount = (content.match(/\n/g) || []).length;

          // Count bullet points (• character)
          const bulletCount = (content.match(/•/g) || []).length;

          // Extra height for newlines
          const newlineExtra = newlineCount * 3.5;

          // Extra height for bullet points (add more space per bullet)
          const bulletExtra = bulletCount * 7;

          // For content with both <br> tags and bullet points
          const brTagCount = (content.match(/<br>/g) || []).length;
          const brExtra = brTagCount * 3;

          return base + newlineExtra + bulletExtra + brExtra;
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
        "background-color": "white",
        color: "#374151",
      },
    },
    {
      selector: "node[compound]",
      style: {
        label: "data(id)", // ← use the id field
        "text-halign": "center",
        "text-valign": "top",
        "text-margin-y": 5,
        "font-size": 13,
        "font-weight": 600,
        "text-opacity": 1, // make sure it isn't zero
        padding: "20px",
        "background-opacity": 0.15,
        "background-color": "#f2f4f5",
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
        width: 230, // px – tweak to taste
        height: 35,

        /* look & feel */
        shape: "roundrectangle",
        "background-opacity": 0.7,
        "background-color": "#E5E7EB", // slate‑200
        "border-width": 1,
        "border-color": "#9ca3af",
        "border-style": "solid",

        /* text centred inside the badge */
        label: "data(id)",
        "text-valign": "center",
        "text-halign": "center",
        "font-size": 13,
        "font-weight": 600,
        "text-wrap": "wrap",
        "text-max-width": 200,
        color: "#374151",
        "text-outline-width": 1,
        "text-outline-color": "#ffffff",
        "text-outline-opacity": 0.8,
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
        "border-width": 3,
        "border-opacity": 1,
        color: cols[nodeType].text,
      },
    });

    base_style.push({
      selector: `node.${nodeType}.selected`, // ← has both classes
      style: selectState,
    });
  }
  return base_style;
}

// Function to process node content for display and size calculation
function processNodeContent(content, addEllipsis = true) {
  let fullContent = content || "";
  fullContent = fullContent.replace(/\*\*/g, ""); // Remove all **

  // Remove "Title:" prefix if present
  const contentWithoutTitle = fullContent.replace(/^Title:\s*/i, "");

  // Get only the first line
  const firstLineOnly = contentWithoutTitle.split("\n")[0];

  const text = firstLineOnly.slice(0, cutoff);
  const suffix = addEllipsis && firstLineOnly.length > cutoff ? "…" : "";

  return `${text}${suffix}`;
}

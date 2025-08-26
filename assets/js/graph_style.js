const selectState = {
  shape: "roundrectangle",
  "font-weight": "500",
  "border-color": "white", // White border
  color: "#FFFFFF", // White text
  "background-color": "#0ea05a", // Slightly darker, more professional green
  "border-width": 0,
};

const cols = {
  user: { text: "#374151", background: "white", border: "white" },
  answer: {
    text: "#374151",
    background: "white",
    border: "#60a5fa",
  },
  antithesis: {
    text: "#374151",
    background: "white",
    border: "#f84b71",
  },
  synthesis: {
    text: "#374151",
    background: "white",
    border: "#c084fc",
  },
  thesis: {
    text: "#374151",
    background: "white",
    border: "#4ade80",
  },
  examples: {
    text: "#374151",
    background: "white",
    border: "red",
  },
  ideas: {
    text: "#374151",
    background: "white",
    border: "blue",
  },
  details: {
    text: "#374151",
    background: "white",
    border: "green",
  },
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

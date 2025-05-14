const selectState = {
  shape: "roundrectangle",
  "font-weight": "400",
  "border-color": "white", // Dark green border
  color: "#FFFFFF", // White text
  "background-color": "#14e37c", // Bright mint green (very vibrant)
  "border-width": 2,
};

const cols = {
  user: { text: "#374151", background: "white", border: "#d1d5db" },
  answer: { text: "#60a5fa", background: "white", border: "#60a5fa" },
  antithesis: { text: "#f84b71", background: "white", border: "#f84b71" },
  synthesis: { text: "#c084fc", background: "white", border: "#c084fc" },
  thesis: { text: "#4ade80", background: "white", border: "#4ade80" },
};

const cutoff = 140;

export function graphStyle() {
  const base_style = [
    {
      selector: "node",
      style: {
        /* sizing ---------------------------------------------------------- */
        width: 250,
        height: (n) =>
          Math.max(Math.min(n.data("content").length, cutoff) - 60, 40),
        "min-width": 60,
        "min-height": 40,
        padding: "12px",
        "text-wrap": "wrap",
        "text-max-width": 250, // interior width incl. padding

        /* label ----------------------------------------------------------- */
        label: (ele) => {
          const fullContent = ele.data("content") || "";

          // Remove "Title:" prefix if present
          const contentWithoutTitle = fullContent.replace(/^Title:\s*/i, "");

          const text = contentWithoutTitle.slice(0, cutoff);
          const suffix = contentWithoutTitle.length > cutoff ? "…" : "";

          return `${text}${suffix}`;
        },

        /* font & layout --------------------------------------------------- */
        "font-family": "sans-serif",
        "font-size": 14,
        "font-weight": 400,
        "text-halign": "center",
        "text-valign": "center",

        /* aesthetics ------------------------------------------------------ */
        shape: "roundrectangle",
        "border-width": 2,
        "border-color": "#d1d5db",
        "background-color": "#f3f4f6",
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
        "background-color": "#4B5563",
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
        width: 250, // px – tweak to taste
        height: 40,

        /* look & feel */
        shape: "roundrectangle",
        "background-opacity": 0.7,
        "background-color": "#E5E7EB", // slate‑200
        "border-width": 2,
        "border-color": "#4B5563",
        "border-style": "solid",
        "box-shadow": "0px 2px 5px rgba(0, 0, 0, 0.1)",

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
        "border-width": 6,
        opacity: 1,
      },
    },

    // Edge styling
    {
      selector: "edge",
      style: {
        width: 2,
        "line-color": "#d1d5db",
        "curve-style": "bezier",
        "edge-distances": "node-position",
        "curve-style": "bezier",
        "control-point-step-size": 40,
        "control-point-weight": 0.5,
        opacity: 0.8,
      },
    },
    {
      selector: ".edge-hover",
      style: {
        width: 3,
        "line-color": "#83f28f", // Light green color
        "z-index": 9998,
        opacity: 1,
        "shadow-blur": 10,
        "shadow-color": "#83f28f",
        "shadow-opacity": 0.3,
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
        "box-shadow": "0px 2px 4px rgba(0, 0, 0, 0.08)",
      },
    });

    base_style.push({
      selector: `node.${nodeType}.selected`, // ← has both classes
      style: selectState,
    });
  }
  return base_style;
}

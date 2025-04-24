const selectState = {
  shape: "roundrectangle",
  "font-weight": "800",
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

export function graphStyle() {
  const base_style = [
    {
      selector: "node",
      style: {
        /* sizing ---------------------------------------------------------- */
        width: 150,
        height: (n) => Math.min(n.data("content").length, 100) + 30,
        "min-width": 60,
        "min-height": 30,
        padding: "12px",
        "text-wrap": "wrap",
        "text-max-width": 150, // interior width incl. padding

        /* label ----------------------------------------------------------- */
        label: (ele) => {
          const full = ele.data("content") || "";
          const text = full.slice(0, 100);
          const suffix = full.length > 100 ? "…" : "";
          return `${ele.data("id")}\n\n${text}${suffix}`;
        },

        /* font & layout --------------------------------------------------- */
        "font-family": "InterVariable, sans-serif",
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
      selector: ".node-hover",
      style: {
        "border-width": 3,
        "z-index": 9999,
      },
    },
    {
      selector: "node[compound]",
      style: {
        label: "data(id)", // ← use the id field
        "text-halign": "center",
        "text-valign": "top",
        "text-margin-y": 0,
        "font-size": 12,
        "font-weight": 600,
        "text-opacity": 1, // make sure it isn’t zero
        /* …border / background… */
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
        "background-opacity": 0.6,
        "background-color": "#E5E7EB", // slate‑200
        "border-width": 2,
        "border-color": "#4B5563",

        /* text centred inside the badge */
        label: "data(id)",
        "text-valign": "center",
        "text-halign": "center",
        "font-size": 12,
        "font-weight": 600,
        "text-wrap": "wrap",
        "text-max-width": 80,
      },
    },
    {
      selector: "node.preview",
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
        "line-color": "#f3f4f6",
        "curve-style": "bezier",
      },
    },
    {
      selector: ".edge-hover",
      style: {
        width: 3,
        "line-color": "#83f28f", // Light green color
        "z-index": 9998,
      },
    },
  ];

  for (const nodeType of Object.keys(cols)) {
    base_style.push({
      selector: `node.${nodeType}`, // ← has the class
      style: {
        //  NOT “css”
        "border-color": cols[nodeType].border,
        "background-color": cols[nodeType].background,
        "border-width": 2,
      },
    });

    base_style.push({
      selector: `node.${nodeType}.selected`, // ← has both classes
      style: selectState,
    });
  }
  return base_style;
}

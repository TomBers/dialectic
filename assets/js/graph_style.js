const selectState = {
  "font-weight": "800",
  "border-color": "white", // Dark green border
  color: "#FFFFFF", // White text
  "background-color": "#14e37c", // Bright mint green (very vibrant)
  "border-width": 2,
};

export function graphStyle(cols_str) {
  const base_style = [
    {
      selector: "node",
      style: {
        "background-color": "#f3f4f6", // gray-100
        "border-width": 2,
        "border-color": "#d1d5db", // gray-300
        label: function (ele) {
          const content = ele.data("content") || "";
          const truncatedContent =
            content.substring(0, 100) + (content.length > 100 ? "..." : "");
          return ele.data("id") + "\n\n" + truncatedContent;
        },
        "text-valign": "center",
        "text-halign": "center",
        "font-family": "InterVariable, sans-serif",
        "font-weight": "400",
        color: "#374151", // gray-700
        "text-wrap": "wrap",
        "text-max-width": "200px",
        shape: "roundrectangle", // Changed from round-diamond to roundrectangle
        width: "label", // Makes the node size fit the content
        height: "label",
        padding: "15px",
        "text-margin-y": 0, // Ensure text is centered vertically
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
    // Clicked node highlight
    {
      selector: "node.selected",
      css: selectState,
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

  const cols = JSON.parse(cols_str);
  for (const nodeType in cols) {
    base_style.push({
      selector: `node[class = "${nodeType}"]`,
      css: {
        "border-color": cols[nodeType].border,
        "background-color": cols[nodeType].background,
        // color: cols[nodeType].text,
      },
    });
    base_style.push({
      selector: `node[class = "${nodeType}"].selected`,
      css: selectState,
    });
  }
  return base_style;
}

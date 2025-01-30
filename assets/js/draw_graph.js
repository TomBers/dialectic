import cytoscape from "cytoscape";

export function draw_graph(graph, elements) {
  const cy = cytoscape({
    container: graph, // container to render in
    elements: elements,

    style: [
      // Base node style
      {
        selector: "node",
        style: {
          "background-color": "#f3f4f6", // gray-100
          "border-width": 2,
          "border-color": "#d1d5db", // gray-300
          label: "data(id)",
          "text-valign": "center",
          "text-halign": "center",
          "font-family": "monospace",
          // "font-size": "18px",
          "font-weight": "600",
          color: "#374151", // gray-700
          // padding: "4px",
          shape: "round-rectangle",
        },
      },
      // Clicked node highlight
      {
        selector: "node.selected",
        css: {
          "font-weight": "800",
          color: "red",
        },
      },
      // Node types matching our chat interface
      {
        selector: `node[class = "thesis"]`,
        css: {
          "border-color": "#34d399", // green-400
          "background-color": "#f0fdf4", // green-50
        },
      },
      {
        selector: `node[class = "antithesis"]`,
        css: {
          "border-color": "#60a5fa", // blue-400
          "background-color": "#eff6ff", // blue-50
        },
      },
      {
        selector: `node[class = "synthesis"]`,
        css: {
          "border-color": "#c084fc", // purple-400
          "background-color": "#faf5ff", // purple-50
        },
      },
      {
        selector: `node[class = "answer"]`,
        css: {
          "border-color": "#4ade80", // green-400
          "background-color": "#f0fdf4", // green-50
        },
      },
      {
        selector: `node[class = "user"]`,
        css: {
          "border-color": "#f87171", // red-400
          "background-color": "#fef2f2", // red-50
        },
      },
      // Edge styling
      {
        selector: "edge",
        style: {
          width: 2,
          "line-color": "#9ca3af", // gray-400
          "target-arrow-color": "#9ca3af", // gray-400
          "target-arrow-shape": "triangle",
          "curve-style": "bezier",
          "arrow-scale": 1.2,
        },
      },
    ],

    layout: {
      name: "breadthfirst",
      directed: true,
      padding: 10,
    },
  });
  return cy;
}

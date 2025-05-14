// Shared layout configuration for consistent graph rendering

export const layoutConfig = {
  // Base layout options
  baseLayout: {
    name: "dagre",
    rankDir: "TB",
    nodeSep: 50,
    edgeSep: 50,
    rankSep: 20,
    spacingFactor: 1.5,
    padding: 30,
    // Consider parent nodes in layout calculation
    weaveToward: "leaves",
    fit: true,
    nestingFactor: 0.8,
    // Handle compound nodes more intelligently
    ranker: "network-simplex",
    // Improve alignment within compounds
    align: "UL", // Upper left alignment
  },
};

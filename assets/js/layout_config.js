// Shared layout configuration for consistent graph rendering - enhanced for visual appeal

export const layoutConfig = {
  // Base layout options
  baseLayout: {
    name: "dagre",
    rankDir: "TB",
    // Spacing adjustments for better proportions
    nodeSep: 35, // Horizontal spacing between nodes (further reduced)
    edgeSep: 25, // Spacing between parallel edges (further reduced)
    rankSep: 45, // Vertical spacing between ranks (significantly reduced)
    // Visual enhancement settings
    spacingFactor: 0.95, // Tighter spacing factor for more compact layout
    padding: 25, // Minimum padding around the graph
    // More natural arrangement for complex graphs
    weaveToward: "leaves",
    nestingFactor: 1.0, // Full size for compound nodes
    fit: false, // Do not auto-fit to viewport
    // Higher quality layout algorithm
    ranker: "network-simplex", // More compact layout algorithm
    // Better alignment for hierarchical structures
    align: "DL", // Down-Left
    // Animation settings
    animate: true,
    animationDuration: 250, // Faster animations
    animationEasing: "ease-out-cubic",
    // Additional compactness settings
    gravity: 1.5, // Pull nodes toward the center
  },

  // Layout options for expanded compound nodes
  expandLayout: {
    name: "dagre",
    fit: false,
    padding: 25,
    animate: true,
    animationDuration: 300,
    // Spacing for expanded compound nodes
    nodeSep: 15,
    edgeSep: 12,
    rankSep: 35,
    // Better handling of expanded groups
    spacingFactor: 0.8,
    nestingFactor: 0.95,
    align: "DL", // Down-left alignment for better compound node layout
  },

  // Compound drag and drop options
  compoundDragDropOptions: {
    grabbedNode: () => true,
    dropTarget: () => true,
    dropSibling: () => false,
    newParentNode: () => [],
    boundingBoxOptions: { includeLabels: true, includeOverlays: false },
    overThreshold: 10,
    outThreshold: 10,
  },

  // Vertical spacing settings for styling
  nodeSpacing: {
    marginTop: 10,
    marginBottom: 10,
  },

  // Edge routing settings
  edgeSettings: {
    // Curve factor for edges
    curve: 0.85,
    // Offset distance for multiple edges between same nodes
    edgeOffset: 2,
    // Controls edge curvature variety
    randomness: 0.1,
    // Preferred edge angle from the node
    idealEdgeLength: 50,
    // Min separation between parallel edges
    minEdgeSeparation: 8,
    // Edge attraction force
    elasticity: 0.8,
  },
};

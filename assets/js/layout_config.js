// Shared layout configuration for consistent graph rendering - enhanced for visual appeal

export const layoutConfig = {
  // Base layout options (spaced view - default)
  baseLayout: {
    name: "dagre",
    rankDir: "TB",
    // Spacing adjustments for better proportions
    nodeSep: 50, // Horizontal spacing between nodes
    edgeSep: 30, // Spacing between parallel edges
    rankSep: 70, // Vertical spacing between ranks
    // Visual enhancement settings
    spacingFactor: 1.05, // Relaxed spacing factor for more readable layout
    padding: 30, // Minimum padding around the graph
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

  // Compact layout options
  compactLayout: {
    name: "dagre",
    rankDir: "TB",
    // Tighter spacing for compact view
    nodeSep: 35, // Horizontal spacing (increased to prevent child overlaps)
    edgeSep: 15, // Minimal spacing between parallel edges
    rankSep: 35, // Minimal vertical spacing (increased to prevent overlap)
    // Visual enhancement settings
    spacingFactor: 0.9, // Tight spacing factor (slightly relaxed)
    padding: 15, // Minimal padding
    // More natural arrangement for complex graphs
    weaveToward: "leaves",
    nestingFactor: 0.9, // Smaller compound nodes
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
    gravity: 2.2, // Pull nodes more toward the center
  },

  // Layout options for expanded compound nodes
  expandLayout: {
    name: "dagre",
    fit: false,
    padding: 30,
    animate: true,
    animationDuration: 300,
    // Spacing for expanded compound nodes
    nodeSep: 30,
    edgeSep: 15,
    rankSep: 50,
    // Better handling of expanded groups
    spacingFactor: 1.0,
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

  // Zoom interaction settings
  zoomSettings: {
    min: 0.05,
    max: 4.0,
    sensitivity: 0.0025,
    pinchSensitivity: 2.0,
  },
};

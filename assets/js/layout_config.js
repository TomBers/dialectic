// Shared layout configuration for consistent graph rendering - enhanced for visual appeal

export const layoutConfig = {
  // Base layout options
  baseLayout: {
    name: "dagre",
    rankDir: "TB",
    nodeDimensionsIncludeLabels: true,
    acyclicer: "greedy",
    // Spacing adjustments for better proportions
    nodeSep: 60, // Increased horizontal spacing between nodes
    edgeSep: 40, // Increased spacing between parallel edges
    rankSep: 80, // Increased vertical spacing between ranks
    // Visual enhancement settings
    spacingFactor: 1.05, // Slightly looser spacing for readability
    padding: 50, // Increased padding around the graph
    // More natural arrangement for complex graphs

    fit: true, // Fit graph to viewport
    // Higher quality layout algorithm
    ranker: "network-simplex", // More compact layout algorithm
    // Better alignment for hierarchical structures
    align: "UL", // Upper-Left
    // Animation settings
    animate: false,
    animationDuration: 250, // Faster animations
    animationEasing: "ease-out-cubic",
    // Additional compactness settings
  },

  // Layout options for expanded compound nodes
  expandLayout: {
    name: "dagre",
    fit: false,
    padding: 35,
    animate: false,
    animationDuration: 250,
    nodeDimensionsIncludeLabels: true,
    // Spacing for expanded compound nodes
    nodeSep: 30,
    edgeSep: 20,
    rankSep: 60,
    // Better handling of expanded groups
    spacingFactor: 0.9,
    align: "UL", // Upper-left alignment for better compound node layout
    acyclicer: "greedy",
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

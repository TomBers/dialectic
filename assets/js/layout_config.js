// Shared layout configuration for consistent graph rendering - enhanced for visual appeal

export const layoutConfig = {
  // Base layout options
  baseLayout: {
    name: "dagre",
    rankDir: "TB",
    // Spacing adjustments for better proportions
    nodeSep: 60,    // Horizontal spacing between nodes
    edgeSep: 45,    // Spacing between parallel edges
    rankSep: 80,    // Vertical spacing between ranks
    // Visual enhancement settings
    spacingFactor: 1.2,  // Adjust overall spacing 
    padding: 40,         // Padding around the graph
    // More natural arrangement for complex graphs
    weaveToward: "leaves",
    nestingFactor: 1.0,  // Full size for compound nodes
    fit: true,           // Fit graph to viewport
    // Higher quality layout algorithm
    ranker: "tight-tree",
    // Better alignment for hierarchical structures
    align: "DL",
    // Animation settings
    animate: true,
    animationDuration: 300,
    animationEasing: "ease-in-out-quad",
  },
  
  // Layout options for expanded compound nodes
  expandLayout: {
    name: "dagre",
    fit: false,
    padding: 35,
    animate: true,
    animationDuration: 300,
    // Spacing for expanded compound nodes
    nodeSep: 30,
    edgeSep: 20,
    rankSep: 60,
    // Better handling of expanded groups
    spacingFactor: 1.1,
    nestingFactor: 1.0,
    align: "DL",         // Down-left alignment for better compound node layout
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
    marginTop: 15,
    marginBottom: 15,
  },
  
  // Edge routing settings
  edgeSettings: {
    // Curve factor for edges
    curve: 1.2,
    // Offset distance for multiple edges between same nodes
    edgeOffset: 5,
    // Controls edge curvature variety
    randomness: 0.2,
    // Preferred edge angle from the node
    idealEdgeLength: 100,
    // Min separation between parallel edges
    minEdgeSeparation: 15,
  }
};
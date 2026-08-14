// Shared layout configuration for consistent graph rendering - enhanced for visual appeal

export const layoutConfig = {
  // Base layout options (spaced view - default)
  baseLayout: {
    name: "dagre",
    rankDir: "TB",
    // Spacing adjustments for better proportions
    nodeSep: 64, // Horizontal spacing between nodes
    edgeSep: 38, // Spacing between parallel edges
    rankSep: 88, // Vertical spacing between ranks
    // Visual enhancement settings
    spacingFactor: 1.08, // Relaxed spacing factor for more readable layout
    padding: 30, // Minimum padding around the graph
    // More natural arrangement for complex graphs
    weaveToward: "leaves",
    nestingFactor: 1.0, // Full size for compound nodes
    fit: false, // Do not auto-fit to viewport
    // Higher quality layout algorithm
    ranker: "network-simplex", // More compact layout algorithm
    // Animation settings
    animate: true,
    animationDuration: 250, // Faster animations
    animationEasing: "ease-out-cubic",
    // Additional compactness settings
    gravity: 1.2, // Pull nodes toward the center without crowding branches
  },

  // Compact layout options
  compactLayout: {
    name: "dagre",
    rankDir: "TB",
    // Tighter spacing for compact view
    nodeSep: 42, // Horizontal spacing (increased to prevent child overlaps)
    edgeSep: 20, // Minimal spacing between parallel edges
    rankSep: 42, // Minimal vertical spacing (increased to prevent overlap)
    // Visual enhancement settings
    spacingFactor: 0.9, // Tight spacing factor (slightly relaxed)
    padding: 15, // Minimal padding
    // More natural arrangement for complex graphs
    weaveToward: "leaves",
    nestingFactor: 0.9, // Smaller compound nodes
    fit: false, // Do not auto-fit to viewport
    // Higher quality layout algorithm
    ranker: "network-simplex", // More compact layout algorithm
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
    nodeSep: 42,
    edgeSep: 20,
    rankSep: 64,
    // Better handling of expanded groups
    spacingFactor: 1.0,
    nestingFactor: 0.95,
  },

  readabilitySettings: {
    spacedMinInitialZoom: 0.75,
    compactMinInitialZoom: 0.78,
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
    sensitivity: 0.0015,
    pinchSensitivity: 1.2,
  },

  interactionSettings: {
    viewportMargin: 32,
    viewportTolerance: 0.25,
    minVisibleRatio: 0.24,
    minVisiblePixels: 160,
    maxVisiblePixels: 280,
    wheelLineStep: 16,
    wheelPageFactor: 0.75,
    wheelPanSpeed: 0.5,
    wheelPanMaxStep: 96,
  },
};

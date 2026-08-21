// Shared layout configuration for consistent graph rendering - enhanced for visual appeal

const stableElementSort = (elementA, elementB) => {
  const idA = String(elementA.id());
  const idB = String(elementB.id());

  if (idA < idB) return -1;
  if (idA > idB) return 1;
  return 0;
};

const dagreRenderingOptions = {
  nodeDimensionsIncludeLabels: true,
  sort: stableElementSort,
};

export const layoutConfig = {
  // Base layout options (spaced view - default)
  baseLayout: {
    name: "dagre",
    rankDir: "TB",
    // Spacing adjustments for better proportions
    nodeSep: 52, // Keep sibling branches compact across the canvas
    edgeSep: 38, // Spacing between parallel edges
    rankSep: 104, // Give each level more vertical breathing room
    // Visual enhancement settings
    spacingFactor: 1.04, // Slight vertical bias without spreading the whole graph
    padding: 30, // Minimum padding around the graph
    // More natural arrangement for complex graphs
    ...dagreRenderingOptions,
    fit: false, // Do not auto-fit to viewport
    // Higher quality layout algorithm
    ranker: "network-simplex", // More compact layout algorithm
    // Animation settings
    animate: true,
    animationDuration: 250, // Faster animations
    animationEasing: "ease-out-cubic",
  },

  // Compact layout options
  compactLayout: {
    name: "dagre",
    rankDir: "TB",
    // Tighter spacing for compact view
    nodeSep: 36, // Keep the overview narrow while preserving branch separation
    edgeSep: 20, // Minimal spacing between parallel edges
    rankSep: 56, // Separate levels so the compact graph reads vertically
    // Visual enhancement settings
    spacingFactor: 0.9, // Tight spacing factor (slightly relaxed)
    padding: 15, // Minimal padding
    // More natural arrangement for complex graphs
    ...dagreRenderingOptions,
    fit: false, // Do not auto-fit to viewport
    // Higher quality layout algorithm
    ranker: "network-simplex", // More compact layout algorithm
    // Animation settings
    animate: true,
    animationDuration: 250, // Faster animations
    animationEasing: "ease-out-cubic",
  },

  // Layout options for expanded compound nodes
  expandLayout: {
    name: "dagre",
    fit: false,
    padding: 30,
    animate: true,
    animationDuration: 300,
    // Spacing for expanded compound nodes
    nodeSep: 36,
    edgeSep: 20,
    rankSep: 76,
    // Better handling of expanded groups
    spacingFactor: 1.0,
    ...dagreRenderingOptions,
  },

  readabilitySettings: {
    spacedMinInitialZoom: 0.85,
    compactMinInitialZoom: 0.82,
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

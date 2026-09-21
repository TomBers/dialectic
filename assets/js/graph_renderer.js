import cytoscape from "cytoscape";

let webglUnavailable = false;

export function refreshGraphLabels(cy) {
  if (!cy || cy.destroyed()) return;
  const renderer = cy.renderer();
  if (!renderer.webgl) return;

  // A loaded web font changes glyph widths without changing Cytoscape's style
  // keys. Invalidate both the wrapping/measurement cache and its GPU textures.
  const elements = cy.elements();
  elements.forEach((element) => {
    const scratch = element._private.rscratch;
    for (const prefix of ["", "source", "target"]) {
      delete scratch[prefix ? `${prefix}LabelWrapKey` : "labelWrapKey"];
      delete scratch[prefix ? `${prefix}PrefixedLabelDimsKey` : "prefixedLabelDimsKey"];
    }
  });
  elements.dirtyBoundingBoxCache();
  renderer.recalculateRenderedStyle(elements, false);
  renderer.drawing.atlasManager.invalidate(elements, {
    forceRedraw: true,
    filterType: (type) => ["label", "edge-source-label", "edge-target-label"].includes(type),
  });
  cy.forceRender();
}

export function prepareWebglRenderer(renderer) {
  // Keep WebGL drawing, but use the established geometry-based pointer tests.
  // The 3.34 GPU picker ignores interactiveElementsOnly/isTouch and consumes
  // screen redraw flags during its offscreen pass. Canvas picking preserves
  // node/edge precedence and mouse/touch tolerances without reading GPU pixels.
  renderer.findNearestElements =
    cytoscape("renderer", "canvas").prototype.findNearestElements;

  const atlas = renderer.drawing.atlasManager;
  // The 3.34 wrapped-texture copy path can leave a label line blank after
  // cache compaction. Keep each texture in one row, including replacement
  // atlases created by garbage collection. This trades some packing density
  // for complete titles and stable cached node bodies.
  for (const type of ["node", "label"]) {
    const collection = atlas.getAtlasCollection(type);
    const createAtlas = collection._createAtlas;
    collection._createAtlas = function (...args) {
      const textureAtlas = createAtlas.apply(this, args);
      textureAtlas.enableWrapping = false;
      return textureAtlas;
    };
  }

  // Labels bake opacity into their texture, but the upstream style key omits
  // it. Keep dimmed search results and hovered/selected labels independent.
  for (const type of ["label", "edge-source-label", "edge-target-label"]) {
    const options = atlas.getRenderTypeOpts(type);
    const getKey = options.getKey;
    options.getKey = (element) => {
      const key = getKey(element);
      const prefix = `${element.effectiveOpacity()}:${element.pstyle("text-opacity").value}:`;
      // Keep the trailing _lineIndex intact for Cytoscape's multiline bounds.
      return Array.isArray(key)
        ? key.map((lineKey) => prefix + lineKey)
        : prefix + key;
    };
  }
}

function initializeRenderer(options, webgl) {
  // Cytoscape 3.34 retains a fourth canvas layer after WebGL initialization.
  // Its shared type list must use 2D for that unused layer during fallback,
  // otherwise a browser without WebGL cannot initialize Canvas either.
  const canvasTypes = cytoscape("renderer", "canvas").prototype.CANVAS_TYPES;
  const previousType = canvasTypes[3];
  if (!webgl) canvasTypes[3] = "2d";
  try {
    return cytoscape({ ...options, renderer: { name: "canvas", webgl } });
  } finally {
    canvasTypes[3] = previousType;
  }
}

export function createGraphRenderer(options, onContextLost) {
  const { webgl = true, ...graphOptions } = options;
  const useWebgl = webgl && !webglUnavailable;
  let cy;

  try {
    cy = initializeRenderer(graphOptions, useWebgl);
  } catch (error) {
    if (!useWebgl) throw error;
    webglUnavailable = true;
    // A failed constructor registers its partial core on the container.
    graphOptions.container?._cyreg?.cy?.destroy();
    console.warn("WebGL initialization failed; using Canvas.", error);
    cy = initializeRenderer(graphOptions, false);
  }

  const container = cy.container();
  const canvas = container.querySelector('canvas[data-id="layer3-webgl"]');
  container.dataset.renderer = cy.renderer().webgl ? "webgl" : "canvas";
  if (!cy.renderer().webgl) return cy;
  prepareWebglRenderer(cy.renderer());

  const gl = canvas.getContext("webgl2");
  let recoveryFrame = null;
  const handleContextLost = (event) => {
    event.preventDefault();
    if (cy.destroyed() || recoveryFrame !== null) return;
    webglUnavailable = true;
    recoveryFrame = requestAnimationFrame(() => {
      recoveryFrame = null;
      if (!cy.destroyed()) onContextLost(cy);
    });
  };

  canvas.addEventListener("webglcontextlost", handleContextLost);
  cy.one("destroy", () => {
    canvas.removeEventListener("webglcontextlost", handleContextLost);
    if (recoveryFrame !== null) cancelAnimationFrame(recoveryFrame);
    if (!gl.isContextLost()) gl.getExtension("WEBGL_lose_context")?.loseContext();
  });
  return cy;
}

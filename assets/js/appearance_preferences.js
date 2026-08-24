export const DEFAULT_APPEARANCE = Object.freeze({
  readingDensity: "comfortable",
  readingFont: "serif",
  graphViewMode: "spaced",
  graphDirection: "TB",
  reduceMotion: false,
  highContrast: false,
});

const READING_DENSITIES = ["compact", "comfortable", "large"];
const READING_FONTS = ["sans", "serif"];
const GRAPH_VIEW_MODES = ["spaced", "compact"];
const GRAPH_DIRECTIONS = ["TB", "BT", "LR", "RL"];

const validOrDefault = (value, validValues, fallback) =>
  validValues.includes(value) ? value : fallback;

const booleanOrDefault = (value, fallback) => {
  if (value === true || value === "true") return true;
  if (value === false || value === "false") return false;
  return fallback;
};

export const appearanceFromDataset = (dataset = {}) => ({
  readingDensity: validOrDefault(
    dataset.readingDensity,
    READING_DENSITIES,
    DEFAULT_APPEARANCE.readingDensity,
  ),
  readingFont: validOrDefault(
    dataset.readingFont,
    READING_FONTS,
    DEFAULT_APPEARANCE.readingFont,
  ),
  graphViewMode: validOrDefault(
    dataset.graphViewMode,
    GRAPH_VIEW_MODES,
    DEFAULT_APPEARANCE.graphViewMode,
  ),
  graphDirection: validOrDefault(
    dataset.graphDirection,
    GRAPH_DIRECTIONS,
    DEFAULT_APPEARANCE.graphDirection,
  ),
  reduceMotion: booleanOrDefault(
    dataset.reduceMotion,
    DEFAULT_APPEARANCE.reduceMotion,
  ),
  highContrast: booleanOrDefault(
    dataset.highContrast,
    DEFAULT_APPEARANCE.highContrast,
  ),
});

export const syncGraphAppearanceStorage = (
  dataset = {},
  storage = localStorage,
) => {
  const appearance = appearanceFromDataset(dataset);

  try {
    storage.setItem("graph_view_mode", appearance.graphViewMode);
    storage.setItem("graph_direction", appearance.graphDirection);
  } catch (_error) {}

  return appearance;
};

import HighlightUtils from "./highlight_utils.js";

const graphs = new Map();
const empty = Object.freeze([]);

export function nodeHighlights(graphId, nodeId) {
  return graphs.get(graphId)?.nodes.get(String(nodeId)) || empty;
}

export function cachedHighlight(graphId, highlightId) {
  return graphs.get(graphId)?.byId.get(String(highlightId));
}

function receiveHighlights({ detail: { graph_id: graphId, highlights = [] } }) {
  const graph = graphs.get(graphId);
  if (!graph) return;
  const next = new Map();
  for (const highlight of highlights) {
    const id = String(highlight.node_id);
    if (!next.has(id)) next.set(id, []);
    next.get(id).push(highlight);
  }
  const signatures = new Map();
  for (const [id, items] of next) {
    signatures.set(id, JSON.stringify(items.map(h => [String(h.id), HighlightUtils.highlightSignature(h)]).sort()));
  }
  const previous = graph.signatures;
  graph.nodes = next;
  graph.byId = new Map(highlights.map(h => [String(h.id), h]));
  graph.signatures = signatures;
  for (const [nodeId, callbacks] of graph.subscribers) {
    if (previous.get(nodeId) !== signatures.get(nodeId)) {
      for (const callback of callbacks) callback();
    }
  }
}

export function subscribeHighlights(graphId, nodeId, callback) {
  if (graphs.size === 0) window.addEventListener("phx:highlights_loaded", receiveHighlights);
  if (!graphs.has(graphId)) graphs.set(graphId, { nodes: new Map(), byId: new Map(), signatures: new Map(), subscribers: new Map() });
  const graph = graphs.get(graphId);
  const id = String(nodeId);
  if (!graph.subscribers.has(id)) graph.subscribers.set(id, new Set());
  const callbacks = graph.subscribers.get(id);
  callbacks.add(callback);
  return () => {
    callbacks.delete(callback);
    if (callbacks.size === 0) graph.subscribers.delete(id);
    if (graph.subscribers.size === 0) graphs.delete(graphId);
    if (graphs.size === 0) window.removeEventListener("phx:highlights_loaded", receiveHighlights);
  };
}

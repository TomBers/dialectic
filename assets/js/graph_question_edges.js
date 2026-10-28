const classes = (element) => Array.isArray(element.classes)
  ? element.classes
  : String(element.classes || "").split(/\s+/);

const questionTitle = (node) => String(node.data.content || "")
  .split(/\r?\n/).find((line) => line.trim())
  ?.replace(/^\s*#{1,6}\s*/, "").replace(/\*\*/g, "").trim() || "Question";

export function projectQuestionEdges(elements) {
  const nodes = new Map();
  const edges = [];
  for (const element of elements) {
    if (!element?.data) continue;
    if (element.data.source != null && element.data.target != null) edges.push(element);
    else nodes.set(String(element.data.id), element);
  }

  const questions = new Set([...nodes].filter(([, node]) =>
    classes(node).includes("question") && !classes(node).includes("origin"),
  ).map(([id]) => id));
  if (questions.size === 0) return elements;

  const outgoing = new Map();
  const incoming = new Set();
  for (const edge of edges) {
    const source = String(edge.data.source);
    const target = String(edge.data.target);
    if (!nodes.has(source) || !nodes.has(target)) continue;
    if (!outgoing.has(source)) outgoing.set(source, []);
    outgoing.get(source).push(edge);
    incoming.add(target);
  }

  const projected = [...nodes].filter(([id]) => !questions.has(id)).map(([, node]) => node);
  const emitted = new Set(projected.map((element) => String(element.data.id)));
  const coveredQuestions = new Set();
  const emit = (element) => {
    if (emitted.has(element.data.id)) return;
    emitted.add(element.data.id);
    projected.push(element);
  };
  const endpoint = (id, questionId, parent) => {
    emit({data: {id, questionNodeId: questionId, ...(parent ? {parent} : {})},
      classes: "question-endpoint"});
    return id;
  };
  const connect = (source, target, questionIds, path) => {
    const last = path.at(-1);
    emit({
      data: {
        ...last.data,
        id: `question-edge:${JSON.stringify(path.map((edge) => edge.data.id))}`,
        source,
        target,
        questionIds,
        questionNodeId: questionIds.at(-1),
        questionLabel: questionIds.map((id) => questionTitle(nodes.get(id))).join("\n\n"),
      },
      classes: "question-edge",
    });
  };

  const follow = (source, edge, questionIds = [], path = []) => {
    const id = String(edge.data.target);
    const nextPath = [...path, edge];
    if (!questions.has(id)) {
      if (questionIds.length) connect(source, id, questionIds, nextPath);
      else emit(edge);
      return;
    }
    // Malformed cycles must not recurse indefinitely or erase the question.
    if (questionIds.includes(id)) return;
    coveredQuestions.add(id);
    const nextQuestions = [...questionIds, id];
    const children = (outgoing.get(id) || []).filter((child) =>
      !nextQuestions.includes(String(child.data.target)),
    );
    if (!children.length) {
      const target = endpoint(`question-endpoint:${id}`, id, nodes.get(id).data.parent);
      connect(source, target, nextQuestions, nextPath);
    } else {
      for (const child of children) follow(source, child, nextQuestions, nextPath);
    }
  };

  for (const [id] of nodes) {
    if (!questions.has(id)) {
      for (const edge of outgoing.get(id) || []) follow(id, edge);
    }
  }
  // Orphan questions still appear as labelled, open-ended branches.
  for (const id of questions) {
    if (coveredQuestions.has(id) || incoming.has(id)) continue;
    const root = endpoint(`question-root:${id}`, id, nodes.get(id).data.parent);
    follow(root, {data: {id: `question-root-edge:${id}`, source: root, target: id}});
  }
  for (const id of questions) {
    if (coveredQuestions.has(id)) continue;
    const root = endpoint(`question-root:${id}`, id, nodes.get(id).data.parent);
    follow(root, {data: {id: `question-root-edge:${id}`, source: root, target: id}});
  }
  return projected;
}

export const questionEdgesFor = (cy, id) => cy.edges().filter((edge) =>
  (edge.data("questionIds") || []).includes(String(id)),
);

export function resolveGraphNode(cy, id) {
  const node = cy.getElementById(String(id));
  if (node.length) return node;
  const edges = questionEdgesFor(cy, id);
  const answers = edges.filter((edge) => edge.target().hasClass("answer"));
  const edge = (answers.length ? answers : edges).first();
  return edge.length ? edge.target() : node;
}

export const graphNodeId = (node) => node.data("questionNodeId") || node.id();

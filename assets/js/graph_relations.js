const RELATION_LABELS = {
  answer: "is answered by",
  initial_explainer: "is answered by",
  explain: "is explained by",
  question: "asks",
  thesis: "develops",
  antithesis: "challenges",
  synthesis: "synthesizes",
  ideas: "explores related ideas",
  user: "adds",
  learning_plan: "guides learning",
  guided_learning_plan_question: "asks for a learning plan",
  guided_learning_plan: "guides learning",
  selection_explain_question: "asks about the selection",
  selection_explain: "explains the selection",
  selection_question_input: "asks about the selection",
  selection_question: "answers about the selection",
  clarify: "clarifies",
  assumptions: "surfaces assumptions",
  counterexample: "tests with a counterexample",
  implications: "draws implications",
  blind_spots: "reveals blind spots",
  says_who: "questions the source",
  who_disagrees: "finds disagreement",
  steel_man: "strengthens",
  what_if: "reframes",
};

export const edgeRelationLabel = (edge) => {
  const relation = edge.data("relation");
  if (relation && RELATION_LABELS[relation]) return RELATION_LABELS[relation];

  const targetClasses = edge.target?.().classes?.() || [];
  const targetRelation = targetClasses.find((className) => RELATION_LABELS[className]);

  return RELATION_LABELS[targetRelation] || "leads to";
};

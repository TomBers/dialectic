# Project Proposal: MuDG × Peter Worley Collaboration

**Critical Thinking Through Structured Argument Mapping**

*A collaboration between MuDG (Multi-Dimensional Graph) and Peter Worley, author of The If Machine: Philosophical Enquiry in the Classroom*

---

## 1. Executive Summary

MuDG is an AI-augmented argument mapping tool that visualises the structure of reasoning as an interactive graph. Peter Worley's work in Philosophy for Children (P4C) and philosophical enquiry has established powerful pedagogical frameworks for developing critical thinking in learners of all ages.

This proposal outlines a collaboration to adapt and extend MuDG's capabilities specifically for critical thinking education, drawing on Worley's expertise in facilitated philosophical enquiry. The goal is to create a suite of tools that make the invisible architecture of reasoning *visible* — helping students, educators, and thinkers formalise arguments, interrogate the language they use, and apply structured thinking methods to any text or claim.

---

## 2. Background

### 2.1 MuDG — What It Already Does

MuDG allows users to explore ideas through a branching graph of interconnected nodes. Its current capabilities include:

- **Dialectical Exploration** — Any claim can be branched into a *thesis* (argument for) and *antithesis* (argument against), with AI generating substantive arguments for each side.
- **Synthesis** — Two positions can be combined into a synthesis that identifies common ground and resolves tensions.
- **Deep Dives** — Any node can be explored in greater depth, surfacing nuance, edge cases, and expert disagreements.
- **Related Ideas** — The system suggests adjacent concepts, thinkers, and rabbit holes to broaden enquiry.
- **Text Selection & Highlighting** — Users can highlight specific passages within a node and ask questions, argue for/against, or explore that specific selection.
- **Multiple Reading Levels** — Content can be generated at expert, university, high school, or simple (age 5+) levels.
- **Collaborative Mapping** — Multiple users can contribute to and explore the same argument graph.

### 2.2 Peter Worley's Approach

Worley's philosophical enquiry method emphasises:

- **Socratic questioning** — Using carefully structured questions to draw out assumptions, contradictions, and implications.
- **Conceptual analysis** — Examining what key words and concepts *really* mean, and whether different speakers mean different things by the same word.
- **Thought experiments** — Using "what if" scenarios to stress-test reasoning and reveal hidden commitments.
- **The distinction between anchoring and opening moves** — Grounding a discussion before opening it up to genuine enquiry.

---

## 3. Proposed Workstreams

### 3.1 Argument Formalisation Engine

**Goal:** Help users move from informal, natural-language reasoning to explicitly structured arguments — making hidden premises visible, identifying logical form, and exposing where reasoning is strong or weak.

#### Features

- **Premise Extraction** — Given a passage of text or a claim in the graph, the system identifies and lists the underlying premises (stated and unstated) as separate, connected nodes. Users can then examine, challenge, or modify each premise independently.

- **Assumption Surfacing** — A dedicated "What am I assuming?" action that analyses a node and generates a set of *hidden assumptions* required for the argument to hold. Each assumption becomes its own node, available for further enquiry. MuDG already supports an `assumption` node class — this workstream gives it a pedagogical workflow.

- **Argument Structure Visualisation** — A view mode that renders the graph in standard argument map notation (premises → intermediate conclusions → final conclusion), making logical dependencies explicit. This could follow Toulmin's model (Claim, Grounds, Warrant, Backing, Qualifier, Rebuttal) or a simpler premise-conclusion structure appropriate to the audience level.

- **Validity & Soundness Checks** — At the expert/university level, the system could flag common informal fallacies (straw man, false dichotomy, appeal to authority, etc.) when analysing an argument's structure, and prompt the user to consider whether the reasoning is valid and the premises are true.

- **Guided Formalisation Workflow (The "If Machine" Flow):**
  1. **Anchor** — User enters or pastes a claim, passage, or thought experiment.
  2. **Identify** — System extracts the core claim and its premises.
  3. **Question** — System generates Socratic questions targeting each premise ("What would have to be true for this to hold?", "Can you think of a case where this premise fails?").
  4. **Branch** — User (or AI) generates thesis/antithesis for the most contested premise.
  5. **Reflect** — System prompts synthesis or revised formulation.

### 3.2 Key Word Analysis — "What Do You Mean By…?"

**Goal:** One of the most powerful moves in philosophical enquiry is asking "What do you mean by X?" This workstream builds tools to systematically explore how key terms are used, misused, and contested within a text or discussion.

#### Features

- **Key Word Extraction** — Analyse a document or node and identify the *load-bearing* words — terms whose meaning significantly affects the argument's force. For example, in "AI systems should be fair," the word *fair* is doing enormous conceptual work.

- **Sense Disambiguation** — For each key word, generate a set of distinct meanings, uses, or interpretations. Present these as branching nodes:
  - *Fair* → "Treating everyone identically" / "Treating everyone equitably" / "Procedurally unbiased" / "Producing equal outcomes"
  - Each sense becomes a new starting point: "If we mean *fair* in sense A, then the argument leads here; if sense B, it leads there."

- **Equivocation Detection** — Flag cases where a key term appears to shift meaning between premises. For example: "Banks should be secure → River banks are banks → Therefore river banks should be secure." The system highlights where a word is used in two different senses within the same argument thread.

- **Conceptual Mapping** — For a given key word, generate a mini concept-map showing related terms, opposites, near-synonyms, and boundary cases. This mirrors Worley's technique of exploring the "conceptual neighbourhood" of a term.

- **"Swap the Word" Experiments** — Allow users to substitute a key word with an alternative and see how the argument changes. For instance, replacing "freedom" with "autonomy" or "liberty" and exploring whether the argument still holds, breaks, or shifts in interesting ways.

- **Document-Level Word Audit** — Upload or paste a document and receive an analysis of its key terms, noting where they are defined, where they are used ambiguously, and where different sections may be using the same word in different ways.

### 3.3 Critical Thinking Toolkit — Structured Enquiry Actions

**Goal:** Extend MuDG's action menu with a suite of critical thinking operations that can be applied to any node, inspired by philosophical enquiry methods.

#### Proposed Actions

| Action | Description | Inspired By |
|---|---|---|
| **"What if…?"** | Generate a thought experiment that tests the claim under unusual or extreme conditions. | Worley's If Machine method |
| **"Says who?"** | Trace the claim's authority — who originated this idea, what evidence supports it, and what credentials or biases might be at play. | Source evaluation / epistemic responsibility |
| **"So what?"** | Explore the *implications* and *consequences* of accepting this claim. If it's true, what follows? | Consequential thinking |
| **"Is that always true?"** | Generate counterexamples, edge cases, and boundary conditions that test the universality of a claim. | Falsification / conceptual boundary-testing |
| **"Who would disagree?"** | Identify specific thinkers, traditions, or perspectives that would challenge this position, with their strongest objections. | Perspective-taking / adversarial collaboration |
| **"What's missing?"** | Analyse what the argument does *not* address — blind spots, excluded perspectives, unconsidered evidence. | Completeness checking |
| **"Rewrite for a 10-year-old"** | Force clarity by restating the argument in the simplest possible terms. Often reveals confusion. | Feynman technique / Worley's accessibility principle |
| **"Steel man this"** | Generate the *strongest possible version* of an argument the user disagrees with. | Charitable interpretation / intellectual honesty |

### 3.4 Classroom & Facilitation Mode

**Goal:** Create a mode specifically designed for educators using philosophical enquiry in the classroom, aligned with Worley's facilitation methods.

#### Features

- **Session Templates** — Pre-built starting graphs based on classic thought experiments from *The If Machine* and related works (with appropriate licensing). For example: The Ship of Theseus, The Ring of Gyges, the Trolley Problem — each set up with an anchor node and initial branching questions.

- **Facilitator Dashboard** — A view for the teacher/facilitator that shows:
  - Which branches students are exploring
  - Where the most disagreement exists
  - Which assumptions have been surfaced but not yet examined
  - Suggested follow-up questions the facilitator could pose to the group

- **Student Contribution Mode** — Students can add their own arguments, questions, and counterexamples as `user` nodes, building the map collaboratively in real time. The facilitator can curate, highlight, or group contributions.

- **Enquiry Progress Indicators** — Visual signals showing:
  - Claims that have been *challenged but not yet defended*
  - Premises that have been *assumed but not yet examined*
  - Branches that are *one-sided* (only thesis, no antithesis)
  - This encourages balanced, thorough enquiry.

- **Age-Appropriate AI Levels** — MuDG already supports multiple reading levels. This workstream would refine the "simple" and "high school" modes with input from Worley to ensure the language, examples, and reasoning complexity are genuinely appropriate and pedagogically sound.

---

## 4. Phased Delivery Plan

### Phase 1: Foundation (Months 1–3)
- **Argument Formalisation v1** — Premise extraction and assumption surfacing for any node.
- **Key Word Extraction v1** — Identify load-bearing terms in a node or document.
- **"What Do You Mean By…?" action** — Sense disambiguation for a selected term.
- **Pilot testing** with a small group of educators from Worley's network.

### Phase 2: Expansion (Months 4–6)
- **Critical Thinking Toolkit** — Implement the full suite of enquiry actions ("What if…?", "Says who?", "So what?", etc.).
- **Equivocation Detection** — Flag shifting word meanings across an argument thread.
- **Argument Structure View** — Visual rendering of premise-conclusion relationships.
- **Classroom Mode v1** — Session templates, facilitator dashboard, student contribution mode.

### Phase 3: Refinement (Months 7–9)
- **Document-Level Word Audit** — Full-text analysis of key term usage.
- **"Swap the Word" Experiments** — Interactive term substitution.
- **Validity & Fallacy Detection** — Informal fallacy flagging at expert/university levels.
- **Enquiry Progress Indicators** — Visual cues for balanced, thorough exploration.
- **Broader pilot programme** with schools and universities.

---

## 5. Roles & Contributions

### MuDG Team
- Platform development and AI integration
- Prompt engineering for new critical thinking actions
- Graph visualisation and UX design
- Technical infrastructure and hosting

### Peter Worley
- Pedagogical design and review of all enquiry workflows
- Validation that tools align with established P4C and philosophical enquiry principles
- Development and curation of session templates and thought experiments
- Connections to educator networks for pilot testing and feedback
- Co-authorship of educational materials and guides
- Advisory input on age-appropriate language and reasoning levels

---

## 6. Success Metrics

- **Engagement:** Number of educators and students actively using the critical thinking tools.
- **Depth of Enquiry:** Average graph depth and branching factor in classroom sessions (are students going deeper, not just wider?).
- **Assumption Discovery:** Number of hidden assumptions surfaced per session.
- **Balanced Reasoning:** Ratio of thesis-to-antithesis nodes (are users examining both sides?).
- **Educator Feedback:** Qualitative assessment from pilot teachers on whether the tools genuinely improve philosophical enquiry in the classroom.
- **Word Analysis Usage:** Frequency of key word actions — are users interrogating language, not just claims?

---

## 7. Why This Matters

Most AI tools generate answers. MuDG generates *questions* — and then maps the territory those questions open up. Combined with Worley's decades of experience in facilitating genuine philosophical enquiry, this collaboration has the potential to create something rare: a technology that doesn't replace thinking, but makes thinking *visible, structured, and shareable*.

The ability to formalise an argument, interrogate key terms, and systematically apply critical thinking methods is not just an academic skill. It is foundational to informed citizenship, ethical reasoning, and intellectual autonomy. By making these tools accessible and engaging — especially for young people — we aim to lower the barrier to rigorous thinking and raise the quality of public discourse.

---

## 8. Next Steps

1. **Feedback on this proposal** — Review and refine scope with Peter Worley.
2. **Prioritisation workshop** — Identify which features deliver the most pedagogical value soonest.
3. **Pilot educator recruitment** — Identify 5–10 teachers willing to trial early features.
4. **Phase 1 development kick-off** — Begin implementation of foundation workstream.

---

*Prepared by the MuDG team — [Date TBD]*
*For discussion with Peter Worley*
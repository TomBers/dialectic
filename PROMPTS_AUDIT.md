# LLM Prompts Audit & Recommendations

## Executive Summary

The current prompt system is causing repetition because:
1. **No explicit "additive" instructions** - prompts don't tell the model to ADD something new
2. **Context encourages repetition** - phrases like "Use the provided Context to ground your explanation" encourage restatement
3. **Unstructured context** - ancestor content is presented as an unlabeled blob
4. **Missing "continuation" framing** - prompts don't frame responses as continuations of an exploration

## Current System Architecture

### Context Building (`Vertex.build_context/3`)

The context is constructed by:
1. Walking up the parent chain from the current node
2. Including all ancestor content (except questions and compound/group nodes)
3. Respecting group boundaries (nodes with `:parent` field)
4. Enforcing a ~5000 token limit (drops oldest ancestors if exceeded)
5. Concatenating with `"\n\n"` separators

**Issues:**
- No labels or structure to distinguish different ancestors
- No indication of what each piece represents
- Model receives a blob of text with no metadata
- No clear signal that this is "already covered territory"

### Prompt Templates (`Dialectic.Responses.Prompts`)

All prompts follow this pattern:
```
### Context
```text
[blob of ancestor content]
```

[Task instruction]
```

## Detailed Prompt Analysis

### 1. `explain/2` - General Explanation

**Current:**
```
Please explain the following topic: [TOPIC].
Use the provided Context to ground your explanation.
```

**Problems:**
- "Use the provided Context" encourages restating context
- No instruction to ADD new information
- Doesn't position this as extending an existing exploration

**Recommendation:**
```
You are continuing an exploration where the Context below has already been covered.

Your task: Explain [TOPIC] by ADDING new perspectives, details, or insights that EXTEND BEYOND what's already in the Context. Do not merely restate what's already been discussed.
```

---

### 2. `initial_explainer/2` - Initial Answer

**Current:**
```
Please answer the following question: [TOPIC].

In addition to the answer, please provide a basis for ongoing exploration by highlighting extension questions and related topics.
Use the provided Context to ground your explanation.
```

**Problems:**
- Actually better than `explain` due to "ongoing exploration" framing
- Still uses "ground your explanation" which can encourage repetition

**Recommendation:**
```
You are beginning an exploration. The Context provides background.

Your task: Answer [TOPIC] while identifying promising directions for deeper exploration. Suggest 2-3 extension questions or related topics that would enrich understanding.
```

---

### 3. `selection/2` - Explain Selection

**Current:**
```
Please explain or elaborate on the following selection: [SELECTION].
Use the provided Context to ground your response.
```

**Problems:**
- "Elaborate" is vague
- Doesn't clarify what kind of elaboration is wanted

**Recommendation:**
```
A specific phrase was highlighted: [SELECTION]

Your task: Provide deeper insight into this specific concept by:
- Unpacking technical terms or implicit assumptions
- Providing concrete examples or applications
- Connecting to broader implications

Add details and perspectives NOT already covered in the Context.
```

---

### 4. `synthesis/4` - Combine Two Positions

**Current:**
```
Please provide a synthesis that bridges the following two positions:
1. [POS1]
2. [POS2]

Draw upon "Context A" and "Context B" to construct a unified perspective or resolution.
```

**Status:**
✅ **This one is actually good!** 
- Clear goal (synthesis) inherently requires adding something new
- "Bridges" and "unified perspective" signal transformation, not repetition

**Minor improvement:**
```
Two different lines of inquiry have emerged:

Position A: [POS1]
Position B: [POS2]

Your task: Synthesize these positions by identifying:
- Common ground or complementary insights
- A unified framework that integrates both perspectives
- New understanding that emerges from their combination

Do not simply summarize—create something new from their integration.
```

---

### 5. `thesis/2` - Argument In Favor

**Current:**
```
Please provide a detailed argument IN FAVOR OF the following claim: [CLAIM].
Use the provided Context to ground your argument.
```

**Problems:**
- "Detailed argument" could just expand on context points
- "Ground your argument" encourages using existing points
- No instruction to provide NEW reasoning

**Recommendation:**
```
The Context represents existing discussion. 

Your task: Build a strong argument IN FAVOR OF this claim: [CLAIM]

Provide:
- New reasoning, evidence, or examples not yet mentioned
- Novel angles or supporting frameworks
- Fresh perspectives that strengthen the case

Avoid simply restating points already made in the Context.
```

---

### 6. `antithesis/2` - Argument Against

**Current:**
```
Please provide a detailed argument AGAINST the following claim: [CLAIM].
Use the provided Context to ground your argument.
```

**Problems:**
- Same as thesis—encourages repetition

**Recommendation:**
```
The Context represents existing discussion.

Your task: Build a strong argument AGAINST this claim: [CLAIM]

Provide:
- New counterarguments, contradicting evidence, or counterexamples
- Alternative frameworks that challenge the claim
- Fresh critical perspectives not yet explored

Avoid simply restating points already made in the Context.
```

---

### 7. `related_ideas/2` - Adjacent Topics

**Current:**
```
Please suggest adjacent topics, thinkers, or concepts that are related to: [TOPIC].
Ensure your suggestions are tightly grounded in the provided Context.
```

**Problems:**
- "Tightly grounded" might LIMIT exploration
- Could suggest only things directly mentioned in context
- Doesn't encourage novel connections

**Recommendation:**
```
The exploration has covered: [TOPIC]

Your task: Identify 3-5 adjacent topics, thinkers, or concepts that would enrich this exploration.

For each suggestion, briefly explain:
- How it connects to the current topic
- What new dimension it would add to understanding

Prioritize suggestions that open NEW directions, not just variations on what's already been discussed.
```

---

### 8. `deep_dive/2` - Deeper Exploration

**Current:**
```
Write a deep dive on [TOPIC]. Feel free to go beyond the previous word limits, write enough to understand the topic.
```

**Problems:**
- No reference to context at all (might cause repetition or disconnection)
- Doesn't clarify what "deeper" means
- No guidance on what aspects to deepen

**Recommendation:**
```
The Context provides an overview of [TOPIC].

Your task: Write a deep dive that goes BEYOND the overview by:
- Adding technical depth, nuance, or complexity
- Providing concrete examples, case studies, or applications  
- Exploring implications, edge cases, or subtleties
- Addressing questions the overview raises but doesn't answer

You may write at length (beyond normal 500-word limit). Focus on adding substantial new understanding.
```

---

## Context Presentation Issues

### Current Format
```
### Context
```text
[Parent content]

[Grandparent content]

[Great-grandparent content]
```
```

**Problems:**
- No indication of what each section is
- No hierarchy or relationship information
- Just a blob of text
- Not clear this represents "already covered" material

### Recommended Format

**Option A: Labeled Ancestry**
```
### Previous Discussion

The exploration so far has covered:

**Immediate Parent:**
[parent content]

**Earlier in the Thread:**
[grandparent content]

[great-grandparent content]

---

Your response should BUILD UPON this foundation without repeating it.
```

**Option B: Structured Summary**
```
### Context: What's Already Been Covered

Prior nodes in this exploration have established:
- [Node 1 title/summary]
- [Node 2 title/summary]  
- [Node 3 title/summary]

Full content:
```text
[concatenated content]
```

Your task is to EXTEND this exploration, not repeat it.
```

**Option C: Minimal Context with Clear Framing** (Recommended)
```
### Foundation

The following has already been explored:

```text
[context content]
```

↑ This is already covered. Your response should ADD NEW insights beyond what's shown above.
```

---

## System-Level Recommendations

### 1. Add Context Framing Function

Add a helper in `Prompts` module:

```elixir
defp frame_context(context_text) do
  """
  ### Foundation
  
  The following has already been explored:
  
  ```text
  #{context_text}
  ```
  
  ↑ This is already covered. Your response should ADD NEW insights beyond what's shown above.
  """
end
```

### 2. Add Universal Anti-Repetition Footer

Consider adding to all prompts:

```
**Important:** Do not repeat or merely rephrase what's in the Foundation section. Focus on adding genuinely new information, perspectives, or insights.
```

### 3. Update System Prompts

Both `PromptsStructured.system_preamble/0` and `PromptsCreative.system_preamble/0` should include:

```
When Context is provided, treat it as already-covered territory. Your role is to ADVANCE the exploration by adding new information, not to summarize or restate what's already been said.
```

### 4. Consider Node Titles in Context

The context building in `Vertex.build_context/3` could be enhanced to include node titles/IDs:

```elixir
def add_node_context(node_id, graph) do
  case :digraph.vertex(graph, node_id) do
    {_id, dat} -> 
      title = extract_title(dat.content)
      "[#{title}]\n#{dat.content}"
    _ -> ""
  end
end

defp extract_title(content) do
  content
  |> String.split("\n")
  |> Enum.find(&String.starts_with?(&1, "#"))
  |> case do
    nil -> "Node"
    title -> String.replace(title, ~r/^#+\s*/, "") |> String.slice(0..50)
  end
end
```

---

## Implementation Priority

### High Priority (Do First)
1. ✅ Update all prompt templates with "additive" language
2. ✅ Add anti-repetition instructions to system prompts
3. ✅ Implement `frame_context/1` helper with clear "already covered" framing

### Medium Priority
4. Add node titles/structure to context building
5. Add universal anti-repetition footer

### Low Priority (Nice to Have)
6. Consider A/B testing different context formats
7. Add token usage optimization for context

---

## Testing Recommendations

After implementing changes:

1. **Test for repetition**: Create a graph with 3-4 levels and check if child nodes repeat parent content
2. **Test for coherence**: Ensure responses still relate appropriately to context
3. **Test edge cases**: 
   - Very short context
   - Maximum context length
   - Multiple parents (synthesis)
4. **User feedback**: Monitor if users feel responses are adding value

---

## Example: Before & After

### Before (Current)

**Context:**
```
Quantum entanglement is a phenomenon where two particles become correlated...
```

**Prompt:**
```
Please explain the following topic: Quantum Entanglement.
Use the provided Context to ground your explanation.
```

**Result:** ❌ Likely to restate what entanglement is, since that's what's in the context.

---

### After (Proposed)

**Context:**
```
### Foundation

The following has already been explored:

```text
Quantum entanglement is a phenomenon where two particles become correlated...
```

↑ This is already covered. Your response should ADD NEW insights beyond what's shown above.
```

**Prompt:**
```
You are continuing an exploration where the Context below has already been covered.

Your task: Explain Quantum Entanglement by ADDING new perspectives, details, or insights that EXTEND BEYOND what's already in the Foundation. Do not merely restate what's already been discussed.

Focus on aspects like: practical applications, experimental verification, common misconceptions, or deeper mathematical framework.
```

**Result:** ✅ More likely to add new information like EPR paradox, Bell's theorem, or quantum computing applications.

---

## Conclusion

The repetition issue stems from prompts that don't explicitly frame responses as **continuations** that should **add** to an existing exploration. By:

1. Adding clear "additive" language to all prompts
2. Framing context as "already covered territory"  
3. Explicitly instructing models to avoid repetition
4. Providing clearer task structure

We can significantly reduce repetition while maintaining coherence and relevance.
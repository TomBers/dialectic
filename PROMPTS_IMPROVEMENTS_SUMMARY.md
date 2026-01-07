# Prompts Improvements Summary

## Changes Made

### 1. Updated `lib/dialectic/responses/prompts.ex`

**Key Changes:**
- Added `frame_context/1` helper that frames context as "Foundation" and "already covered territory"
- Added `anti_repetition_footer/0` with explicit instruction to avoid repetition
- Rewrote all 8 prompt templates with "additive" language that emphasizes EXTENDING beyond context

**Before/After Examples:**

#### `explain/2` - General Explanation
**Before:**
```
Please explain the following topic: [TOPIC].
Use the provided Context to ground your explanation.
```

**After:**
```
You are continuing an exploration where the Foundation has already been covered.

**Your task:** Explain [TOPIC] by ADDING new perspectives, details, or insights 
that EXTEND BEYOND what's already in the Foundation.

Focus on aspects not yet discussed, such as:
- Deeper mechanisms or processes
- Concrete examples or applications
- Different perspectives or frameworks
- Connections to related concepts

**Important:** Do not repeat or merely rephrase what's in the Foundation section.
```

#### `thesis/2` - Argument In Favor
**Before:**
```
Please provide a detailed argument IN FAVOR OF the following claim: [CLAIM].
Use the provided Context to ground your argument.
```

**After:**
```
The Foundation represents existing discussion.

**Your task:** Build a strong argument IN FAVOR OF this claim: [CLAIM]

Provide:
- New reasoning, evidence, or examples not yet mentioned
- Novel angles or supporting frameworks
- Fresh perspectives that strengthen the case

Avoid simply restating points already made in the Foundation.

**Important:** Do not repeat or merely rephrase what's in the Foundation section.
```

### 2. Updated System Prompts

Both `PromptsStructured` and `PromptsCreative` now include:

```
Graph-based exploration context
- You are part of a conversation graph where each node builds on previous nodes.
- When Foundation/Context is provided, treat it as already-covered territory.
- Your role is to ADVANCE the exploration by adding NEW information, perspectives, or insights.
- Do NOT repeat or merely rephrase what has already been established in the Foundation.
- Each response should contribute something genuinely new to the exploration.
```

### 3. Created Documentation

- `PROMPTS_AUDIT.md` - Comprehensive analysis of issues and recommendations
- `PROMPTS_IMPROVEMENTS_SUMMARY.md` - This file

---

## Why These Changes Work

### Problem: Repetition
The old prompts encouraged repetition through:
1. "Use the provided Context to ground your explanation" → suggests restating context
2. No instruction to ADD something new
3. Context presented as unlabeled blob
4. No framing as a continuation

### Solution: Additive Framing
The new prompts fix this by:
1. **Reframing context** as "Foundation" (already covered territory)
2. **Explicit additive instructions** - "EXTEND BEYOND", "ADD NEW insights"
3. **Clear anti-repetition footer** - "Do not repeat or merely rephrase"
4. **Continuation framing** - "You are continuing an exploration"
5. **Concrete guidance** - Bullet points suggest what to add

---

## All Updated Prompts

### 1. `explain/2` ✅
- Emphasizes EXTENDING beyond foundation
- Lists concrete aspects to focus on
- Anti-repetition footer

### 2. `initial_explainer/2` ✅
- Frames as "beginning an exploration"
- Requests extension questions
- Clear structure (answer + 2-3 extensions)

### 3. `selection/2` ✅
- Clarifies "elaborate" means unpacking, examples, implications
- Focus on "NOT already covered"
- Anti-repetition footer

### 4. `synthesis/4` ✅
- Already good, minor improvements
- Explicit: "Do not simply summarize—create something new"
- Two foundations clearly separated

### 5. `thesis/2` ✅
- "New reasoning, evidence, or examples not yet mentioned"
- "Avoid simply restating points"
- Anti-repetition footer

### 6. `antithesis/2` ✅
- "New counterarguments, contradicting evidence"
- "Fresh critical perspectives not yet explored"
- Anti-repetition footer

### 7. `related_ideas/2` ✅
- Changed from "tightly grounded" to "open NEW directions"
- Prioritizes novelty over repetition
- For each suggestion, explain connection + new dimension

### 8. `deep_dive/2` ✅
- "Goes BEYOND the overview"
- Lists what to add: depth, examples, implications, subtleties
- Can exceed word limit
- Anti-repetition footer

---

## Testing Guide

### Manual Testing

1. **Test Repetition Reduction**
   - Create a graph: Origin → Answer → Deepdive
   - Check if Deepdive repeats Answer content
   - Expected: Deepdive adds NEW depth/examples/implications

2. **Test Branching (Thesis/Antithesis)**
   - Create: Origin → Branch (creates Thesis + Antithesis)
   - Check if they provide NEW arguments vs repeating origin
   - Expected: Novel reasoning on both sides

3. **Test Synthesis**
   - Combine two nodes with different perspectives
   - Check if synthesis creates something new vs summarizing
   - Expected: Integration that transcends both inputs

4. **Test Related Ideas**
   - Ask for related ideas from any node
   - Check if suggestions are truly NEW vs obvious from context
   - Expected: Novel connections, not just restatements

5. **Test Answer Chain**
   - Origin → Question → Answer → Question → Answer
   - Check if second answer avoids repeating first answer
   - Expected: Each answer adds new information

### Automated Testing Checklist

```elixir
# Test that prompts generate expected structure
test "explain prompt includes anti-repetition footer" do
  result = Prompts.explain("context", "topic")
  assert result =~ "Do not repeat or merely rephrase"
  assert result =~ "EXTEND BEYOND"
end

test "frame_context wraps content correctly" do
  result = Prompts.explain("test context", "topic")
  assert result =~ "### Foundation"
  assert result =~ "already been explored"
  assert result =~ "test context"
end

test "all prompts use additive language" do
  prompts = [
    Prompts.explain("ctx", "topic"),
    Prompts.thesis("ctx", "claim"),
    Prompts.antithesis("ctx", "claim"),
    Prompts.related_ideas("ctx", "idea"),
    Prompts.deep_dive("ctx", "topic")
  ]
  
  for prompt <- prompts do
    # Should have either "ADD", "NEW", or "BEYOND"
    assert prompt =~ ~r/(ADD|NEW|BEYOND)/i
  end
end
```

### What to Look For

✅ **Good Signs:**
- Responses add specific examples not in context
- New reasoning/frameworks appear
- Different angles or perspectives emerge
- Responses feel like they're building on vs repeating

❌ **Bad Signs:**
- Responses restate what's in context
- Same examples/reasoning as parent nodes
- Feels like summary rather than extension
- No new information value

---

## Performance Considerations

### Context Length
- Current: ~5000 token limit in `Vertex.build_context/3`
- New framing adds ~50 tokens per prompt
- Net impact: Negligible (<1% of context budget)

### Model Behavior
- More explicit instructions may slightly increase response time
- Trade-off: Better quality (less repetition) vs slightly longer responses
- Expected: Minimal impact, likely improved user satisfaction

---

## Rollback Plan

If the changes cause issues:

```bash
# Revert prompts.ex
git checkout HEAD~1 lib/dialectic/responses/prompts.ex

# Revert system prompts
git checkout HEAD~1 lib/dialectic/responses/prompts_structured.ex
git checkout HEAD~1 lib/dialectic/responses/prompts_creative.ex

# Recompile
mix compile
```

---

## Future Improvements (Not Implemented Yet)

### Priority 2: Context Enhancements
```elixir
# Add node titles to context
def add_node_context(node_id, graph) do
  case :digraph.vertex(graph, node_id) do
    {_id, dat} -> 
      title = extract_title(dat.content)
      "[#{title}]\n#{dat.content}"
    _ -> ""
  end
end
```

### Priority 3: Context Summarization
For very long context chains, consider:
- Summarizing older ancestors
- Keeping only recent nodes in full
- Structured metadata (dates, authors, node types)

### Priority 4: A/B Testing
Test variations:
- Different footer text
- Different framing language
- With/without bullet points
- Shorter vs longer instructions

---

## Metrics to Monitor

After deployment, track:

1. **User Feedback**
   - Do users report less repetition?
   - Are responses more valuable?
   - Any confusion from new framing?

2. **Usage Patterns**
   - Regeneration rate (users asking for new versions)
   - Graph depth (do users continue exploring deeper?)
   - Branching frequency (more/less thesis-antithesis?)

3. **Quality Indicators**
   - Response length (should stay ~same)
   - Unique vocabulary (should increase slightly)
   - Context relevance (should maintain)

---

## Summary

**What Changed:**
- All 8 prompt templates rewritten with additive language
- System prompts updated with anti-repetition guidance
- Context framed as "Foundation" (already covered)
- Explicit instructions to avoid repetition

**Expected Impact:**
- ✅ Reduced repetition across all node types
- ✅ More valuable, additive responses
- ✅ Better user experience in deep explorations
- ✅ Clearer guidance for LLMs

**Risk Level:** Low
- Changes are prompt-only (no logic/data changes)
- Easy to revert if issues arise
- Backwards compatible

**Next Steps:**
1. Deploy to production
2. Monitor for 1 week
3. Gather user feedback
4. Iterate based on results
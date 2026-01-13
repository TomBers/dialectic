# Minimal Context Simplification

## Overview

This document explains the simplification of the "minimal context" feature for text selection explanations, moving from a binary threshold approach to a consistent "always include with truncation" approach.

## Problem with Previous Implementation

### The 500-Character Threshold Issue

The original implementation used a binary threshold for including context:

```elixir
# Old approach
if String.length(context_text) < 500 do
  # Include context with permissive framing
  """
  ### Foundation (for reference)
  #{context_text}
  ↑ Background context. You may reference this but are not bound by it.
  """
else
  # Omit context entirely
  ""
end
```

### Why This Was Problematic

**1. Inconsistent User Experience**
- Selecting from a 499-char answer: Got context for grounding
- Selecting from a 500-char answer: No context at all
- Single character difference caused drastically different behavior

**2. Counterintuitive Results**
- Longer, more detailed answers (which are often MORE relevant) gave LESS context
- Users selecting text FROM a specific node lost connection to that node
- The source of the selection is inherently relevant context

**3. Binary Cutoff Was Arbitrary**
- Why 500 characters specifically?
- No gradual degradation - it's all or nothing
- Edge cases (499 vs 500 chars) behaved very differently

**4. Wrong Problem Being Solved**
- Original issue: LLM too constrained by full parent chain when explaining selections
- Real solution: 
  - Reduce context from "full chain" to "immediate parent" ✓
  - Change prompt to encourage divergence ✓
  - Omit context entirely? ✗ (unnecessary and problematic)

## New Simplified Implementation

### Always Include with Smart Truncation

```elixir
# New approach
@minimal_context_max_length 1000

defp frame_minimal_context(context_text) do
  # Always include immediate parent context, truncating if needed
  truncated_context =
    if String.length(context_text) > @minimal_context_max_length do
      String.slice(context_text, 0, @minimal_context_max_length) <>
        "\n\n[... truncated for brevity ...]"
    else
      context_text
    end

  """
  ### Foundation (for reference)
  
  ```text
  #{truncated_context}
  ```
  
  ↑ Background context. You may reference this but are not bound by it.
  """
end
```

### Key Principles

1. **Always Include Immediate Parent**
   - Consistent behavior regardless of parent length
   - Users always get grounding from the source node
   - The node they're reading when making selection is relevant

2. **Smart Truncation**
   - If parent > 1000 chars, include first 1000 + truncation indicator
   - Preserves beginning (often contains thesis/summary)
   - Clear indication that content was truncated

3. **Rely on Prompt for Divergence**
   - The prompt says "NEW exploration starting point"
   - Explicitly encourages diverging from original discussion
   - This is the key mechanism, not context omission

## Behavior Comparison

### Old Implementation

| Parent Length | Context Included | Behavior |
|---------------|-----------------|----------|
| 499 chars | ✓ Full context | Grounded exploration |
| 500 chars | ✗ No context | Ungrounded exploration |
| 1000 chars | ✗ No context | Ungrounded exploration |

**Problem:** Binary threshold creates inconsistent experience

### New Implementation

| Parent Length | Context Included | Behavior |
|---------------|-----------------|----------|
| 499 chars | ✓ Full context | Consistently grounded |
| 500 chars | ✓ Full context | Consistently grounded |
| 1000 chars | ✓ Full context | Consistently grounded |
| 1500 chars | ✓ Truncated (first 1000) | Grounded with summary |

**Benefit:** Consistent, predictable behavior for all cases

## Real-World Examples

### Example 1: Short Parent

**User is reading:**
```
Quantum mechanics describes nature at atomic scales. Key concepts 
include wave-particle duality and uncertainty principle.
```

**User selects:** "uncertainty principle"

**Context sent to LLM:**
- ✓ Full parent content (< 1000 chars)
- Prompt: "NEW exploration starting point... may diverge..."

**Result:** Explores uncertainty principle deeply, can branch into philosophy, epistemology, etc., but grounded in the quantum mechanics context.

### Example 2: Long Parent

**User is reading:**
```
[A 2000-character detailed explanation of quantum mechanics covering
historical development, mathematical formalism, Copenhagen interpretation,
many-worlds interpretation, experimental evidence, philosophical implications,
practical applications, current research directions...]
```

**User selects:** "Copenhagen interpretation"

**Old behavior (500-char threshold):**
- ✗ No context at all
- Explores Copenhagen interpretation in vacuum
- Lost connection to the detailed quantum mechanics discussion

**New behavior (1000-char truncation):**
- ✓ First 1000 chars of parent + "[... truncated for brevity ...]"
- Explores Copenhagen interpretation with grounding
- Maintains connection to source while allowing divergence

## Why This Works Better

### 1. Consistent Grounding
Users selecting text from a node expect that node to be relevant. Always including it (even truncated) respects this expectation.

### 2. Predictable Behavior
No magic thresholds or surprising omissions. Users get consistent behavior regardless of parent length.

### 3. Beginning Contains Key Info
Most well-written responses front-load key information. The first 1000 characters typically contain:
- Main thesis
- Core definitions
- Primary context

Truncating from the end preserves the most important grounding.

### 4. Prompt Does Heavy Lifting
The real innovation is the prompt change:
- "Treat this as a NEW exploration starting point"
- "May diverge from the original discussion"

This explicit permission to diverge is more effective than omitting context.

### 5. Simpler Logic
Fewer edge cases, no binary cutoffs, easier to understand and maintain.

## Technical Details

### Module Attribute

```elixir
# Maximum character length for context in minimal context prompts.
# Longer contexts are truncated to this length to keep prompts focused
# while still providing grounding from the immediate parent node.
# This ensures consistent behavior regardless of parent node length.
@minimal_context_max_length 1000
```

### Truncation Logic

- **Under 1000 chars:** Include full context
- **Over 1000 chars:** Include first 1000 + "\n\n[... truncated for brevity ...]"
- **Always:** Include Foundation section with permissive framing

### Test Coverage

New tests verify:
- Short contexts included fully
- Long contexts truncated with indicator
- Edge cases (999 vs 1001 chars) handled correctly
- Beginning of long contexts preserved
- Truncation indicator present when needed
- Markdown formatting preserved

## Migration Impact

### Breaking Changes
None. This is an internal improvement that doesn't change the API.

### User-Visible Changes
- **Before:** Selecting from long answers gave no context
- **After:** Selecting from long answers gives truncated context

This is a **quality improvement** - users get more consistent, helpful behavior.

### Performance Impact
Minimal. Truncation is a simple string slice operation. No performance concerns.

## Design Philosophy

This change aligns with several principles:

1. **Principle of Least Surprise**
   - Users expect the source node to be relevant
   - Always including it (even truncated) matches this expectation

2. **Progressive Enhancement**
   - Start with grounding (context)
   - Add freedom (divergence prompt)
   - Don't remove foundation entirely

3. **Avoid Binary Thresholds**
   - Gradual degradation (truncation) better than cliff (omission)
   - No "magic numbers" that cause surprising behavior changes

4. **Trust the Prompt**
   - The prompt explicitly encourages divergence
   - Don't need to remove context to enable exploration
   - LLMs are good at following instructions

## Future Considerations

### Potential Enhancements

1. **Configurable Max Length**
   - Could make `@minimal_context_max_length` configurable per deployment
   - Allow tuning based on model capabilities and use patterns

2. **Smart Truncation**
   - Could truncate at sentence boundaries rather than character count
   - Could use summarization instead of simple truncation

3. **User Preference**
   - Could allow users to configure context behavior
   - Some users might want even more context, others less

4. **Context Visualization**
   - Could show truncation indicator in UI
   - Let users expand to see full parent if desired

### Not Recommended

- **Going back to binary threshold:** The problems are well-documented
- **Complete context omission:** Users need grounding from source
- **Very short truncation:** 1000 chars seems like good balance

## Conclusion

The simplification from "binary threshold with omission" to "always include with truncation" provides:

✅ **Consistent behavior** across all parent lengths
✅ **Predictable user experience** without surprises
✅ **Maintained grounding** from source node
✅ **Simpler implementation** with fewer edge cases
✅ **Better user outcomes** through reliable context

The prompt change ("NEW exploration starting point") is the key innovation for enabling divergent exploration. Context reduction (full chain → immediate parent) helps avoid over-constraint. But complete context omission was solving the wrong problem and created more issues than it solved.

This approach strikes the right balance: provide grounding, enable divergence, stay consistent.
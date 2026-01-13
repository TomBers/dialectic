# Text Selection Exploration Fix

## Problem

When users selected text and clicked "Explain", the LLM response was too constrained by the original graph context. Instead of treating the selected text as a new exploration starting point, it would:

1. Pull in the entire parent chain context (up to 5000 tokens)
2. Try to "extend beyond" the foundation while staying tied to the original topic
3. Keep responses closely related to the original graph subject

This prevented users from branching off in genuinely new directions when they found an interesting phrase or concept to explore.

**Example:**
- Original graph: "What is quantum mechanics?"
- User selects text: "observer effect"
- Expected: Deep exploration of observer effect, potentially moving into philosophy, psychology, or other fields
- Actual: Explanation of observer effect strictly within quantum mechanics context

## Solution

### 1. Minimal Context for Text Selections

Created a new function `gen_response_minimal_context/4` in `LlmInterface` that:
- Uses **only the immediate parent node** as context (not the entire chain)
- Allows the context to be empty if the parent doesn't exist
- Treats the selected text as a **new exploration topic**

```elixir
def gen_response_minimal_context(node, child, graph_id, live_view_topic) do
  # Build minimal context - only the immediate parent node
  context =
    case node.parents do
      [parent_id | _] ->
        case GraphManager.find_node_by_id(graph_id, parent_id) do
          nil -> ""
          parent -> parent.content || ""
        end
      _ -> ""
    end
  
  # Extract the selected text from the question node
  selection =
    node.content
    |> String.replace(~r/^Please explain:\s*/, "")
    |> String.trim()
  
  instruction = Prompts.selection(context, selection)
  # ...
end
```

### 2. Updated Selection Prompt

Modified the `selection/2` prompt in `Prompts` module to:
- Use `frame_minimal_context/1` instead of `frame_context/1`
- Skip context entirely if it's longer than 500 characters
- Frame the task as exploring a **NEW starting point**, not extending existing discussion
- Explicitly encourage divergence from the original topic

**Key changes:**
```elixir
defp frame_minimal_context(context_text) do
  # Always include immediate parent context, truncating if needed
  truncated_context =
    if String.length(context_text) > 1000 do
      String.slice(context_text, 0, 1000) <>
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

**Philosophy:**
- **Always include immediate parent** as Foundation (the node where selection came from)
- **Smart truncation** if parent is > 1000 chars (preserves beginning, indicates truncation)
- **Permissive framing** tells LLM the context is for reference, not constraint
- **Prompt encourages divergence** - treat as "NEW exploration starting point"

This ensures consistent behavior: users always get grounding from the source node, while the prompt explicitly encourages exploring in new directions.

**New instruction:**
```
A specific phrase was highlighted: **[selected text]**

**Your task:** Treat this as a NEW exploration starting point. Explain this concept in depth, opening up new directions:
- What is this concept and why does it matter?
- Provide concrete examples or applications
- Explore different perspectives or frameworks
- Identify related concepts or questions worth exploring
- Consider implications, edge cases, or nuances

While the Foundation provides context, feel free to explore this concept in directions that may diverge from the original discussion.
```

### 3. Explicit Parameter Detection

Updated `ask_and_answer/3` to accept an explicit `minimal_context` option:
- Frontend passes `prefix: "explain"` for text selections
- Backend uses this prefix to set `minimal_context: true`
- Uses minimal context flow for selections
- Uses full context for regular questions

```elixir
def ask_and_answer({graph_id, node, user, live_view_topic}, question_text, opts \\ []) do
  minimal_context = Keyword.get(opts, :minimal_context, false)
  
  # ...
  
  fn n ->
    if minimal_context do
      LlmInterface.gen_response_minimal_context(question_node, n, graph_id, live_view_topic)
    else
      LlmInterface.gen_response(question_node, n, graph_id, live_view_topic)
    end
  end
end
```

In `graph_live.ex`:
```elixir
def handle_event("reply-and-answer", %{"vertex" => %{"content" => answer}, "prefix" => prefix}, socket) do
  minimal_context = prefix == "explain"
  
  GraphActions.ask_and_answer(
    graph_action_params(socket, socket.assigns.node),
    answer,
    minimal_context: minimal_context
  )
end
```

## Behavior Comparison

### Before (Constrained - Full Parent Chain)

**Graph:** "What is quantum mechanics?"
**Selected text:** "wave function collapse"
**Context sent to LLM:** Full parent chain (origin → answer → explanation → ...)
**Prompt:** "Extend beyond what's in the Foundation..."
**Result:** Explanation stays within quantum mechanics, references existing discussion

### After (Expansive - Immediate Parent Only)

**Graph:** "What is quantum mechanics?"
**Selected text:** "wave function collapse"
**Frontend:** Sends `prefix: "explain"`
**Backend:** Sets `minimal_context: true`
**Context sent to LLM:** Only immediate parent node (truncated if > 1000 chars)
**Prompt:** "Treat this as a NEW exploration starting point..."
**Result:** Can explore philosophical implications, consciousness debates, measurement problem, related fields, etc.

**Key difference:** The immediate parent provides grounding (what was the user reading?), but the prompt explicitly encourages divergence.

## Examples

Now when users select text, they can:

✓ **Diverge into new fields:**
- Select "consciousness" from a neuroscience discussion → explore philosophy of mind
- The neuroscience answer provides grounding, but LLM is encouraged to explore broadly

✓ **Explore related concepts freely:**
- Select "entropy" from a physics discussion → explore thermodynamics, information theory, or even social systems
- The physics context is present for reference, but exploration isn't constrained by it

✓ **Go deeper without constraint:**
- Select technical term → get comprehensive explanation grounded in source but not bound by it

✓ **Consistent behavior:**
- Short parent (< 1000 chars): Full context included
- Long parent (> 1000 chars): First 1000 chars + truncation indicator
- Always have Foundation section for grounding

## Files Changed

1. **`lib/dialectic/responses/llm_interface.ex`**
   - Added `gen_response_minimal_context/4` function

2. **`lib/dialectic/responses/prompts.ex`**
   - Added `frame_minimal_context/1` helper with smart truncation
   - Always includes immediate parent (truncated if > 1000 chars)
   - Updated `selection/2` prompt to encourage divergence

3. **`lib/dialectic/graph/graph_actions.ex`**
   - Updated `ask_and_answer/3` to accept explicit `minimal_context` option

4. **`lib/dialectic_web/live/graph_live.ex`**
   - Updated `handle_event("reply-and-answer", ...)` to use `prefix` parameter

## Testing

To test the fix:

1. Create a graph on any topic (e.g., "What is machine learning?")
2. Generate some nodes with explanations
3. Select a specific phrase or concept from one of the answers
4. Click "Explain" or press the ask button
5. Observe that the response:
   - Treats the selected text as its own topic
   - May diverge from the original graph subject
   - Explores the concept in depth without being constrained by prior context

## Design Philosophy

This change aligns with the core vision of Dialectic as a tool for **exploratory thinking**:

- **Consistent grounding:** Always include immediate parent for context (what was the user reading?)
- **Smart limits:** Truncate long contexts to keep prompts focused, but never omit entirely
- **Freedom to diverge:** Prompt explicitly encourages exploration in new directions
- **Bottom-up exploration:** Selected text becomes a new seed for branching discussions
- **No binary thresholds:** Avoid "all-or-nothing" behavior based on arbitrary character counts
- **Explicit signaling:** Frontend explicitly indicates when minimal context is desired, avoiding brittle string matching

The original behavior (full context, "extend beyond") is preserved for regular questions and node explanations, where maintaining coherence with the parent discussion is valuable.

## Why This Approach?

**Previous approach had a 500-char threshold:**
- Parent < 500 chars: Include context
- Parent ≥ 500 chars: Omit context entirely

**Problems:**
- Binary cutoff created inconsistent behavior
- Longer, detailed answers gave NO context (counterintuitive)
- User selecting from a specific answer inherently makes that answer relevant

**Current approach:**
- **Always include immediate parent** (consistency)
- **Truncate if needed** (keeps prompts manageable)
- **Rely on prompt for divergence** (the key innovation)

The prompt change ("NEW exploration starting point") is the primary mechanism for encouraging divergence. Context reduction (full chain → immediate parent) helps, but complete context omission was unnecessary.
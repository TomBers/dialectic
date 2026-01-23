# Ask About Selection Action

## Overview

A dedicated action for asking questions about specific text selections in the graph. This provides a clean separation between general questions (`reply-and-answer`) and questions about specific highlighted text.

## The Problem

Previously, text selection questions were handled by the `reply-and-answer` event with a `highlight_context` parameter. This caused issues:

1. **Protocol Error**: Tried to pass entire `Vertex` structs where strings were expected
2. **Mixed Responsibilities**: Single event handler trying to do too many things
3. **Complex Data Flow**: Context being passed through multiple layers with unclear semantics

## The Solution

Create a dedicated `ask-about-selection` event and action that:

1. Has a clear, specific purpose
2. Uses simple, explicit parameters
3. Stores selection context properly as metadata
4. Always uses minimal context mode (focused on the selection)

## Data Flow

### Frontend (JavaScript)

```javascript
// When user types a question about selected text
this.pushEvent("ask-about-selection", {
  question: "What does this mean?\n\nRegarding: \"speculative bioengineered\"",
  selected_text: "speculative bioengineered"
});
```

### Backend (Phoenix LiveView)

```elixir
def handle_event(
  "ask-about-selection",
  %{"question" => question, "selected_text" => selected_text},
  socket
) do
  update_graph(
    socket,
    GraphActions.ask_about_selection(
      graph_action_params(socket, socket.assigns.node),
      question,
      selected_text
    ),
    "answer"
  )
end
```

### Graph Actions

```elixir
def ask_about_selection({graph_id, node, user, live_view_topic}, question_text, selected_text) do
  # 1. Create question node
  question_node = GraphManager.add_child(graph_id, [node], fn _ -> question_text end, "question", user)
  
  # 2. Store selected text as metadata
  GraphManager.update_vertex_fields(graph_id, question_node.id, %{
    source_highlight_id: selected_text
  })
  
  # 3. Generate answer with minimal context
  answer_node = GraphManager.add_child(
    graph_id,
    [question_node],
    fn n -> LlmInterface.gen_response_minimal_context(question_node, n, graph_id, live_view_topic) end,
    "answer",
    user
  )
  
  {nil, answer_node}
end
```

## Key Features

### 1. Simple Parameters

- `question`: The user's question (includes "Regarding: ..." context)
- `selected_text`: The exact text that was selected

No complex vertex structures or optional parameters.

### 2. Metadata Storage

The selected text is stored in `source_highlight_id` field on the question vertex:

```elixir
%Vertex{
  id: "3",
  content: "What does this mean?\n\nRegarding: \"speculative bioengineered\"",
  class: "question",
  source_highlight_id: "speculative bioengineered",  # ← Stored here
  ...
}
```

### 3. Minimal Context Mode

Always uses `gen_response_minimal_context` because:
- The question already includes the selected text
- We want focused answers about the specific selection
- Don't need full conversation history

### 4. New Graph Manager Function

Added `update_vertex_fields/3` to cleanly update vertex metadata:

```elixir
def update_vertex_fields(path, node_id, fields) do
  GenServer.call(via_tuple(path), {:update_vertex_fields, {node_id, fields}})
end

def handle_call({:update_vertex_fields, {node_id, fields}}, _from, {graph_struct, graph}) do
  case :digraph.vertex(graph, node_id) do
    {_id, vertex} ->
      updated_vertex = Map.merge(vertex, fields)
      :digraph.add_vertex(graph, node_id, updated_vertex)
      {:reply, updated_vertex, {graph_struct, graph}}
    false ->
      {:reply, nil, {graph_struct, graph}}
  end
end
```

## Comparison with Other Actions

### `reply-and-answer` (General Questions)

```javascript
// Used for: Regular follow-up questions
this.pushEvent("reply-and-answer", {
  vertex: { content: "What are the implications?" }
});
```

- No text selection involved
- Full context mode (knows entire conversation)
- General questions about the current node

### `reply-and-answer` with `prefix: "explain"` (Quick Explain)

```javascript
// Used for: Quick "explain this selection" action
this.pushEvent("reply-and-answer", {
  vertex: { content: "Please explain: speculative bioengineered" },
  prefix: "explain"
});
```

- Minimal context mode
- Pre-formatted question
- No metadata storage
- One-click action

### `ask-about-selection` (Custom Selection Question)

```javascript
// Used for: User's custom question about selection
this.pushEvent("ask-about-selection", {
  question: "What does this mean?\n\nRegarding: \"speculative bioengineered\"",
  selected_text: "speculative bioengineered"
});
```

- Minimal context mode
- User's custom question
- Stores selection in metadata
- Typed in input field

## Files Changed

1. **`lib/dialectic/graph/graph_actions.ex`**
   - Added `ask_about_selection/3` function
   - Removed `highlight_context` logic from `ask_and_answer`

2. **`lib/dialectic/graph/graph_manager.ex`**
   - Added `update_vertex_fields/3` function
   - Added `handle_call({:update_vertex_fields, ...})` handler

3. **`lib/dialectic_web/live/graph_live.ex`**
   - Added `handle_event("ask-about-selection", ...)` handler
   - Removed `highlight_context` parameter from `reply-and-answer` handlers

4. **`assets/js/text_selection_hook.js`**
   - Changed custom question submit to use `ask-about-selection` event
   - Removed `highlight_context` from explain button event

## Benefits

✅ **Clear separation of concerns** - Each action has one purpose  
✅ **Type safety** - No more protocol errors with vertex structs  
✅ **Better maintainability** - Easy to understand what each action does  
✅ **Simpler code** - No complex conditional logic in single handler  
✅ **Explicit parameters** - Clear what data is needed for each action  
✅ **Proper metadata storage** - Selection context stored correctly  

## Testing

```elixir
# In graph_live_test.exs
test "ask-about-selection creates question with selection metadata", %{view: view} do
  # Select text and ask a question
  render_click(view, "ask-about-selection", %{
    question: "What does this mean?\n\nRegarding: \"test text\"",
    selected_text: "test text"
  })
  
  # Verify question node was created
  assert has_element?(view, "#node-content", "What does this mean?")
  
  # Verify selection is stored in metadata
  # (would need to check the graph structure directly)
end
```

## Future Enhancements

- Add UI indicator when a question was asked about a selection
- Link question nodes back to the specific text location
- Show selection context in the question node UI
- Allow clicking a question to highlight the original selection
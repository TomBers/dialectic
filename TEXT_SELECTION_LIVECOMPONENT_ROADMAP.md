# Text Selection LiveComponent Refactor Roadmap

## Current State

The text selection panel is currently implemented using pure JavaScript with manual DOM manipulation and event handling. While functional, it has several limitations:

### Problems with Current Approach

1. **Manual Event Management**
   - Event listeners added/removed manually in JS
   - Risk of memory leaks if not cleaned up properly
   - Hard to debug when events don't fire
   - No automatic Enter key handling

2. **State Synchronization Issues**
   - JavaScript state (selected text, position) not synced with server
   - Panel doesn't update when user selects different text while panel is open
   - No way to update panel from server-side events

3. **Form Handling**
   - Manual form submission via JavaScript
   - Manual Enter key detection and handling
   - No Phoenix form helpers or changesets
   - No server-side validation

4. **Testing Challenges**
   - Hard to test JavaScript event handling
   - Can't use Phoenix LiveView testing tools
   - Browser-dependent behavior

5. **Code Duplication**
   - Similar panel HTML in 3 templates (node_comp.ex, linear_graph_live.html.heex, modal_comp.ex)
   - Behavior implemented multiple times
   - Changes must be made in multiple places

## Proposed Solution: LiveComponent

Convert the selection actions panel to a proper Phoenix LiveComponent with server-side state management.

### Architecture

```
┌─────────────────────────────────────┐
│   ParentLiveView (GraphLive)        │
│                                     │
│   handles:                          │
│   - Text selection events from JS   │
│   - Spawns/updates component        │
│   - Processes actions (explain,     │
│     highlight, ask)                 │
└──────────────┬──────────────────────┘
               │
               │ sends update
               ▼
┌─────────────────────────────────────┐
│   SelectionActionsComponent         │
│   (LiveComponent)                   │
│                                     │
│   state:                            │
│   - selected_text                   │
│   - position (top, left)            │
│   - visible                         │
│   - question (form field)           │
│                                     │
│   renders:                          │
│   - Selected text display           │
│   - Action buttons                  │
│   - Form with proper phx-submit     │
└─────────────────────────────────────┘
```

### Benefits

#### 1. Automatic Form Handling
```elixir
# Phoenix handles Enter key automatically
<.form for={@form} phx-submit="ask_question" phx-target={@myself}>
  <input type="text" name="question" />
  <button type="submit">Ask</button>
</.form>
```

#### 2. Server-Side State
```elixir
# Component state is managed on server
socket
|> assign(:selected_text, "bioengineered")
|> assign(:visible, true)
|> assign(:position, %{top: 100, left: 200})
```

#### 3. Reactive Updates
```elixir
# Parent can update component when selection changes
send_update(SelectionActionsComponent,
  id: "selection-actions",
  selected_text: new_text,
  position: new_position
)
```

#### 4. Clean Event Handling
```elixir
def handle_event("close", _params, socket) do
  {:noreply, assign(socket, visible: false)}
end

def handle_event("explain", _params, socket) do
  # Send message to parent
  send(self(), {:selection_action, :explain, socket.assigns.selected_text})
  {:noreply, assign(socket, visible: false)}
end
```

#### 5. Testable
```elixir
test "submitting question closes panel and creates node" do
  {:ok, view, _html} = live(conn, "/graph/#{graph_id}")
  
  # Show selection panel
  render_hook(view, "show-selection-actions", %{
    selected_text: "test",
    position: %{top: 0, left: 0}
  })
  
  # Submit question
  view
  |> element("#selection-actions form")
  |> render_submit(%{question: "What is this?"})
  
  assert has_element?(view, "#node-content", "What is this?")
end
```

## Implementation Plan

### Phase 1: Create LiveComponent (2-3 hours)

1. **Create `SelectionActionsComponent`**
   - File: `lib/dialectic_web/live/selection_actions_comp.ex`
   - State: selected_text, position, visible, question
   - Events: close, explain, highlight, ask_question

2. **Update JavaScript Hook**
   - Simplify to just detect selection and send event
   - Remove all manual DOM manipulation
   - Keep only: selection detection, position calculation

3. **Add to Parent LiveView**
   - Mount component in render
   - Handle `show-selection-actions` event from JS
   - Handle messages from component (action requests)

### Phase 2: Update Templates (1 hour)

1. **Remove hardcoded panels**
   - Remove from node_comp.ex
   - Remove from linear_graph_live.html.heex
   - Remove from modal_comp.ex

2. **Add component rendering**
   ```heex
   <.live_component
     module={SelectionActionsComponent}
     id="selection-actions"
     selected_text={@selection_text}
     position={@selection_position}
     visible={@selection_visible}
     node_id={@selection_node_id}
   />
   ```

### Phase 3: Handle Actions (1 hour)

1. **Explain action**
   ```elixir
   def handle_info({:selection_action, :explain, text}, socket) do
     update_graph(socket, GraphActions.ask_and_answer(...))
   end
   ```

2. **Highlight action**
   - Keep using JS createHighlight function
   - Or move to server-side

3. **Ask question action**
   ```elixir
   def handle_info({:selection_action, :ask, question, text}, socket) do
     update_graph(socket, GraphActions.ask_about_selection(...))
   end
   ```

### Phase 4: Testing (1-2 hours)

1. **Component tests**
   - Test rendering
   - Test button clicks
   - Test form submission

2. **Integration tests**
   - Test full flow from selection to node creation
   - Test multiple selections
   - Test in all views (node, linear, modal)

## Code Examples

### SelectionActionsComponent

```elixir
defmodule DialecticWeb.SelectionActionsComponent do
  use DialecticWeb, :live_component

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, visible: false)}
  end

  def handle_event("explain", _params, socket) do
    send(self(), {:selection_action, :explain, socket.assigns.selected_text})
    {:noreply, assign(socket, visible: false)}
  end

  def handle_event("submit_question", %{"question" => q}, socket) do
    if String.trim(q) != "" do
      send(self(), {:selection_action, :ask, q, socket.assigns.selected_text})
      {:noreply, assign(socket, visible: false, question: "")}
    else
      {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class={["selection-panel", if(@visible, do: "", else: "hidden")]}
         style={"top: #{@position.top}px; left: #{@position.left}px"}>
      
      <button phx-click="close" phx-target={@myself}>X</button>
      
      <div class="selected-text">{@selected_text}</div>
      
      <button phx-click="explain" phx-target={@myself}>Explain</button>
      <button phx-click="highlight" phx-target={@myself}>Highlight</button>
      
      <.form for={%{}} phx-submit="submit_question" phx-target={@myself}>
        <input type="text" name="question" placeholder="Ask a question..." />
        <button type="submit">Ask</button>
      </.form>
    </div>
    """
  end
end
```

### Simplified JavaScript

```javascript
handleSelection(event) {
  // Only detect selection and calculate position
  const selection = window.getSelection();
  const selectedText = selection.toString().trim();
  
  if (!selectedText) return;
  
  const range = selection.getRangeAt(0);
  const rect = range.getBoundingClientRect();
  
  // Send to server - let LiveComponent handle the rest
  this.pushEvent("show-selection-actions", {
    selected_text: selectedText,
    position: {
      top: rect.bottom + 8,
      left: rect.left + (rect.width / 2)
    },
    node_id: this.nodeId
  });
}
```

### Parent LiveView

```elixir
def handle_event("show-selection-actions", params, socket) do
  {:noreply,
   socket
   |> assign(:selection_visible, true)
   |> assign(:selection_text, params["selected_text"])
   |> assign(:selection_position, params["position"])
   |> assign(:selection_node_id, params["node_id"])}
end

def handle_info({:selection_action, :explain, text}, socket) do
  update_graph(
    socket,
    GraphActions.ask_and_answer(
      graph_action_params(socket, socket.assigns.node),
      "Please explain: #{text}",
      minimal_context: true
    ),
    "answer"
  )
end

def handle_info({:selection_action, :ask, question, text}, socket) do
  update_graph(
    socket,
    GraphActions.ask_about_selection(
      graph_action_params(socket, socket.assigns.node),
      "#{question}\n\nRegarding: \"#{text}\"",
      text
    ),
    "answer"
  )
end
```

## Migration Strategy

### Option A: Big Bang (Faster, Riskier)
1. Implement complete LiveComponent
2. Replace all at once
3. Test thoroughly
4. Deploy

**Time:** 5-7 hours
**Risk:** High (might break things)
**Benefit:** Clean break, all benefits immediately

### Option B: Gradual (Slower, Safer)
1. Implement LiveComponent
2. Add feature flag
3. Test in one view first (node view)
4. Roll out to linear view
5. Roll out to modal view
6. Remove old code

**Time:** 8-10 hours
**Risk:** Low (can rollback easily)
**Benefit:** Safe, easier to debug issues

## Recommendation

**Use Option B (Gradual Migration)** because:
- Text selection is a core feature
- Multiple views use it
- Easy to test incrementally
- Can gather user feedback early
- Low risk of breaking production

## Success Metrics

After refactor, we should have:

✅ **Enter key works automatically** (Phoenix form handling)
✅ **Panel updates with new selections** (reactive state)
✅ **Single source of truth** (one component, not 3 templates)
✅ **Testable** (LiveView testing tools)
✅ **Maintainable** (less JS, more Elixir)
✅ **Debuggable** (server-side state, logs)
✅ **Type-safe** (Elixir compiler catches errors)

## Timeline

- **Phase 1:** 2-3 hours
- **Phase 2:** 1 hour
- **Phase 3:** 1 hour
- **Phase 4:** 1-2 hours
- **Buffer:** 1-2 hours

**Total:** 6-9 hours of focused work

## Next Steps

1. Review this roadmap
2. Decide on migration strategy (A or B)
3. Create feature branch
4. Implement Phase 1
5. Test thoroughly
6. Get feedback
7. Continue with remaining phases

## References

- Phoenix LiveComponent docs: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html
- Phoenix.HTML.Form docs: https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html
- LiveView Testing: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html

## Notes

- Keep the highlight creation in JS (it's working well)
- Position calculation can stay in JS (simpler)
- Only UI/form handling moves to LiveComponent
- Maintains separation: JS for DOM, Elixir for logic
# Combine Mode Documentation

## Overview

The combine mode feature allows users to select two nodes from the graph and create a synthesis between them. This document describes the improved UX implementation that replaces the old modal-based selection with an interactive, presentation-mode-style interface.

## User Experience

### Old Flow (Deprecated)
1. User clicks a node
2. User clicks "Combine" button
3. A modal appears with a list of all other nodes
4. User selects a node from the list
5. Synthesis is created

**Problems:**
- Required clicking a node first
- Modal list could be long and hard to navigate
- No visual feedback on the graph
- Unclear which nodes were being combined

### New Flow (Current)
1. User clicks "Combine" button (no pre-selection needed)
2. Combine setup panel opens on the right side
3. User clicks two nodes directly on the graph
4. Selected nodes are highlighted with violet glow
5. Panel shows both selected nodes with details
6. User clicks "Create Synthesis" button
7. Panel automatically closes and synthesis is created

**Benefits:**
- More intuitive - select nodes visually on the graph
- Clear visual feedback with node highlighting
- Panel shows what you're combining before executing
- Panel automatically closes on execution for seamless workflow
- Similar UX to presentation mode (familiar pattern)
- Can easily deselect nodes if you change your mind

## Implementation Details

### Frontend Components

#### 1. CombineSetupComp (`lib/dialectic_web/live/combine_setup_comp.ex`)
A new LiveComponent that renders the combine setup panel as a right-side drawer.

**Key Features:**
- Shows instructions to click two nodes
- Displays selected nodes with their titles and types
- Shows numbered badges (1, 2) for selected nodes
- "Create Synthesis" button (only enabled when 2 nodes selected)
  - Automatically closes the drawer when clicked (using JS.dispatch to toggle panel)
  - Triggers `execute_combine` event on the server
- "Clear selection" button
- Close button to exit combine mode

#### 2. Graph Hook Events (`assets/js/graph_hook.js`)
Added event handlers for node highlighting:

```javascript
// Highlight selected nodes in combine mode
this.handleEvent("combine_highlight_nodes", ({ ids }) => {
  // Adds 'combine-selected' class to nodes
});

// Clear highlights when exiting combine mode
this.handleEvent("combine_clear_highlights", () => {
  // Removes 'combine-selected' class
});
```

#### 3. Graph Styling (`assets/js/graph_style.js`)
Added visual styling for selected nodes:

```javascript
{
  selector: "node.combine-selected",
  style: {
    "underlay-color": "#8b5cf6", // violet-500
    "underlay-opacity": 0.2,
    "underlay-padding": isCompact ? 10 : 14,
    "border-width": isCompact ? 3 : 4,
    "border-color": "#8b5cf6",
    // ... transitions
  }
}
```

### Backend Implementation

#### 1. State Management
Added two new assigns to `graph_live.ex`:
- `combine_mode: :off | :setup` - Tracks if combine mode is active
- `combine_selected_nodes: []` - List of selected node structs (max 2)

#### 2. Event Handlers

##### `handle_event("node_combine", _params, socket)`
Toggles combine setup mode on/off. If already in setup mode, closes it and clears selection.

##### `handle_event("node_clicked", %{"id" => id}, socket)` - Enhanced
Modified to handle three different modes using `cond`:
1. **Combine mode** - Toggle node in selection (max 2)
2. **Presentation mode** - Toggle node in slide deck
3. **Normal mode** - Navigate to node

##### `handle_event("execute_combine", _params, socket)`
Executes the combine action when user has selected exactly 2 nodes:
```elixir
case socket.assigns.combine_selected_nodes do
  [node1, node2] ->
    node = GraphActions.combine(
      graph_action_params(socket, node1),
      node2.id
    )
    # Clear state and highlights (drawer is already closed by JS.dispatch)
    update_graph(socket, {nil, node}, "combine")
  _ ->
    {:noreply, socket |> put_flash(:error, "Please select exactly 2 nodes")}
end
```

**Note:** The combine drawer is closed on the client side before this event fires, using `JS.dispatch("toggle-panel")` in the button's `phx-click` handler. This provides immediate UI feedback while the synthesis is being created.

##### `handle_event("combine_deselect_node", %{"node-id" => node_id}, socket)`
Removes a specific node from selection.

##### `handle_event("combine_clear_selection", _params, socket)`
Clears all selected nodes.

##### `handle_event("close_combine_setup", _params, socket)`
Exits combine setup mode and clears everything.

### UI Integration

#### Template (`graph_live.html.heex`)
Added combine drawer alongside presentation drawer:

```heex
<div
  id="combine-drawer"
  class="fixed top-10 bottom-0 right-0 w-0 overflow-hidden bg-white border-l border-gray-200 z-50 transform translate-x-full opacity-0 transition-all duration-300 ease-in-out"
>
  <.live_component
    module={DialecticWeb.CombineSetupComp}
    id="combine-setup"
    mode={@combine_mode}
    selected_nodes={@combine_selected_nodes}
  />
</div>
```

#### Panel Toggle (`assets/js/app.js`)
Added `"combine-drawer"` to the panels array and logic to close combine mode when switching to other panels:

```javascript
if (combineWasOpen && id !== "combine-drawer") {
  this.pushEvent("close_combine_setup", {});
}
```

#### Action Button (`action_toolbar_comp.ex`)
Modified combine button to toggle the drawer and enter setup mode:

```elixir
phx-click={
  Phoenix.LiveView.JS.dispatch("toggle-panel",
    to: "#graph-layout",
    detail: %{id: "combine-drawer"}
  )
  |> Phoenix.LiveView.JS.push("node_combine")
}
```

### Removed Components

The old modal-based combine UI has been completely removed:
- `CombineComp` - Deleted
- `CombinetMsgComp` - Deleted
- `handle_event("combine_node_select", ...)` - Deleted
- `handle_event("modal_closed", ...)` - Deleted
- `show_combine` assign - Removed

## Testing

Updated `graph_live_e2e_test.exs` to test the new flow:

```elixir
# Open combine mode
render_click(view, "node_combine", %{})
assert assigns.combine_mode == :setup

# Select first node
render_click(view, "node_clicked", %{"id" => node1_id})
assert length(assigns.combine_selected_nodes) == 1

# Select second node
render_click(view, "node_clicked", %{"id" => node2_id})
assert length(assigns.combine_selected_nodes) == 2

# Execute combine
render_click(view, "execute_combine", %{})
# Verify synthesis node created
```

## Future Improvements

1. **Node limit indicator**: Show "2/2 selected" more prominently
2. **Animations**: Animate node selection/deselection
3. **Keyboard shortcuts**: Allow ESC to exit, number keys to select
4. **Preview synthesis**: Show AI-generated preview before committing
5. **Drag reorder**: Allow users to swap which node is "first" vs "second"
6. **Multi-combine**: Allow combining more than 2 nodes at once

## Related Files

### New Files
- `lib/dialectic_web/live/combine_setup_comp.ex` - New setup panel component
- `docs/COMBINE_MODE.md` - This documentation

### Modified Files
- `lib/dialectic_web/live/graph_live.ex` - Main LiveView with event handlers
- `lib/dialectic_web/live/graph_live.html.heex` - Template with drawer
- `lib/dialectic_web/live/action_toolbar_comp.ex` - Combine button
- `assets/js/graph_hook.js` - Graph highlighting events
- `assets/js/graph_style.js` - Node styling
- `assets/js/app.js` - Panel management
- `test/dialectic_web/live/graph_live_e2e_test.exs` - E2E tests
- `test/dialectic_web/live/graph_live_test.exs` - Unit tests

### Deleted Files
- `lib/dialectic_web/live/combine_comp.ex` - Old modal component (removed)
- `lib/dialectic_web/live/combine_msg_comp.ex` - Old node list item component (removed)
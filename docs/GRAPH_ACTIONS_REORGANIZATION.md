# Graph Actions Reorganization

## Overview

Following UX designer feedback, the graph action buttons have been reorganized into two distinct menus:

1. **Document-level menu** (top right): Actions that apply to the entire graph/document
2. **Node-level actions** (bottom menu): Actions that operate on the currently selected node

This separation provides better visual hierarchy and clearer user intent.

---

## Changes Summary

### Before
- All actions were combined in a single bottom toolbar
- Mixed document-level and node-level actions together
- Could be confusing which actions applied to what scope

### After
- **Document menu** (top right): Star, Read, Share, Present, Views, Highlights, Settings
- **Node actions** (floating on selected node): Related Ideas, Pros/Cons, Blend, Explore, Delete
- Clear separation of concerns
- Better visual organization
- Context menu appears directly on the selected node

---

## New Components

### 1. DocumentMenuComp (`lib/dialectic_web/live/document_menu_comp.ex`)

**Purpose**: Provides document-level controls that affect the entire graph or viewing experience.

**Actions included**:
- **Star/Unstar** - Add/remove current node to/from notes
- **Read** - Open linear reading view
- **Share** - Share the graph
- **Present** - Enter presentation mode
- **Views** - Toggle view options panel
- **Highlights** - Toggle highlights panel
- **Settings** - Toggle settings panel

**Location**: Fixed position in top-right corner (`fixed top-12 right-3`)

**Features**:
- Shows lock indicator when graph is locked
- Responsive button states (disabled when graph_id is nil)
- Groups related actions with visual dividers
- Consistent styling with rounded buttons

### 2. NodeActionsComp (`lib/dialectic_web/live/node_actions_comp.ex`)

**Purpose**: Provides actions that operate on the currently selected node.

**Actions included**:
- **Ideas** - Generate related ideas (orange)
- **Pro/Con** - Generate pros and cons analysis (gradient emerald-rose)
- **Blend** - Combine with another node (violet)
- **Explore** - Explore all points (gradient fuchsia-rose-amber)
- **Delete** - Delete the current node (red, with constraints)

**Location**: Floating menu positioned directly below (or above if space limited) the currently selected node

**Features**:
- Inherits deletion logic from original ActionToolbarComp
- Smart deletion constraints (ownership, children, lock state)
- Contextual tooltips
- Compact horizontal layout
- Automatically repositions on pan/zoom
- Hides when clicking background
- Intelligently positions above node if bottom would overflow viewport

---

## Files Modified

### Created
1. `lib/dialectic_web/live/document_menu_comp.ex` - Document-level menu component
2. `lib/dialectic_web/live/node_actions_comp.ex` - Node-level actions component
3. `assets/js/node_menu_hook.js` - JavaScript hook for Cytoscape popper integration

### Modified
1. `lib/dialectic_web/live/graph_live.html.heex` - Updated to use new components:
   - Added DocumentMenuComp in top-right
   - Added floating NodeActionsComp with NodeMenu hook
   - Removed ActionToolbarComp from bottom menu
   - Conditional rendering (hidden during presentation mode)
2. `assets/js/draw_graph.js` - Import and register cytoscape-popper extension
3. `assets/js/graph_hook.js` - Store hook reference for menu access
4. `assets/js/app.js` - Register NodeMenuHook
5. `assets/package.json` - Added `cytoscape-popper` and `@popperjs/core` dependencies

### Preserved
1. `lib/dialectic_web/live/action_toolbar_comp.ex` - Still exists and can be removed later if not used elsewhere

---

## Implementation Details

### Document Menu Positioning

```heex
<div class="fixed top-12 right-3 z-30 flex items-center gap-2 pointer-events-auto">
  <!-- Lock indicator (if applicable) -->
  <!-- Main action buttons group -->
</div>
```

- Uses `fixed` positioning for consistent placement
- Positioned below header (`top-12` = 48px from top)
- High z-index (30) to stay above graph content
- `pointer-events-auto` to ensure clickability
- Hidden during presentation mode

### Node Actions Positioning

```heex
<div id="node-actions-menu" phx-hook="NodeMenu" class="pointer-events-none">
  <.live_component module={DialecticWeb.NodeActionsComp} ... />
</div>
```

- Floating menu positioned via JavaScript
- Appears below selected node (or above if viewport space is limited)
- Follows node on pan/zoom
- Initially hidden, shown only when node is selected
- Compact horizontal layout
- All node-scoped actions together

**JavaScript Hook (`node_menu_hook.js`)**:
- Uses Cytoscape's built-in `popper()` extension
- Automatically attaches menu to selected node
- Popper handles all positioning logic (placement, overflow, viewport boundaries)
- Automatically updates position on pan/zoom (no manual debouncing needed)
- Listens to Cytoscape tap events to show/hide menu
- Hides menu when clicking graph background

### Deletion Logic

The delete button includes sophisticated constraint checking:

1. **Ownership check**: User must be the node author
2. **Children check**: Node must have no live (non-deleted) children
3. **Lock check**: Graph must not be locked
4. **Tooltip feedback**: Clear messaging about why deletion is disabled

---

## Visual Design

### Document Menu
- White background with backdrop blur (`bg-white/95 backdrop-blur`)
- Shadow and border for elevation (`shadow-lg border border-gray-200`)
- Grouped buttons with consistent padding
- Color-coded by function:
  - Star: Yellow
  - Read: Gray
  - Share: Indigo
  - Present: Fuchsia
  - Views: Sky
  - Highlights: Amber
  - Settings: Gray

### Node Actions
- Compact button layout with icons + text
- Color-coded by action type (matching existing patterns)
- Visual divider before delete action
- Smaller text size (`text-xs`) for compact appearance

---

## User Experience Improvements

1. **Clearer Intent**: Users can now easily distinguish between graph-wide and node-specific actions
2. **Reduced Clutter**: Bottom menu is less crowded with only node actions
3. **Better Discoverability**: Document controls are always visible in top-right
4. **Consistent Patterns**: Follows common UI patterns (document controls top-right, contextual actions near content)

---

## Testing Considerations

When testing this feature, verify:

1. ✓ Document menu appears in top-right when not in presentation mode
2. ✓ Document menu is hidden during presentation mode
3. ✓ Node actions appear as floating menu on selected node
4. ✓ Floating menu follows node when panning/zooming
5. ✓ Menu positions above node when bottom would overflow
6. ✓ Menu hides when clicking graph background
7. ✓ All actions trigger correct events (no regressions)
8. ✓ Delete button constraints work correctly
9. ✓ Responsive behavior on different screen sizes
10. ✓ Lock indicator appears when graph is locked
11. ✓ Disabled states work correctly when graph_id is nil

---

## Future Considerations

1. **Mobile responsiveness**: May need special handling for small screens
2. **Keyboard shortcuts**: Consider adding shortcuts for common actions
3. **Action tooltips**: Could be enhanced with keyboard shortcut hints
4. **Animation**: Could add subtle slide-in/fade animations for menu appearance
5. **Remove old ActionToolbarComp**: If not used elsewhere, can be deprecated
6. **Right-click context menu**: Could add right-click support to show menu
7. **Menu arrow**: Add visual arrow pointing to the node
8. **Performance**: Monitor performance with very large graphs (many nodes)

---

## Migration Notes

- Existing functionality is preserved, just reorganized
- No breaking changes to event handlers
- All phx-click events remain the same
- Compatible with existing JavaScript hooks
- Node menu now requires Cytoscape instance to be available
- Graph hook stores reference on DOM element for menu positioning

## Technical Implementation Details

### How the Floating Menu Works

1. **Cytoscape Extension**: Uses the official `cytoscape-popper` extension with `@popperjs/core`
2. **Node Tap**: When a node is tapped, Cytoscape event listener triggers menu display
3. **Popper Creation**: Hook calls `node.popper()` to create a Popper.js instance
4. **Automatic Positioning**: Popper.js handles all positioning logic with modifiers:
   - `flip`: Automatically flips to top if bottom overflows
   - `preventOverflow`: Ensures menu stays within viewport
   - `offset`: Adds 8px padding from node
5. **Pan/Zoom Tracking**: Popper automatically updates position via Cytoscape event listener
6. **Cleanup**: Menu destroys popper instance when clicking background

### Cytoscape Popper Integration

The menu uses Cytoscape's official popper extension:
- **Extension**: `cytoscape-popper` wraps Popper.js for Cytoscape nodes
- **Benefits**: 
  - No manual coordinate calculations needed
  - Automatic viewport boundary detection
  - Built-in flip/overflow prevention
  - Optimized for pan/zoom performance
- **Configuration**: 
  - Placement: `bottom` with fallback to `top`, `left`, `right`
  - Boundary: `viewport` with 8px padding
  - Offset: 8px from node edge
- **Updates**: Listens to `pan`, `zoom`, `resize` events to reposition automatically
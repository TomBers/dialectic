# Selection Actions Expansion - Implementation Summary

**Date:** January 26, 2026  
**Status:** Phase 1 Complete - Schema & Core Infrastructure Ready

## Overview

This document describes the expansion of the text selection actions system to support multiple types of linked actions (pros/cons, related ideas, deep dives, etc.) through a flexible many-to-many relationship model.

## Goals

1. Allow highlights to link to multiple nodes of different types
2. Support pros/cons analysis, related ideas, and custom questions from selected text
3. Provide visual indicators showing what's linked to each highlight
4. Create a flexible foundation for future expansion

## Architecture Changes

### Database Schema

#### New Table: `highlight_links`

```sql
CREATE TABLE highlight_links (
  id SERIAL PRIMARY KEY,
  highlight_id INTEGER NOT NULL REFERENCES highlights(id) ON DELETE CASCADE,
  node_id VARCHAR NOT NULL,
  link_type VARCHAR NOT NULL,
  inserted_at TIMESTAMP NOT NULL,
  
  CONSTRAINT unique_highlight_node UNIQUE (highlight_id, node_id)
);

CREATE INDEX ON highlight_links(highlight_id);
CREATE INDEX ON highlight_links(node_id);
```

**Link Types:**
- `explain` - Explanation/answer node
- `question` - Custom question answer node  
- `pro` - Supporting argument (thesis) node
- `con` - Counter argument (antithesis) node
- `related_idea` - Related ideas node
- `deep_dive` - Deep dive exploration node

#### Removed from `highlights` table:
- `linked_node_id` (single field - no longer needed)
- `link_type` (single field - no longer needed)

#### Added to `highlights` schema:
- `has_many :links, HighlightLink` association

### New Schema Module

**File:** `lib/dialectic/highlights/highlight_link.ex`

- Validates link types against allowed list
- Enforces unique constraint (one highlight can't link to same node twice)
- Provides clean API for link management

### Context Layer Updates

**File:** `lib/dialectic/highlights.ex`

New functions added:
- `add_link(highlight_id, node_id, link_type)` - Create a link
- `get_links(highlight_id)` - Get all links for a highlight
- `get_links_by_type(highlight_id, link_type)` - Filter by type
- `has_link?(highlight_id, link_type)` - Check existence
- `remove_link(highlight_id, node_id)` - Delete a link
- `list_highlights_with_links(criteria)` - Preload links efficiently
- `get_highlight_for_selection(mudg_id, node_id, start, end)` - Find existing highlight

**Deprecated functions removed:**
- `link_to_node/3` - Replaced by `add_link/3`
- `unlink_from_node/1` - No longer needed (cascade delete handles cleanup)

## Component Architecture

### New LiveComponent: `SelectionActionsComp`

**File:** `lib/dialectic_web/live/selection_actions_comp.ex`

**Responsibilities:**
- Manage selection modal visibility and state
- Query existing highlights and their links
- Show appropriate button states ("Create" vs "View")
- Handle all selection actions (explain, pros/cons, related ideas, questions)
- Send actions to parent LiveView via messages

**Props:**
- `current_user` - For permission checks
- `graph_id` - Current graph context
- `can_edit` - Whether editing is allowed

**State:**
- `visible` - Modal visibility
- `selected_text` - The selected text
- `node_id` - Source node ID
- `offsets` - Start/end character positions
- `highlight` - Existing highlight (if any)
- `links` - Associated links

### Event Flow

```
User selects text
  ↓
TextSelectionHook fires "selection:show" window event
  ↓
SelectionActionsHook (phx-hook) receives event
  ↓
Hook calls pushEvent("show", {...}) to LiveComponent
  ↓
Component.handle_event("show") queries existing highlight/links
  ↓
Component re-renders with conditional button states
  ↓
User clicks action button (e.g., "Pros/Cons")
  ↓
Component.handle_event("pros_cons") 
  ↓
send(parent, {:selection_action, params})
  ↓
GraphLive.handle_info({:selection_action, params})
  ↓
Create/update highlight, create nodes, create links
  ↓
Update graph and broadcast changes
```

## Implementation Details

### Graph Live Updates

**File:** `lib/dialectic_web/live/graph_live.ex`

#### New message handler:
```elixir
def handle_info({:selection_action, params}, socket)
```

#### New action handlers:
- `handle_selection_action(:explain, ...)` - Create explanation
- `handle_selection_action(:highlight_only, ...)` - Just highlight
- `handle_selection_action(:pros_cons, ...)` - Create thesis/antithesis with links
- `handle_selection_action(:related_ideas, ...)` - Create ideas node with link
- `handle_selection_action(:ask_question, ...)` - Custom question with link

#### Helper function:
```elixir
defp create_highlight(socket, node_id, offsets, selected_text)
```

Creates or finds existing highlight for the selection.

### Visual Indicators

**File:** `lib/dialectic_web/live/right_panel_comp.ex`

**Added helper functions:**
- `link_type_icon/1` - Maps type to hero icon name
- `link_type_color/1` - Maps type to Tailwind color class
- `link_type_label/1` - Human-readable label

**UI Display:**
In the highlights list, each highlight now shows:
- Selected text snippet
- Node ID
- Colored icons for each linked node (with tooltips)
  - 💡 Orange for related ideas
  - ⬆️ Green for pro
  - ⬇️ Red for con  
  - ❓ Blue for questions
  - ℹ️ Gray for explanations
  - 🔍 Cyan for deep dives

### Selection Modal UI

**Buttons available:**

1. **Explain** (Blue)
   - Creates explanation answer node
   - Links with type `explain`

2. **Highlight** (Yellow)  
   - Just creates highlight, no linked nodes

3. **Pros & Cons** (Green-to-Red gradient)
   - Creates thesis + antithesis nodes
   - Links both with types `pro` and `con`

4. **Related Ideas** (Orange)
   - Creates ideas node
   - Links with type `related_idea`

5. **Ask Question** (Indigo, textarea form)
   - Creates custom question answer node
   - Links with type `question`
   - Allows multiple questions per highlight

**Button states:**
- If link exists: "View [Type]" (future: navigate to node)
- If link doesn't exist: "Create [Type]"
- Disabled if `can_edit` is false

## Files Modified

### Schema & Context
- `priv/repo/migrations/20260126100615_create_highlight_links.exs` (new)
- `priv/repo/migrations/20260126100632_remove_old_link_fields_from_highlights.exs` (new)
- `lib/dialectic/highlights/highlight_link.ex` (new)
- `lib/dialectic/highlights/highlight.ex` (modified)
- `lib/dialectic/highlights.ex` (modified)

### Components
- `lib/dialectic_web/live/selection_actions_comp.ex` (new)
- `lib/dialectic_web/live/right_panel_comp.ex` (modified)

### LiveViews
- `lib/dialectic_web/live/graph_live.ex` (modified)
- `lib/dialectic_web/live/graph_live.html.heex` (modified)
- `lib/dialectic_web/live/linear_graph_live.html.heex` (modified)

### JavaScript
- `assets/js/selection_actions_hook.js` (simplified)

### Controllers
- `lib/dialectic_web/controllers/highlight_json.ex` (modified)

## Migration Applied

```bash
mix ecto.migrate

# Created:
# - highlight_links table
# - Indexes on highlight_id, node_id, and unique(highlight_id, node_id)

# Removed:
# - highlights.linked_node_id field
# - highlights.link_type field
# - Associated indexes
```

## Current Limitations & Future Work

### Phase 2: Enhanced Navigation
- [ ] Click link icon in highlights list → navigate to linked node
- [ ] Show preview of linked nodes on hover
- [ ] Link icon badges should be clickable

### Phase 3: Duplicate Detection UX
- [ ] Show warning when creating similar actions on same text
- [ ] Allow user to view existing instead of creating duplicate
- [ ] Smart suggestions based on existing links

### Phase 4: Unlink Functionality
- [ ] Add "unlink" buttons in highlight details
- [ ] Cascade considerations (delete highlight vs. delete link)
- [ ] Undo/redo support

### Phase 5: Advanced Features
- [ ] Deep dive action integration
- [ ] Highlight color coding based on link types
- [ ] Multiple highlights per text range (different users/types)
- [ ] Link strength indicators (how many links)

### Phase 6: Performance Optimizations
- [ ] Batch link creation for bulk operations
- [ ] Preload optimization for large graphs
- [ ] Query optimization with proper indexes

## Testing Checklist

### Manual Testing
- [x] Compile without errors
- [ ] Create highlight with explain action
- [ ] Create highlight with pros/cons action  
- [ ] Create highlight with related ideas action
- [ ] Ask custom question on highlight
- [ ] View existing highlights in right panel
- [ ] See link icons next to highlights
- [ ] Hover over icons to see tooltips
- [ ] Delete node with links (cascade delete)
- [ ] Create multiple questions on same highlight
- [ ] Button states update correctly (View vs. Create)

### Automated Testing (TODO)
- [ ] Unit tests for HighlightLink schema
- [ ] Context tests for add_link, get_links, etc.
- [ ] Integration tests for SelectionActionsComp
- [ ] E2E tests for complete selection → node creation flow

## Notes

### Design Decisions

1. **Join table over JSON array:** We chose a proper join table for maximum flexibility and query performance, rather than storing node IDs in a JSON array.

2. **Relaxed overlap validation:** We removed the strict overlap validation to allow multiple users or the same user to create different types of links on the same text.

3. **Component extraction:** Moving selection actions to a LiveComponent provides better encapsulation, testability, and reusability across graph/linear views.

4. **Cascade delete:** When a highlight is deleted, all its links are automatically removed via `ON DELETE CASCADE`. When a node is deleted, we explicitly clean up links in `graph_live.ex`.

5. **Link type validation:** We enforce valid link types at the schema level to prevent data integrity issues.

### Breaking Changes

**None for end users** - The old single-link system had not been deployed to production yet, so this is a clean implementation.

### Performance Considerations

- Indexes on `highlight_id` and `node_id` ensure fast lookups
- Preloading links with `list_highlights_with_links` avoids N+1 queries
- Unique constraint prevents duplicate links efficiently

## Conclusion

Phase 1 is complete with a solid foundation for multi-link highlights. The system is now ready for:
- Creating multiple types of links per highlight
- Visual indication of link types
- Future navigation and advanced features

The architecture is flexible enough to add new link types without schema changes, and the component-based approach makes it easy to extend functionality.
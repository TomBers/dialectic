# Text Selection Quick Reference

## TL;DR

**Problem**: Panel was auto-hiding, protocol error when asking questions about selections.

**Solution**: Ultra-simple modal behavior + dedicated `ask-about-selection` action.

## Panel Behavior (Modal-Style)

### Opens When:
- User selects text

### Closes When (only 4 ways):
1. Click X button
2. Click "Explain" 
3. Click "Highlight"
4. Click "Ask" (submit)

### Stays Open For:
- Clicking outside ✓
- Typing in input ✓
- Clearing selection ✓
- Pressing Escape ✓
- Everything else ✓

## Three Actions

### 1. Quick Explain (one-click)
```javascript
Event: "reply-and-answer"
Trigger: Click "Explain" button
Result: Creates question "Please explain: [text]" with minimal context answer
```

### 2. Create Highlight (one-click)
```javascript
Event: (handled by createHighlight)
Trigger: Click "Highlight" button  
Result: Saves highlight to database, renders in UI
```

### 3. Ask About Selection (custom question)
```javascript
Event: "ask-about-selection"
Trigger: Type question + press Enter or click "Ask"
Params: { question: "...", selected_text: "..." }
Result: Creates question node with source_highlight_id metadata
```

## Code Changes Summary

### Removed
- ❌ All auto-hide event listeners (~70 lines)
- ❌ Complex focus detection logic
- ❌ `highlight_context` parameter passing
- ❌ Mixed responsibility in `reply-and-answer`

### Added
- ✅ `ask-about-selection` event handler
- ✅ `GraphActions.ask_about_selection/3`
- ✅ `GraphManager.update_vertex_fields/3`
- ✅ Close button UI (3 templates)
- ✅ Guard clause in `handleSelection`

## Data Flow

```
User types question about "bioengineered"
   ↓
JavaScript: ask-about-selection event
   {
     question: "What does this mean?\n\nRegarding: \"bioengineered\"",
     selected_text: "bioengineered"
   }
   ↓
LiveView: handle_event("ask-about-selection", ...)
   ↓
GraphActions.ask_about_selection(...)
   ↓
1. Create question node
2. Update source_highlight_id = "bioengineered"
3. Generate answer with minimal context
   ↓
Result: Question node with metadata stored
```

## Key Files

- `assets/js/text_selection_hook.js` - Panel + event
- `lib/dialectic_web/live/graph_live.ex` - Event handler
- `lib/dialectic/graph/graph_actions.ex` - ask_about_selection
- `lib/dialectic/graph/graph_manager.ex` - update_vertex_fields

## Testing

```bash
# Start server
mix phx.server

# Test sequence:
1. Select text
2. Type question
3. Press Enter
4. Verify no errors
5. Check question has source_highlight_id
```

## Debugging

If panel still auto-hides:
- Check `handleSelection` has guard clause
- Verify no other event listeners registered
- Check browser console for errors

If protocol error:
- Verify using `ask-about-selection` event
- Check params are strings, not structs
- Ensure `update_vertex_fields` exists

## Benefits

- 🎯 Predictable UX
- 🧹 Simpler code (-70 lines)
- 🔧 Maintainable architecture
- 🐛 No protocol errors
- 📱 Better mobile UX

## Documentation

- `TEXT_SELECTION_COMPLETE_SUMMARY.md` - Full details
- `ASK_ABOUT_SELECTION_ACTION.md` - New action docs
- `SELECTION_PANEL_SIMPLE.md` - Modal behavior guide
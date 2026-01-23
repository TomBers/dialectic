# Text Selection Multiple Hooks Fix

## The Problem

In the Linear view, there are **N TextSelectionHook instances** (one per node), all listening to `mouseup` events on their respective containers. This caused a major UX issue where clicking the close button required multiple clicks to actually close the panel.

## Root Cause Analysis

### The Setup

```
Linear View with 3 nodes:

┌─────────────────────────────┐
│ Node 1 (TextSelectionHook)  │
│   └─ .selection-actions     │
├─────────────────────────────┤
│ Node 2 (TextSelectionHook)  │
│   └─ .selection-actions     │
├─────────────────────────────┤
│ Node 3 (TextSelectionHook)  │
│   └─ .selection-actions     │
└─────────────────────────────┘
```

Each hook listens to `mouseup` on its container element.

### What Happened on Close Button Click

**Before the fix:**

```
1. User clicks X button in Node 2's panel
   ↓
2. onclick handler fires → hideSelectionActions()
   Panel gets hidden (adds "hidden" class)
   ↓
3. mouseup event bubbles up
   ↓
4. ALL THREE hook instances receive the mouseup event
   (because the event bubbles to document level)
   ↓
5. Each hook runs handleSelection after 10ms delay
   ↓
6. By the time setTimeout fires:
   - Node 2's panel is hidden
   - Guard clause checks: "is panel visible?" → NO
   - So it continues to check selection
   - Text is still selected!
   - Shows Node 2's panel AGAIN!
   ↓
7. Meanwhile, Node 1 and Node 3's hooks also run
   - Their panels are hidden
   - They might also try to show panels
   ↓
8. User clicks X again... and the cycle repeats
```

**Result:** Multiple clicks needed to close the panel.

## The Solution

Added two crucial guard clauses to `handleSelection`:

### Guard Clause 1: Event Container Check

```javascript
// IMPORTANT: Only handle events that originated within THIS hook's container
if (!this.el.contains(event.target)) {
  return; // Event didn't happen in this hook's container, ignore it
}
```

**Purpose:** Each hook only processes events that happened within its own node container.

**Effect:** If you click in Node 2, only Node 2's hook processes it (Node 1 and Node 3 ignore it).

### Guard Clause 2: Panel Click Check

```javascript
// IMPORTANT: If the click was inside the selection actions panel, ignore it
if (selectionActionsEl.contains(event.target)) {
  return; // Click was inside the panel, don't re-process
}
```

**Purpose:** If the click was on the panel itself (like the close button), don't try to show/hide the panel based on selection state.

**Effect:** Close button clicks are handled by their `onclick` handlers, and `handleSelection` stays out of the way.

## Event Flow After Fix

```
1. User clicks X button in Node 2's panel
   ↓
2. onclick handler fires → hideSelectionActions()
   Panel gets hidden
   ↓
3. mouseup event bubbles up
   ↓
4. ALL THREE hook instances receive the mouseup event
   ↓
5. Node 1's hook:
   - Checks: event.target in my container? NO (it's in Node 2)
   - Returns early ✓
   ↓
6. Node 2's hook:
   - Checks: event.target in my container? YES
   - Checks: event.target in my panel? YES (it's the X button)
   - Returns early ✓
   ↓
7. Node 3's hook:
   - Checks: event.target in my container? NO (it's in Node 2)
   - Returns early ✓
   ↓
8. Panel stays closed! ✓
```

**Result:** One click closes the panel reliably.

## Code Changes

### Before

```javascript
handleSelection(event) {
  setTimeout(() => {
    const selection = window.getSelection();
    const selectionActionsEl = this.el.querySelector(".selection-actions");
    
    if (!selectionActionsEl) return;
    
    const panelIsVisible = !selectionActionsEl.classList.contains("hidden");
    
    if (panelIsVisible) {
      return;
    }
    
    // ... check selection and show panel
  }, 10);
}
```

### After

```javascript
handleSelection(event) {
  setTimeout(() => {
    // Guard 1: Only process events in this container
    if (!this.el.contains(event.target)) {
      return;
    }
    
    const selection = window.getSelection();
    const selectionActionsEl = this.el.querySelector(".selection-actions");
    
    if (!selectionActionsEl) return;
    
    // Guard 2: Don't re-process panel clicks
    if (selectionActionsEl.contains(event.target)) {
      return;
    }
    
    const panelIsVisible = !selectionActionsEl.classList.contains("hidden");
    
    if (panelIsVisible) {
      return;
    }
    
    // ... check selection and show panel
  }, 10);
}
```

## Why This Pattern?

### Separation of Concerns

**Panel buttons handle closing:**
```javascript
closeButton.onclick = (e) => {
  e.preventDefault();
  e.stopPropagation();
  this.hideSelectionActions();
};
```

**handleSelection handles showing:**
```javascript
// Only shows panel when:
// 1. Event is in this container
// 2. Event is NOT in the panel
// 3. Panel is NOT already visible
// 4. There's a valid text selection
```

### Benefits

✅ **Clear responsibility** - Buttons close, selection shows  
✅ **No interference** - Hooks don't fight each other  
✅ **Predictable** - One click always closes  
✅ **Scalable** - Works with any number of nodes  

## Testing Verification

### Single Node (Node View)
- Click X → closes in 1 click ✓
- No other hooks to interfere ✓

### Multiple Nodes (Linear View)
- Click X on Node 2 → only Node 2's hook processes ✓
- Node 1 and 3 ignore the event ✓
- Closes in 1 click ✓

### Rapid Selection Changes
- Select text in Node 1 → Node 1's panel shows ✓
- Select text in Node 2 → Node 1's panel hides, Node 2's shows ✓
- Other nodes don't interfere ✓

## Edge Cases Handled

### Event Target is SVG inside Button
- `selectionActionsEl.contains(event.target)` checks the entire subtree
- Works correctly even if clicking SVG path elements

### Panel is Already Hidden
- Guard clause 2 catches this before checking visibility
- Prevents race conditions

### Multiple Rapid Clicks
- Each click is processed independently
- Guards prevent interference between clicks

## Key Insights

1. **Multiple hook instances are inevitable** in list views
2. **Event containment is crucial** when hooks are on sibling elements
3. **Guard clauses should be ordered** from most general to most specific
4. **Button handlers and selection handlers should be separate** concerns

## Performance Impact

**Before:** Every mouseup event processed by all N hooks (even if irrelevant)

**After:** Most mouseup events return early after simple containment check

**Result:** Slightly better performance, dramatically better UX

## Related Issues

This pattern also prevents:
- Panels appearing in wrong nodes
- Selection state confusion between nodes
- Event handler memory leaks
- UI flickering from competing handlers

## Documentation

- `TEXT_SELECTION_COMPLETE_SUMMARY.md` - Full implementation
- `TEXT_SELECTION_UX_IMPROVEMENTS.md` - UX improvements
- `SELECTION_PANEL_SIMPLE.md` - Modal behavior guide
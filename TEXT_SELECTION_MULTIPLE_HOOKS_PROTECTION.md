# Text Selection Multiple Hooks Protection

## Overview

In the linear view, multiple nodes are rendered, each with its own `TextSelectionHook` instance. Without proper guards, all hooks would respond to text selection events, causing the modal to open multiple times or with the wrong context.

## The Problem

### Linear View Structure
```
Linear View with 10 nodes:

┌─────────────────────────────┐
│ Node 1 (TextSelectionHook)  │
├─────────────────────────────┤
│ Node 2 (TextSelectionHook)  │
├─────────────────────────────┤
│ Node 3 (TextSelectionHook)  │
├─────────────────────────────┤
│ ...  (7 more nodes)         │
└─────────────────────────────┘
```

Each hook listens to `mouseup` on its container element.

### What Could Go Wrong

**Without guards:**
```
User selects text in Node 5
   ↓
mouseup event fires
   ↓
ALL 10 hooks receive the event (event bubbles to document)
   ↓
Each hook runs handleSelection()
   ↓
10 events sent to server: "show-selection-actions"
   ↓
Modal opens/closes/reopens 10 times
   ↓
Wrong node_id might be used
   ↓
Chaos! ❌
```

## The Solution

Three layers of protection in `handleSelection()`:

### Guard 1: Container Check
```javascript
// Only handle events that originated within THIS hook's container
if (!this.el.contains(event.target)) {
  return; // Event didn't happen in this hook's container, ignore it
}
```

**Purpose:** Filter out events that happened in other nodes.

**Effect:** If you select text in Node 5, only Node 5's hook continues.

### Guard 2: Selection Within Component
```javascript
// Check if selection is empty or not within this component
if (selection.isCollapsed || !this.isSelectionInComponent(selection)) {
  return;
}
```

**Purpose:** Ensure the selection is actually inside this container.

**Effect:** If selection spans multiple nodes or is outside, this hook ignores it.

### Guard 3: Closest Container
```javascript
// If we're not the closest container to the selection, don't show our button
if (!this.isClosestSelectionContainer()) {
  return;
}
```

**Purpose:** If selection spans nested containers, only the innermost one responds.

**Effect:** Handles edge cases with nested content.

## Event Flow with Guards

```
User selects text in Node 5
   ↓
mouseup event bubbles
   ↓
Node 1 hook: event.target not in my container? YES → Return ✓
Node 2 hook: event.target not in my container? YES → Return ✓
Node 3 hook: event.target not in my container? YES → Return ✓
Node 4 hook: event.target not in my container? YES → Return ✓
Node 5 hook: event.target in my container? YES → Continue
             selection in my component? YES → Continue
             closest container? YES → Send event ✓
Node 6 hook: event.target not in my container? YES → Return ✓
Node 7 hook: event.target not in my container? YES → Return ✓
...
   ↓
ONE event sent to server
   ↓
Modal opens once with correct node_id ✓
```

## Implementation

### Guard 1: Container Check

```javascript
if (!this.el.contains(event.target)) {
  return;
}
```

Uses DOM API to check if the click target is a descendant of this hook's container element.

### Guard 2: Selection In Component

```javascript
isSelectionInComponent(selection) {
  const range = selection.rangeCount > 0 ? selection.getRangeAt(0) : null;
  if (!range) return false;

  const selectionContainer = range.commonAncestorContainer;
  return this.el.contains(selectionContainer);
}
```

Checks if the selection's common ancestor is within this container.

### Guard 3: Closest Container

```javascript
isClosestSelectionContainer() {
  const selection = window.getSelection();
  if (!selection.rangeCount) return false;

  const range = selection.getRangeAt(0);
  let container = range.commonAncestorContainer;

  // Walk up to find element node
  while (container && container.nodeType !== Node.ELEMENT_NODE) {
    container = container.parentNode;
  }

  // Find all TextSelectionHook containers
  const allContainers = document.querySelectorAll('[phx-hook="TextSelectionHook"]');

  // Find closest container to selection
  let closestContainer = null;
  let minDepth = Infinity;

  for (const hookContainer of allContainers) {
    if (hookContainer.contains(container)) {
      let depth = 0;
      let parent = container;
      while (parent && parent !== hookContainer) {
        depth++;
        parent = parent.parentNode;
      }
      if (depth < minDepth) {
        minDepth = depth;
        closestContainer = hookContainer;
      }
    }
  }

  return closestContainer === this.el;
}
```

Finds the closest container to the selection by measuring DOM depth.

## Edge Cases Handled

### Selection Spans Multiple Nodes
If user drags selection across Node 4 and Node 5:
- Guard 2 ensures only one hook responds (common ancestor determines winner)
- Modal opens with context from the correct node

### Rapid Selections
If user quickly selects text in different nodes:
- Each selection is independent
- Guards ensure only the relevant hook responds each time
- Modal updates correctly

### Nested Containers
If there are nested elements with hooks (rare but possible):
- Guard 3 ensures innermost container wins
- Prevents duplicate events

### Empty Selections
If user just clicks without selecting:
- `selection.isCollapsed` check catches this early
- No hooks proceed past Guard 2

## Benefits

✅ **No interference** - Each hook stays in its lane  
✅ **Correct context** - Modal always shows correct node_id  
✅ **Performance** - Most hooks return early (cheap checks)  
✅ **Scalable** - Works with any number of nodes  
✅ **Reliable** - Multiple layers of protection  

## Testing

### Single Node View
- Only one hook instance
- Guards still work correctly
- No performance impact

### Linear View (Multiple Nodes)
- 10+ hook instances
- Guards prevent interference
- Only one event sent per selection
- Correct node_id always used

### Nested Content
- Rare edge case
- Innermost container wins
- No duplicate events

## Code Metrics

| Scenario | Hooks on Page | Guards That Fire | Events Sent |
|----------|---------------|------------------|-------------|
| Single node | 1 | 3 checks per hook | 1 event |
| Linear (10 nodes) | 10 | ~30 checks total | 1 event |
| Linear (50 nodes) | 50 | ~150 checks total | 1 event |

**Result:** O(n) guard checks, but only 1 event sent regardless of n.

## Comparison

### Without Guards
```javascript
handleSelection(event) {
  const selectedText = window.getSelection().toString();
  this.pushEvent("show-selection-actions", { text: selectedText });
}
```

**Problems:**
- All N hooks send events
- Server receives N duplicate events
- Modal flickers
- Wrong node_id might be used

### With Guards (Current)
```javascript
handleSelection(event) {
  // Guard 1: Container check
  if (!this.el.contains(event.target)) return;
  
  // Guard 2: Selection check
  if (!this.isSelectionInComponent(selection)) return;
  
  // Guard 3: Closest container check
  if (!this.isClosestSelectionContainer()) return;
  
  // Only ONE hook reaches here
  this.pushEvent("show-selection-actions", { text: selectedText });
}
```

**Benefits:**
- Only 1 hook sends event
- Server receives 1 clean event
- Modal opens once
- Correct node_id guaranteed

## Future Improvements

Could optimize further:
- Cache container queries
- Use event delegation at document level
- Add debouncing for rapid selections

But current solution is sufficient and performant.

## Related Issues

This protection pattern is useful for any scenario with:
- Multiple hook instances on the same page
- DOM events that bubble
- Need for "closest container" logic

Similar patterns could be used for:
- Multiple form validation hooks
- Multiple drag-and-drop zones
- Multiple tooltip triggers

## References

- DOM API: `Element.contains()` - https://developer.mozilla.org/en-US/docs/Web/API/Node/contains
- Selection API - https://developer.mozilla.org/en-US/docs/Web/API/Selection
- Event bubbling - https://javascript.info/bubbling-and-capturing
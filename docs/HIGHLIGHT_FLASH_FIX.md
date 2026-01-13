# Highlight Flash Fix

## Problem

After LLM streaming completes, users were experiencing a visual "flash" or re-render where the content would briefly disappear and reappear. This was particularly noticeable when asking questions and watching the answer stream in.

## Root Cause

The issue was caused by unnecessary DOM manipulation in the highlight rendering system:

1. When LLM streaming completes, the markdown is rendered one final time with the complete content
2. This triggers a `markdown:rendered` event
3. The event listener calls `refreshHighlights()` → `fetchHighlights()`
4. `fetchHighlights()` calls `HighlightUtils.renderHighlights()`
5. **`renderHighlights()` was unconditionally removing ALL highlight spans and re-adding them**, even when nothing had changed
6. This DOM manipulation caused a visible flash as elements were removed and re-inserted

### Event Flow

```
LLM completes streaming
    ↓
Markdown renders final content
    ↓
"markdown:rendered" event dispatched
    ↓
fetchHighlights() called (with 300ms debounce)
    ↓
Fetch /api/highlights
    ↓
renderHighlights() called
    ↓
removeHighlights() removes ALL spans    ← FLASH HAPPENS HERE
    ↓
applySingleHighlight() re-adds spans
```

## Solution

Optimized `renderHighlights()` to skip DOM manipulation when highlights haven't changed:

### Before (Naive)

```javascript
renderHighlights(container, highlights) {
  if (!container || !highlights || highlights.length === 0) return;
  
  // Always remove and re-add ALL highlights
  this.removeHighlights(container);
  
  const sortedHighlights = [...highlights].sort(
    (a, b) => a.selection_start - b.selection_start
  );
  
  sortedHighlights.forEach((highlight) => {
    this.applySingleHighlight(container, highlight);
  });
}
```

### After (Optimized)

```javascript
renderHighlights(container, highlights) {
  if (!container || !highlights) return;
  
  // Get existing highlight IDs
  const existingSpans = container.querySelectorAll(".highlight-span");
  const existingIds = new Set(
    Array.from(existingSpans).map((span) => span.dataset.highlightId)
  );
  
  // Get new highlight IDs
  const newIds = new Set(highlights.map((h) => h.id.toString()));
  
  // Only proceed if there are actual changes
  const hasChanges =
    existingIds.size !== newIds.size ||
    Array.from(existingIds).some((id) => !newIds.has(id)) ||
    Array.from(newIds).some((id) => !existingIds.has(id));
  
  if (!hasChanges) {
    // No changes needed - highlights are already up to date
    return;
  }
  
  // Only remove and re-add if there are actual changes
  this.removeHighlights(container);
  // ... rest of rendering logic
}
```

## Key Optimization

The optimization compares existing highlights in the DOM with the fetched highlights:
- If the set of highlight IDs is identical, **skip all DOM manipulation**
- Only when highlights have actually changed (added, removed) do we update the DOM

This is especially important when:
- Streaming completes (no highlights yet, but system checks anyway)
- User navigates between nodes that don't have highlights
- Multiple `markdown:rendered` events fire in quick succession

## Files Changed

1. **`assets/js/highlight_utils.js`**
   - Added comparison logic to detect highlight changes
   - Skip DOM manipulation when highlights are unchanged

## Testing

To verify the fix:

1. Create a new graph
2. Ask a question
3. Watch the answer stream in
4. **Before**: Content would flash/re-render when streaming completes
5. **After**: Content smoothly completes with no flash

## Performance Benefits

- Eliminates unnecessary DOM manipulation
- Reduces reflows and repaints
- Improves perceived performance during streaming
- Prevents visual disruption when no highlights exist

## Edge Cases Handled

- Empty highlights array (no highlights) → skips rendering, no DOM changes
- Same highlights fetched multiple times → skips rendering
- Highlights actually changed → updates DOM as needed
- Container doesn't exist → early return

## Related Systems

This fix complements existing optimizations:
- `fetchHighlights()` already has 300ms debouncing
- `data-streaming` attribute prevents fetching during active streaming
- Highlight rendering only happens after markdown is fully rendered
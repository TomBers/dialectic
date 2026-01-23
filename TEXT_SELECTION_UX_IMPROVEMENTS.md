# Text Selection UX Improvements

## Overview

Two key UX improvements were made to the text selection panel:

1. **Display selected text** - Show users what text they're asking about
2. **Fix close button** - Prevent multiple clicks needed to close (especially in Linear view)

## Problem 1: Context Not Visible

### Issue
When users clicked into the custom question input field, they could no longer see what text they had selected. This made it hard to formulate questions about the selection.

### Solution
Added a selected text display box at the top of the panel that shows the highlighted text.

**Visual:**
```
┌─────────────────────────────────┐
│  Selected text:              [X]│
│  "speculative bioengineered"    │
├─────────────────────────────────┤
│  [Explain]  [Highlight]         │
├─────────────────────────────────┤
│  Or ask a custom question:      │
│  [___________________] [Ask]    │
└─────────────────────────────────┘
```

## Problem 2: Multiple Clicks to Close

### Issue
In the Linear view, closing the panel required many clicks on the X button. This was caused by:

1. Missing `type="button"` on buttons (defaulting to type="submit")
2. Event bubbling not being properly prevented
3. Multiple `handleSelection` calls from different node instances

### Solution

**Added to all buttons:**
```html
<button type="button" class="close-panel-btn">
```

**Enhanced JavaScript event handling:**
```javascript
closeButton.onclick = (e) => {
  e.preventDefault();      // Prevent form submission
  e.stopPropagation();     // Stop event bubbling
  this.hideSelectionActions();
};
```

This ensures:
- No form submissions triggered
- Events don't bubble to parent handlers
- Only one click needed to close

## Implementation Details

### JavaScript Changes (`assets/js/text_selection_hook.js`)

**Display selected text:**
```javascript
// Display the selected text in the panel
const selectedTextDisplay = selectionActionsEl.querySelector(
  ".selected-text-display",
);
if (selectedTextDisplay) {
  selectedTextDisplay.textContent = selectedText;
}
```

**Better close button handling:**
```javascript
closeButton.onclick = (e) => {
  e.preventDefault();
  e.stopPropagation();
  this.hideSelectionActions();
};
```

### Template Changes

All three templates updated:
- `lib/dialectic_web/live/node_comp.ex`
- `lib/dialectic_web/live/linear_graph_live.html.heex`
- `lib/dialectic_web/live/modal_comp.ex`

**Added selected text display:**
```html
<div class="pt-3 pb-1 px-2 bg-gray-50 rounded-md border border-gray-200">
  <div class="text-[10px] text-gray-500 mb-0.5 font-medium">Selected text:</div>
  <div class="selected-text-display text-xs text-gray-700 italic line-clamp-2"></div>
</div>
```

**Fixed all button types:**
```html
<button type="button" class="close-panel-btn">...</button>
<button type="button" class="explain-btn">...</button>
<button type="button" class="add-note-btn">...</button>
<button type="button" class="submit-custom-question">...</button>
```

## Styling Details

### Selected Text Display

- **Background:** Light gray (`bg-gray-50`)
- **Border:** Subtle gray border
- **Text:** Small, italic, with line-clamp-2 (max 2 lines)
- **Label:** Tiny text "Selected text:"
- **Padding:** Comfortable spacing for readability

### Line Clamp

Uses Tailwind's `line-clamp-2` utility to:
- Limit display to 2 lines
- Add ellipsis (...) if text is too long
- Keep panel compact even with long selections

Example:
```
Selected text:
"This is a very long selection that 
would normally wrap to many lines..."
```

## Benefits

### UX Benefits
✅ **Context always visible** - Users can see what they're asking about  
✅ **One-click close** - No more multiple clicks needed  
✅ **Better mobile experience** - Clearer on touch devices  
✅ **Professional appearance** - Polished, complete UI  

### Technical Benefits
✅ **Proper event handling** - No form submission bugs  
✅ **No event bubbling issues** - Clean event propagation  
✅ **Works across all views** - Consistent behavior  
✅ **Accessible** - Clear context for all users  

## Testing Checklist

- [ ] Select text in Node view → see selected text in panel
- [ ] Select text in Linear view → see selected text in panel
- [ ] Select text in Modal → see selected text in panel
- [ ] Long text selection → see ellipsis after 2 lines
- [ ] Click X button once → panel closes immediately
- [ ] Test on mobile/tablet → one-tap close works
- [ ] Type in input field → selected text still visible above

## Edge Cases Handled

### Long Selections
- Text is truncated to 2 lines with `line-clamp-2`
- Ellipsis shows there's more text
- Full text is still used in the question

### Multiple Nodes (Linear View)
- Each node has its own TextSelectionHook instance
- Guard clause prevents interference: `if (panelIsVisible) return;`
- Only the node where text was selected shows its panel

### Button Type Issues
- All buttons now have `type="button"`
- Prevents accidental form submissions
- Works correctly in all contexts

## Visual Comparison: Before vs After

### Before
```
┌─────────────────────────────────┐
│                              [X]│
│  [Explain]  [Highlight]         │
│                                 │
│  Or ask a custom question:      │
│  [____________________] [Ask]   │
└─────────────────────────────────┘

❌ Can't see what text was selected
❌ Must click X button 5-10 times
❌ Buttons trigger form submissions
❌ Event bubbling causes conflicts
```

### After
```
┌─────────────────────────────────┐
│  Selected text:              [X]│
│  "speculative bioengineered"    │
├─────────────────────────────────┤
│  [Explain]  [Highlight]         │
├─────────────────────────────────┤
│  Or ask a custom question:      │
│  [____________________] [Ask]   │
└─────────────────────────────────┘

✅ Selected text always visible
✅ One click closes panel
✅ Buttons behave correctly
✅ Clean event handling
```

## Related Documentation

- `TEXT_SELECTION_COMPLETE_SUMMARY.md` - Full implementation details
- `SELECTION_PANEL_SIMPLE.md` - Modal behavior guide
- `ASK_ABOUT_SELECTION_ACTION.md` - New action documentation

## Future Enhancements

Potential improvements:
- Click selected text display to scroll to original location
- Highlight the selection with a different color in the display
- Show more context (surrounding sentences)
- Add "Copy" button next to selected text
- Support for selecting multiple fragments
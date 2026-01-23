# Text Selection Modal-Style UX Changes

## Overview

Updated the text selection actions panel to use a modal-style interaction pattern that provides a cleaner, more predictable UX when selecting text and asking questions.

## Visual Changes

### Before
```
┌─────────────────────────────────────┐
│  Selected Text                      │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ [Explain] [Highlight]       │   │
│  │ Or ask a custom question:   │   │
│  │ [________________] [Ask]    │   │
│  └─────────────────────────────┘   │
│                                     │
│  ❌ Issues:                         │
│  • Panel disappears when clicking   │
│    into input field                 │
│  • Complex auto-hide logic          │
│  • No clear way to dismiss          │
└─────────────────────────────────────┘
```

### After
```
┌─────────────────────────────────────┐
│  Selected Text                      │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ [Explain] [Highlight]    [X]│   │
│  │ Or ask a custom question:   │   │
│  │ [________________] [Ask]    │   │
│  └─────────────────────────────┘   │
│                                     │
│  ✅ Improvements:                   │
│  • Panel stays open                 │
│  • Clear close button               │
│  • Simple, predictable behavior     │
└─────────────────────────────────────┘
```

## Problem Solved

Previously, the selection actions panel would automatically hide when:
- Text selection was cleared
- Focus changed
- User clicked elsewhere

This caused issues when the "Ask a question" input field was added, because:
- Clicking into the input would clear the selection, triggering auto-hide logic
- Focus changes would compete with the input field needing focus
- Complex event handlers were fighting each other

### Solution: Modal-Style Overlay

The panel now behaves like a sticky tooltip:
- **Stays open** until user performs an action
- **No auto-hide logic at all** - completely predictable
- **Four ways to close:**
  1. Click the X close button (top-right corner)
  2. Click "Explain" button (performs action and closes)
  3. Click "Highlight" button (performs action and closes)
  4. Click "Ask" button (submits question and closes)

## Changes Made

### 1. JavaScript (`assets/js/text_selection_hook.js`)

**Removed:**
- `handleSelectionChange` event listener and all related logic
- `handleOutsideClick` event listener - no more outside click handling
- Escape key close functionality
- Complex timing delays and focus detection
- All auto-hide logic (~70 lines removed)

**Simplified:**
- `mounted()` - Only sets up text selection listeners
- `destroyed()` - Only cleans up text selection listeners
- Panel only closes when action buttons explicitly call `hideSelectionActions()`

**Added:**
- Close button click handler in `handleSelection()`
- Each action button (Explain, Highlight, Ask) calls `hideSelectionActions()` after performing its action

### 2. Templates

Updated three template files to add close button UI:

#### `lib/dialectic_web/live/node_comp.ex`
- Added close button (X icon) in top-right corner
- Added `pt-3` padding to action buttons to accommodate close button
- Panel is now `flex flex-col` for proper layout

#### `lib/dialectic_web/live/linear_graph_live.html.heex`
- Added close button to highlight-only panel
- Changed from inline-flex to `flex flex-col`
- Added `mt-4` to highlight button to clear close button area

#### `lib/dialectic_web/live/modal_comp.ex`
- Added close button to modal's selection panel
- Updated to `flex flex-col` layout
- Added `mt-4` to "Ask about selection" button

### 3. CSS (`assets/css/app.css`)

**Enhanced:**
- Better box shadow for modal feel (`0 4px 16px rgba(0, 0, 0, 0.12)`)
- Smooth transitions for opacity AND transform
- Transform animation when hiding (slides up slightly)
- Specific styling for close button (no shadow, subtle hover)

**Added:**
```css
.selection-actions.hidden {
    opacity: 0;
    transform: translateY(-4px);
    pointer-events: none;
}

.selection-actions .close-panel-btn {
    box-shadow: none;
}

.selection-actions .close-panel-btn:hover {
    background-color: rgba(0, 0, 0, 0.05);
}
```

## User Experience Flow

1. **User selects text** → Panel appears with smooth fade-in
2. **User can:**
   - Click "Explain" for quick explanation (closes panel)
   - Click "Highlight" to save highlight (closes panel)
   - Type custom question in input field (panel stays open)
   - Press Enter to submit question (closes panel)
   - Click X button to dismiss (closes panel)
3. **Panel stays open** for all interactions except explicit actions
4. **Zero auto-hide logic** - completely predictable behavior

## Benefits

✅ **Predictable behavior** - Panel only closes on explicit actions  
✅ **Input field usable** - No auto-hide interference at all  
✅ **Simpler code** - Removed ~70 lines of complex event handling  
✅ **Better mobile UX** - Panel stays put, no accidental dismissals  
✅ **Sticky tooltip pattern** - Stays until you do something with it  
✅ **Visual polish** - Better shadows and animations  

## Testing Checklist

- [ ] Select text → panel appears
- [ ] Click "Explain" → sends explanation request and closes
- [ ] Click "Highlight" → creates highlight and closes
- [ ] Type in custom question input → panel stays open
- [ ] Press Enter in input → submits question and closes
- [ ] Click X button → closes panel
- [ ] Click outside panel → panel stays open (no auto-hide)
- [ ] Click inside panel → stays open
- [ ] Clear text selection → panel stays open (no auto-hide)
- [ ] Click elsewhere in document → panel stays open (no auto-hide)
- [ ] Select text while panel is open → updates panel position (existing behavior)
- [ ] Test on mobile/touch devices

## Future Enhancements

Potential improvements to consider:
- Optionally add back Escape key to close (if users request it)
- Optionally add back outside click to close (if users request it)
- Add keyboard shortcuts (e.g., Cmd+/ to open with selection)
- Add animation when repositioning for new selection
- Add tooltip on close button
- Consider adding backdrop overlay for extra-clear modal behavior
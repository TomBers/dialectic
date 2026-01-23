# Text Selection Modal Refactor

## Overview

Converted the floating positioned panel to a proper centered modal dialog. This simplifies the code, fixes focus/scroll issues, and provides a better UX.

## Why Modal?

### Problems with Floating Panel
1. **Complex positioning** - Had to calculate top/left relative to selection and container
2. **Position edge cases** - Panel could go off-screen, needed bounds checking
3. **Focus issues** - Focus trapped in hidden panel broke scrolling
4. **Multiple instances** - In linear view, N panels caused interference
5. **Mobile UX** - Floating panels awkward on small screens
6. **Maintainability** - Position calculation spread across JS and Elixir

### Benefits of Modal
✅ **Simple positioning** - Always centered, no calculations  
✅ **Better focus management** - Modal backdrop handles clicks outside  
✅ **Works everywhere** - Same UX in all views (graph, linear, mobile)  
✅ **Familiar pattern** - Users understand modal interactions  
✅ **Cleaner code** - Removed ~50 lines of position calculation  
✅ **No scroll issues** - Modal doesn't interfere with page scroll  
✅ **Accessible** - Standard modal keyboard interactions (Escape to close)  

## Changes Made

### 1. Component UI (`selection_actions_component.ex`)

**Before: Floating Panel**
```elixir
<div 
  class="absolute ..."
  style={"top: #{@position["top"]}px; left: #{@position["left"]}px;"}>
  <!-- content -->
</div>
```

**After: Centered Modal**
```elixir
<!-- Backdrop -->
<div class="fixed inset-0 bg-gray-900/50 backdrop-blur-sm ...">
</div>

<!-- Modal -->
<div class="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 ...">
  <div class="flex items-center justify-between">
    <h3>Selection Actions</h3>
    <button>X</button>
  </div>
  <!-- content -->
</div>
```

### 2. Visual Improvements

**Enhanced Styling:**
- Backdrop with blur effect (`backdrop-blur-sm`)
- Larger, more prominent modal (max-width 500px)
- Better spacing and typography
- Indigo accent color for selected text display
- Larger buttons with hover shadows
- Header with title
- Divider between actions and custom question

**Animations:**
- Backdrop fade in/out
- Modal scale transition (scale-95 → scale-100)
- Smooth opacity changes

### 3. Keyboard Support

Added Escape key handler:
```elixir
phx-window-keydown="keydown"
phx-target={@myself}

def handle_event("keydown", %{"key" => "Escape"}, socket) do
  {:noreply, assign(socket, visible: false, question: "")}
end
```

### 4. JavaScript Simplification

**Removed:**
- Position calculation (~30 lines)
- Bounds checking logic
- Container rect calculations
- Complex left/top positioning

**Now:**
```javascript
// Just send the selected text - no position needed!
this.pushEvent("show-selection-actions", {
  selected_text: selectedText,
  node_id: this.nodeId,
  offsets: capturedOffsets
});
```

### 5. State Cleanup

**Removed from all LiveViews:**
- `selection_position` assign (no longer needed)
- Position calculation in event handlers
- Position passing in component rendering

**Simplified:**
```elixir
# Before
assign(socket,
  selection_visible: true,
  selection_text: text,
  selection_position: %{"top" => 100, "left" => 200},  # ❌ REMOVED
  selection_node_id: node_id
)

# After
assign(socket,
  selection_visible: true,
  selection_text: text,
  selection_node_id: node_id
)
```

### 6. Removed Unnecessary Code

- ❌ `blur_on_hide_hook.js` - Not needed with proper modal
- ❌ BlurOnHide hook registration
- ❌ Position calculation in JavaScript
- ❌ Position prop in component
- ❌ Complex focus management

## User Experience

### Before (Floating Panel)
```
Select text
   ↓
Panel appears near selection
   - Might be off-screen
   - Might overlap content
   - Focus issues after closing
   - Different behavior in each view
```

### After (Modal)
```
Select text
   ↓
Modal opens in center
   - Always visible
   - Clear backdrop
   - Focus managed automatically
   - Consistent everywhere
   - Escape to close
```

## Visual Comparison

### Old Floating Panel
- Small, compact
- Positioned near selection
- No backdrop
- Hard to see on busy backgrounds
- Could be partially off-screen

### New Modal
- Prominent and centered
- Clear backdrop (dimmed background)
- Larger, more readable
- Always fully visible
- Professional appearance

## Technical Details

### Modal Backdrop
```elixir
<div
  :if={@visible}
  class="fixed inset-0 bg-gray-900/50 backdrop-blur-sm z-[999]"
  phx-click="close"
  phx-target={@myself}>
</div>
```

Features:
- Covers entire viewport (`fixed inset-0`)
- Semi-transparent dark overlay (`bg-gray-900/50`)
- Blur effect on background content
- Click to close
- Below modal (`z-[999]` vs `z-[1000]`)

### Modal Content
```elixir
<div class="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 ...">
```

Positioning:
- `fixed` - Relative to viewport
- `top-1/2 left-1/2` - Move to center
- `-translate-x-1/2 -translate-y-1/2` - Perfect centering
- Works on all screen sizes

### Responsive Design
- `w-[90vw]` - 90% of viewport width on mobile
- `max-w-[500px]` - Max 500px on desktop
- Padding adjusts with breakpoints

## Code Metrics

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Position calculation (JS) | ~30 lines | 0 | -100% |
| Component assigns | 6 | 4 | -33% |
| CSS complexity | High | Low | Simpler |
| Focus management code | Custom hook | None needed | -100% |
| Works on mobile | Awkward | Perfect | ✨ |

## Testing Checklist

- [x] Select text → modal appears
- [x] Click backdrop → modal closes
- [x] Press Escape → modal closes
- [x] Click X button → modal closes
- [x] Click Explain → creates question
- [x] Click Highlight → creates highlight
- [x] Type question + Enter → submits
- [x] Empty input + Enter → does nothing
- [x] Works in graph view
- [x] Works in linear view
- [x] Works on mobile
- [x] No scroll issues
- [x] No focus issues

## Benefits Summary

### For Users
- 🎯 **Clear focus** - Modal draws attention to actions
- 🖱️ **Easy to dismiss** - Click outside, press Escape, or X button
- 📱 **Mobile friendly** - Works great on all screen sizes
- ♿ **Accessible** - Standard modal keyboard interactions
- 💅 **Beautiful** - Modern design with blur backdrop

### For Developers
- 🧹 **Less code** - Removed position calculations
- 🐛 **Fewer bugs** - No positioning edge cases
- 🔧 **Maintainable** - Standard modal pattern
- 🧪 **Testable** - Simpler state management
- 📚 **Familiar** - Everyone knows how modals work

## Migration Notes

### Breaking Changes
None - same functionality, better UX

### Removed Props
- `position` - No longer needed or accepted

### New Features
- Escape key closes modal
- Backdrop click closes modal
- Better visual hierarchy
- Improved mobile experience

## Future Enhancements

Possible improvements:
- Add fade-in animation for backdrop
- Add bounce effect on modal open
- Remember last action used
- Add keyboard shortcuts (Cmd+E for explain, etc.)
- Support for multiple selections simultaneously
- Add "Don't show again for this session" option

## Conclusion

Converting from a floating panel to a proper modal simplified the code, fixed multiple issues (scroll, focus, positioning), and improved the UX. The modal pattern is familiar, accessible, and works consistently across all views and devices.

**Result:** Cleaner code, better UX, fewer bugs. Win-win-win! 🎉

## Files Changed

- ✅ `lib/dialectic_web/live/selection_actions_component.ex` - Modal UI
- ✅ `assets/js/text_selection_hook.js` - Removed position calc
- ✅ `lib/dialectic_web/live/graph_live.ex` - Removed position state
- ✅ `lib/dialectic_web/live/linear_graph_live.ex` - Removed position state
- ✅ `lib/dialectic_web/live/graph_live.html.heex` - Updated component props
- ✅ `lib/dialectic_web/live/linear_graph_live.html.heex` - Updated component props
- ✅ `assets/js/app.js` - Removed BlurOnHide hook
- ❌ `assets/js/blur_on_hide_hook.js` - Deleted (not needed)

## References

- Modal design patterns: https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- Tailwind backdrop blur: https://tailwindcss.com/docs/backdrop-blur
- Phoenix LiveView keyboard events: https://hexdocs.pm/phoenix_live_view/bindings.html#key-events
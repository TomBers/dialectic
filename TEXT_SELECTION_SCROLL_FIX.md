# Text Selection Scroll Focus Fix

## Problem

After creating a highlight in the graph view, scrolling would stop working until the user clicked somewhere in the frame again.

## Root Cause

When the SelectionActionsComponent was visible and the user clicked the "Highlight" button:

1. The button received focus
2. The highlight was created
3. The component was hidden (set to `visible: false`)
4. **But focus remained on elements inside the hidden component**
5. The main scrollable content area couldn't receive scroll events
6. User had to manually click to restore focus

This is a common issue with modal/overlay components - they can trap focus even after being hidden.

## Solution

Created a `BlurOnHide` hook that:

1. Watches the `data-visible` attribute on the component
2. When component transitions from visible to hidden:
   - Blurs any focused element inside the component
   - Tries to restore focus to the scrollable parent
   - Falls back to focusing document.body

### Files Changed

**1. Component Template** (`lib/dialectic_web/live/selection_actions_component.ex`)
```elixir
<div
  id={"selection-actions-component-#{@id}"}
  phx-hook="BlurOnHide"
  data-visible={@visible}
  ...>
```

Added:
- `phx-hook="BlurOnHide"` - Registers the hook
- `data-visible={@visible}` - Tracks visibility state for hook

**2. New Hook** (`assets/js/blur_on_hide_hook.js`)

```javascript
const BlurOnHideHook = {
  mounted() {
    this.previousVisible = this.el.dataset.visible === "true";
  },

  updated() {
    const currentVisible = this.el.dataset.visible === "true";

    // If component just became hidden
    if (this.previousVisible && !currentVisible) {
      // Blur focused elements inside component
      const focusedElement = this.el.querySelector(":focus");
      if (focusedElement) {
        focusedElement.blur();
      }

      // Restore focus to scrollable parent
      const scrollableParent = this.el.closest('.overflow-y-auto, .overflow-auto');
      if (scrollableParent) {
        scrollableParent.focus();
      } else {
        document.body.focus();
      }
    }

    this.previousVisible = currentVisible;
  }
};
```

**3. Hook Registration** (`assets/js/app.js`)
```javascript
import BlurOnHideHook from "./blur_on_hide_hook.js";
// ...
hooks.BlurOnHide = BlurOnHideHook;
```

## How It Works

### Before Fix
```
1. User clicks "Highlight" button
2. Button has focus
3. Component sets visible: false
4. Component re-renders with opacity-0 and pointer-events-none
5. BUT focus is still on the button (or input inside component)
6. Scroll events go to focused element (component)
7. Scroll doesn't work ❌
```

### After Fix
```
1. User clicks "Highlight" button
2. Button has focus
3. Component sets visible: false
4. Component re-renders
5. BlurOnHide hook detects visibility change
6. Hook blurs all focused elements inside component
7. Hook focuses scrollable parent
8. Scroll events go to scrollable content
9. Scroll works! ✅
```

## Technical Details

### Hook Lifecycle

**mounted():**
- Called once when component first appears in DOM
- Stores initial visibility state

**updated():**
- Called every time component updates
- Checks if visibility changed from true → false
- If so, performs focus cleanup

### Focus Strategy

The hook tries three approaches in order:

1. **Blur focused element** - Remove focus from component internals
2. **Focus scrollable parent** - Give focus to nearest scrollable container
3. **Focus body** - Fallback if no scrollable parent found

### Why Not `autofocus`?

Using `autofocus` on the input is good for UX when the panel appears, but doesn't solve the problem when it disappears. We need explicit cleanup.

### Why Not `tabindex`?

Adding `tabindex="-1"` to scrollable containers would work, but:
- Changes tab order for keyboard navigation
- Affects accessibility
- Not semantic

The hook approach is cleaner and doesn't affect normal interaction.

## Testing

### Manual Test
1. Select text in graph view
2. Panel appears
3. Click "Highlight" button
4. Try to scroll immediately
5. Scroll should work ✅

### Without Fix
Scrolling wouldn't work until you clicked somewhere else in the content area.

### With Fix
Scrolling works immediately after highlight creation.

## Edge Cases Handled

### Multiple Focusable Elements
If the input has focus, it gets blurred. If a button has focus, it gets blurred. The hook finds any `:focus` element.

### No Scrollable Parent
If there's no scrollable parent (edge case), focus goes to `document.body` which allows default scroll behavior.

### Rapid Open/Close
The hook tracks `previousVisible` state, so rapid open/close cycles are handled correctly.

### Component Never Mounted
If the component is conditionally rendered and never mounted, the hook gracefully does nothing.

## Benefits

✅ **Better UX** - No awkward "scroll breaks after action"  
✅ **Automatic** - Works for all actions (Explain, Highlight, Ask)  
✅ **Accessible** - Doesn't break keyboard navigation  
✅ **Reusable** - Hook can be used on other modal components  
✅ **Clean** - No manual focus management in component code  

## Future Improvements

Could extend the hook to:
- Remember where focus was before opening component
- Restore focus to that exact element when closing
- Handle focus trapping for true modal behavior
- Add focus outline restoration

But current solution is sufficient for the use case.

## Related Issues

This is a common pattern with overlay components. Other places that might need similar fixes:
- Modal dialogs
- Dropdown menus
- Popovers
- Sidebars

Any component that can "trap" focus while visible should clean up focus when hidden.

## References

- MDN: Focus management - https://developer.mozilla.org/en-US/docs/Web/Accessibility/Keyboard-navigable_JavaScript_widgets
- Phoenix LiveView Hooks - https://hexdocs.pm/phoenix_live_view/js-interop.html#client-hooks
- ARIA focus management - https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
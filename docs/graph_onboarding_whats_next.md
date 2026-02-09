# “What’s Next” Panel (Graph Onboarding)

This guide describes the lightweight onboarding panel that appears the first time a user opens any graph during a browser session. The panel is designed to be unobtrusive and provide quick, actionable steps for first-time users.

---

## Goals

- Reduce first-time drop-off after graph creation or first link visit.
- Provide lightweight guidance without blocking the experience.
- Persist only for the browser session (no backend state).

---

## Behavior Overview

- The panel appears on the left side drawer above the node content.
- It is shown only once per browser session.
- Dismissing the panel sets a session flag and hides it.
- A call-to-action (“Try Related ideas”) can trigger an existing UI action.

---

## User Experience

**Panel copy (default):**
1. Click a node to focus it and read details on the left.
2. Use the toolbar below to branch, compare pros/cons, or explore related ideas.
3. Highlight text inside a node to create linked questions and notes.

**Actions:**
- **Dismiss**: Hides the panel and sets the session flag.
- **Read the guide**: Links to the `/intro/how` page.
- **Try “Related ideas”**: Attempts to click the related ideas action if present.

---

## Technical Notes

### Storage Strategy
The panel uses `sessionStorage` so the onboarding state is scoped to a single browser session:

- **Key**: `dialectic_whats_next_seen`
- **Value**: `"true"`

If the key is missing, the panel is shown. If present, it is hidden.

### Location
The panel is placed inside the left drawer and above the node content, so it is visible but does not block the graph or controls.

---

## Copy Guidelines

Keep the copy:
- **Short** (3 bullets or less)
- **Actionable** (describe what the user can do right now)
- **Directional** (point to UI elements, like the toolbar or highlights)

---

## Customization Ideas

If you want to tune the onboarding:

- **Change the CTA** to “Try Pros/Cons” or “Explore related ideas”.
- **Swap the bullets** based on new features.
- **Add a second panel** after a user performs their first action.

---

## Troubleshooting

If the panel never appears:
- Ensure the user hasn’t already set the session flag.
- Verify that the left drawer is visible.
- Confirm that the panel element exists in the graph template.

If the CTA doesn’t work:
- Make sure the “Related ideas” button has a recognizable selector.
- Consider wiring a dedicated data attribute to the action button.

---
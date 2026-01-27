# Testing Guide: Selection Actions Expansion

## Quick Start

After starting the server (`mix phx.server`), follow this guide to test the new multi-link highlight system.

---

## Prerequisites

1. **Database migrations applied:** ✅ (already done)
2. **Server running:** `mix phx.server`
3. **Logged in user:** Required for creating highlights
4. **Existing graph:** Navigate to any graph or create a new one

---

## Test Scenarios

### 1. Basic Highlight (No Links)

**Steps:**
1. Navigate to a graph with some content
2. Select some text in a node (drag to select)
3. Modal should appear with "Selection Actions"
4. Click the **"Highlight"** button (yellow)
5. Modal closes

**Expected Result:**
- Highlight created with no linked nodes
- Text is marked/highlighted (check right panel)
- No link icons appear next to the highlight

**Verify:**
- Open right panel (right sidebar)
- Find "Highlights" section
- Should see your selected text
- No colored icons next to it

---

### 2. Explain Action

**Steps:**
1. Select different text in a node
2. Click **"Explain"** button (blue)
3. Wait for AI response

**Expected Result:**
- Highlight created
- Question node created: "Please explain: [your text]"
- Answer node created with explanation
- Highlight linked to answer node with type `explain`

**Verify in Right Panel:**
- Highlight shows with ℹ️ gray info icon
- Hover over icon → tooltip says "Explanation: [node_id]"
- Graph should show new answer node

---

### 3. Pros & Cons Action

**Steps:**
1. Select text that represents a topic or claim
2. Click **"Pros & Cons"** button (green-to-red gradient)
3. Wait for AI to generate pros/cons

**Expected Result:**
- Highlight created (or reused if selecting same text)
- Branch node created
- Thesis node (Pro) created with green border
- Antithesis node (Con) created with red border
- Highlight has TWO links: one `pro`, one `con`

**Verify in Right Panel:**
- Highlight shows ⬆️ green arrow AND ⬇️ red arrow icons
- Hover over each icon to see which node it links to
- Graph shows green "Pro" and red "Con" nodes

---

### 4. Related Ideas Action

**Steps:**
1. Select text about a concept
2. Click **"Related Ideas"** button (orange)
3. Wait for AI response

**Expected Result:**
- Highlight created
- Ideas node created with orange border
- Node contains related concepts
- Highlight linked with type `related_idea`

**Verify in Right Panel:**
- Highlight shows 💡 orange lightbulb icon
- Hover → tooltip says "Related Idea: [node_id]"
- Graph shows orange "Related Ideas" node

---

### 5. Custom Question

**Steps:**
1. Select text
2. Type a question in the textarea at bottom of modal
   - Example: "What are the implications of this?"
3. Press Enter or click **"Ask"** button

**Expected Result:**
- Highlight created
- Question node created with your custom question
- Answer node created
- Highlight linked with type `question`

**Verify in Right Panel:**
- Highlight shows ❓ blue question icon
- Count shows if multiple questions exist

---

### 6. Multiple Links on Same Highlight

**Important Test:** This is the new capability!

**Steps:**
1. Select the EXACT same text you used in Test #2 (Explain)
2. Modal should appear
3. Notice the **"Explain"** button now says **"View Explanation"**
4. Click **"Pros & Cons"** button (different action)
5. Wait for pros/cons to generate

**Expected Result:**
- Same highlight is reused (not creating duplicate)
- New links added for `pro` and `con`
- Highlight now has 3 icons: ℹ️ ⬆️ ⬇️

**Verify in Right Panel:**
- Single highlight entry with multiple icons
- Should see: gray info + green arrow + red arrow
- Each icon links to different node

---

### 7. Multiple Questions on Same Highlight

**Steps:**
1. Select text that already has links
2. Ask a custom question (e.g., "Why is this important?")
3. Modal closes, nodes created
4. Select THE SAME text again
5. Ask ANOTHER question (e.g., "What are alternatives?")

**Expected Result:**
- Same highlight reused
- Multiple `question` type links created
- Counter appears: "2 question(s) linked"

**Verify in Right Panel:**
- Highlight shows multiple ❓ icons OR count indicator
- All questions link to different answer nodes

---

### 8. Button State Changes

**Steps:**
1. Select fresh text (no existing highlight)
2. Observe button labels:
   - "Explain" (not "View Explanation")
   - "Pros & Cons" (not "View Pros/Cons")
   - "Related Ideas" (not "View Ideas")
3. Create an explanation
4. Select THE SAME text again
5. Observe button now says: **"View Explanation"**

**Expected Result:**
- Buttons dynamically change based on existing links
- Shows "View [Type]" when link exists
- Shows "Create [Type]" when link doesn't exist

---

### 9. Node Deletion & Link Cleanup

**Steps:**
1. Create a highlight with links (e.g., Pros & Cons)
2. Note the node IDs from the icons
3. Delete one of the linked nodes from the graph
4. Refresh or check right panel

**Expected Result:**
- Link automatically removed (cascade delete)
- Icon for that link disappears
- Other links remain intact
- Highlight itself stays (only link deleted)

---

### 10. Highlight Icons & Tooltips

**Steps:**
1. Create a highlight with multiple link types
2. Open right panel → Highlights section
3. Find your highlight
4. Observe the icons displayed
5. Hover over each icon

**Expected Result:**
- Icons are color-coded by type:
  - ℹ️ Gray (explain)
  - ❓ Blue (question)
  - ⬆️ Green (pro)
  - ⬇️ Red (con)
  - 💡 Orange (related idea)
  - 🔍 Cyan (deep dive)
- Tooltip shows: "[Type]: [node_id]"
- Icons appear after node ID

---

### 11. Linear View (Read-Only)

**Steps:**
1. Click "Linear View" button (top left)
2. Select some text
3. Modal appears

**Expected Result:**
- Can only create **"Highlight"** (yellow button)
- Other action buttons are **disabled** (grayed out)
- Custom question form is disabled
- Message may appear about switching to Graph View for full features

**Verify:**
- Highlight created successfully
- No nodes created (read-only mode)
- Switching back to Graph View shows the highlight

---

### 12. Edge Cases

#### A. Overlapping Text Selections

**Test:** Select "artificial intelligence" → create highlight → select "artificial" (subset) → create another highlight

**Expected:** Both highlights can coexist (overlap validation removed)

#### B. Permission Check

**Test:** Try creating highlights without being logged in

**Expected:** Login modal appears

#### C. Locked Graph

**Test:** Try selection actions on a locked/read-only graph

**Expected:** Error flash: "This graph is locked"

#### D. Empty Selection

**Test:** Click in text without selecting anything

**Expected:** Modal doesn't appear (no selection event)

---

## Debugging

### Check Database

```bash
mix ecto.query "SELECT * FROM highlight_links;"
```

Should show records with:
- `highlight_id`
- `node_id`
- `link_type` (explain, question, pro, con, related_idea, deep_dive)

### Check Console

Browser console should show:
- `selection:show` event firing when text selected
- No JavaScript errors
- Component updating without page refresh

### Check LiveView

In browser console:
```javascript
// Check if hook is mounted
window.liveSocket.getHookCallbacks("SelectionActions")
```

---

## Known Issues / Future Work

- [ ] Clicking link icon doesn't navigate to node yet (Phase 2)
- [ ] No "unlink" button yet (Phase 4)
- [ ] Deep dive action not yet integrated (Phase 5)
- [ ] Multiple "View" buttons don't navigate (just create for now)

---

## Success Criteria

✅ **Phase 1 Complete** if:
- All 12 test scenarios pass
- Highlights can have multiple links
- Icons appear correctly in right panel
- No compilation errors
- No runtime errors in browser console
- Database shows links in `highlight_links` table

---

## Quick Visual Check

After running tests, your right panel should look like:

```
Highlights (3)
  "artificial intelligence" 💡⬆️⬇️
  Node: node_123 • [3 colored icons]
  
  "quantum computing" ℹ️❓❓
  Node: node_456 • [3 colored icons]
  
  "neural networks" ⬆️⬇️
  Node: node_789 • [2 colored icons]
```

Each highlight shows:
1. Selected text (quoted)
2. Node ID
3. Separator (•)
4. Colored link type icons

---

## Troubleshooting

### Modal doesn't appear
- Check browser console for JS errors
- Verify `SelectionActions` hook is registered in `app.js`
- Check that component ID matches in template

### Icons don't show
- Verify links were created in database
- Check that `highlights` are loaded with `.links` preloaded
- Verify `link_type_icon/1` functions exist

### Buttons stay disabled
- Check `@can_edit` is true
- Verify not in locked graph
- Check user is logged in (`@current_user` not nil)

### Wrong button states
- Check `get_highlight_for_selection` query works
- Verify offsets match exactly (start/end)
- Check component state updates on "show" event

---

## Report Issues

If tests fail:
1. Note which scenario
2. Check browser console for errors
3. Check server logs for Elixir errors
4. Verify database migrations ran
5. Try hard refresh (Cmd+Shift+R / Ctrl+Shift+R)

Good luck testing! 🚀
# Feature Testing Checklist

This document provides step-by-step testing instructions for all 10 implemented customer feedback features.

## Prerequisites

1. Run database migration:
   ```bash
   mix ecto.migrate
   ```

2. Start the Phoenix server:
   ```bash
   mix phx.server
   ```

3. Navigate to `http://localhost:4000` and create/open a graph

---

## 🟢 Tier 1 — Quick Wins

### ✅ Ticket 1 — Auto-Expand Ask Textarea for Long Input

**Test Steps:**
1. Navigate to any graph
2. Click in the "Ask a question" input at the bottom
3. Type or paste a long question (multiple lines of text)

**Expected Behavior:**
- Textarea expands vertically as you type
- Maximum height caps at ~6 lines
- Scrollbar appears when exceeding max height
- Submit button position adjusts with height
- Textarea shrinks back when content deleted

**Pass Criteria:** ✅ Textarea expands smoothly without layout breaks

---

### ✅ Ticket 2 — Allow Deleting User-Created Nodes

**Test Steps:**
1. Create a new comment node (toggle to "Comment" mode and post)
2. Select the node you just created
3. Look for the trash/delete button in the action toolbar

**Expected Behavior:**
- Delete button appears in action toolbar
- Hover shows tooltip "Delete this node"
- Click shows confirmation dialog
- After confirming, node is deleted
- Cannot delete nodes with children (button disabled with tooltip explaining why)
- Cannot delete other users' nodes (button disabled)

**Pass Criteria:** ✅ Can delete own nodes, proper restrictions apply

---

### ✅ Ticket 3 — Prevent Duplicate Highlights on Same Span

**Test Steps:**
1. Open any graph with a node containing text
2. Select some text and click "Highlight"
3. Try to highlight the exact same text again

**Expected Behavior:**
- First highlight creates successfully
- Second attempt does NOT create duplicate
- Instead, existing highlight is scrolled into view
- Orange pulse effect appears on existing highlight
- No error message shown

**Pass Criteria:** ✅ No duplicates created, existing highlight focused

---

### ✅ Ticket 4 — Make Node Colors More Discoverable

**Test Steps:**
1. Open any graph
2. Click the panel toggle on the right side to open settings panel
3. Scroll through the right panel sections

**Expected Behavior:**
- "Node Colors" section appears above "Keyboard Shortcuts"
- Shows 7+ node types with:
  - Colored dot (matching graph colors)
  - Human-readable label (e.g., "Pro / Supporting Point")
  - Brief description
- Colors match what's shown in graph visualization

**Pass Criteria:** ✅ Clear color legend with all node types explained

---

## 🟡 Tier 2 — UX Wiring & State Coordination

### ✅ Ticket 5 — Always Indicate the Current / Active Node

**Test Steps:**
1. Open any graph with multiple nodes
2. Click different nodes on the graph
3. Observe the area above the "Ask a question" input

**Expected Behavior:**
- Shows "Active node: [NODE_ID]" indicator
- Blue gradient background with pulsing dot
- Node ID changes when clicking different nodes
- Clicking the node ID in the indicator focuses that node on graph
- Indicator only shows when a node is selected

**Pass Criteria:** ✅ Always clear which node is active

---

### ✅ Ticket 6 — Double-Click Node Opens Reader Panel Reliably

**Test Steps:**
1. Close the left reader panel if open
2. Double-click any node on the graph
3. Try on different nodes

**Expected Behavior:**
- Reader panel opens on double-click
- Works consistently across all nodes
- Does not interfere with single-click selection
- Works on both desktop (mouse) and touch devices

**Pass Criteria:** ✅ Double-click reliably opens reader panel

---

### ✅ Ticket 7 — Auto-Open Newly Created Answer in Reader

**Test Steps:**
1. Close the reader panel
2. Type a question in the ask box
3. Click "Ask" to submit

**Expected Behavior:**
- Reader panel opens automatically
- Shows the new answer node as it streams
- No need to manually click the node or open panel
- Works for both "Ask" and text selection "Explain"

**Pass Criteria:** ✅ Panel auto-opens to show new answers

---

### ✅ Ticket 8 — Show Full Thread Automatically When Selecting a Node

**Test Steps:**
1. Navigate to a graph with nested conversations
2. Click a node that has parent nodes (not the root)
3. Open the reader panel to see the node content

**Expected Behavior:**
- "Thread (X ancestors)" section appears at top of reader
- Thread is expanded by default if node has parents
- Shows numbered list of all ancestor nodes
- Each ancestor shows:
  - Node type badge with color
  - Node ID (clickable)
  - Content preview (truncated)
- Clicking ancestor ID navigates to that node
- Can collapse/expand thread with arrow button

**Pass Criteria:** ✅ Full conversation thread visible and navigable

---

## 🟠 Tier 3 — Semantic UX & Interaction Design

### ✅ Ticket 9 — Allow Custom Question When Asking About a Highlight Selection

**Test Steps:**
1. Open a node with text content
2. Select some text
3. Three buttons appear: "Ask Custom Question", "Explain", "Highlight"

**Testing "Ask Custom Question":**
1. Click "Ask Custom Question" button
2. A text input should appear
3. Type a custom question about the selection
4. Click "Ask" or press Cmd/Ctrl+Enter

**Expected Behavior:**
- Custom input appears with textarea
- Three options: "Ask", "Just Explain", "Cancel"
- Custom question includes context about selected text
- Creates node with your custom question + selection context
- "Just Explain" gives default explanation
- "Cancel" closes input
- Escape key also cancels

**Testing "Explain" Quick Action:**
1. Select text
2. Click "Explain" button directly

**Expected Behavior:**
- Immediately creates explanation question (no input shown)
- Faster workflow for default behavior

**Pass Criteria:** ✅ Both custom and quick workflows function

---

### ✅ Ticket 10 — Visually Link Highlight Span to Spawned Branch

**Test Steps:**
1. Select text and click "Explain" or "Ask Custom Question"
2. New question node is created
3. Inspect node data (currently backend only)

**Expected Behavior:**
- `source_highlight_id` field stored on question node
- Contains the highlighted text as context
- Data persists with graph saves
- Foundation for future visual linking features

**Backend Verification:**
```elixir
# In IEx console:
node = GraphManager.find_node_by_id("graph_id", "node_id")
node.source_highlight_id  # Should contain highlight text
```

**Pass Criteria:** ✅ Data layer properly stores highlight associations

**Note:** Visual hover effects (node→highlight bidirectional highlighting) are future enhancements. The data infrastructure is complete.

---

## Edge Cases to Test

### Auto-Expand Textarea
- [ ] Very long single line (should wrap and expand)
- [ ] Paste multi-line content
- [ ] Delete content (should shrink)
- [ ] Clear all content (should return to min height)

### Duplicate Highlights
- [ ] Same text, different nodes
- [ ] Overlapping but not identical spans
- [ ] Exact same span on same node

### Thread View
- [ ] Node with no parents (no thread shown)
- [ ] Node with 1 parent
- [ ] Node with deep ancestry (5+ levels)
- [ ] Circular references (if possible)

### Delete Node
- [ ] Delete as author
- [ ] Try delete as non-author
- [ ] Try delete with children
- [ ] Try delete on locked graph

### Custom Questions
- [ ] Empty custom question (should block submit)
- [ ] Very long custom question
- [ ] Special characters in question
- [ ] Cancel without submitting

---

## Performance Tests

1. **Large Highlight Count:** Create 20+ highlights on one node
2. **Deep Thread:** Navigate node with 10+ ancestors
3. **Long Text in Textarea:** Paste 1000+ words
4. **Rapid Node Switching:** Click through many nodes quickly

---

## Browser Compatibility

Test critical features on:
- [ ] Chrome/Edge (latest)
- [ ] Firefox (latest)
- [ ] Safari (latest)
- [ ] Mobile Safari (iOS)
- [ ] Mobile Chrome (Android)

---

## Regression Tests

Verify existing features still work:
- [ ] Basic node creation (Ask/Comment)
- [ ] Graph navigation (arrows, click)
- [ ] Pros/Cons branching
- [ ] Deep Dive
- [ ] Related Ideas
- [ ] Graph search
- [ ] Note starring
- [ ] Graph sharing
- [ ] Linear view
- [ ] Export functions

---

## Known Limitations

1. **Highlight Visual Linking:** Hover effects between highlights and nodes are not yet implemented (data layer only)
2. **Thread Performance:** Very deep ancestry (20+ levels) may cause UI slowdown
3. **Mobile Double-Click:** May require tuning tap detection timing on some devices

---

## Bug Reporting Template

If you find issues, report with:

```
**Feature:** [Ticket number and name]
**Steps to Reproduce:** 
1. 
2. 
3. 

**Expected:** 
**Actual:** 
**Browser/Device:** 
**Screenshots:** [if applicable]
```

---

## Success Criteria Summary

All 10 features should:
- ✅ Function without errors
- ✅ Not break existing functionality
- ✅ Work across modern browsers
- ✅ Provide clear user feedback
- ✅ Match design specifications
- ✅ Be discoverable without documentation

**Overall Implementation: 9/10 features fully functional, 1/10 data layer complete**
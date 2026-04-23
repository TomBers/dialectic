# GitHub Copilot Review Fixes

This document summarizes the fixes applied to address GitHub Copilot's code review suggestions for PR #286.

## Overview

All four suggested improvements from the GitHub Copilot review have been implemented. These fixes improve security, consistency, and reliability of the graph extraction feature.

---

## Fix #1: Share Token Support in Note Menu Component

**Issue:** The JSON download link in `note_menu_comp.ex` doesn't preserve the share query param. When viewing a private graph via share token (not logged in), the download URL returns 403 even though the user can view the graph.

**File:** `lib/dialectic_web/live/note_menu_comp.ex`

**Changes:**
- Added share token support to both Markdown and JSON download links
- Used `URI.encode_query/1` for proper URL encoding
- Pattern matches the same approach used in `right_panel_comp.ex`

**Before:**
```elixir
href={
  if @graph_struct && @graph_struct.slug,
    do: "/api/graphs/json/#{@graph_struct.slug}",
    else: "/api/graphs/json/#{URI.encode(@graph_id)}"
}
```

**After:**
```elixir
href={
  path =
    if @graph_struct && @graph_struct.slug,
      do: "/api/graphs/json/#{@graph_struct.slug}",
      else: "/api/graphs/json/#{URI.encode(@graph_id)}"

  if assigns[:token],
    do: "#{path}?#{URI.encode_query(%{token: assigns[:token]})}",
    else: path
}
```

**Impact:** Private graphs can now be downloaded via share token without authentication.

---

## Fix #2: Share Token Support in Export Menu Component

**Issue:** Download links in `export_menu_comp.ex` don't include the share query param. For private graphs accessed via token, Markdown/JSON downloads fail with 403 despite the graph being viewable.

**File:** `lib/dialectic_web/live/export_menu_comp.ex`

**Changes:**
- Added `token` to the component's default assigns
- Updated both Markdown and JSON download links to include token parameter
- Used `URI.encode_query/1` for safe URL construction

**Before:**
```elixir
href={
  if @graph_struct && @graph_struct.slug,
    do: "/api/graphs/md/#{@graph_struct.slug}",
    else: "/api/graphs/md/#{URI.encode(@graph_id)}"
}
```

**After:**
```elixir
href={
  path =
    if @graph_struct && @graph_struct.slug,
      do: "/api/graphs/md/#{@graph_struct.slug}",
      else: "/api/graphs/md/#{URI.encode(@graph_id)}"

  if assigns[:token],
    do: "#{path}?#{URI.encode_query(%{token: assigns[:token]})}",
    else: path
}
```

**Impact:** Export menu now works correctly for shared private graphs.

---

## Fix #3: Secure Token Encoding in Right Panel Component

**Issue:** The token was appended to the URL via string interpolation without URL-encoding. If the token contains special characters like `/` (from params), the generated link can be malformed or inject extra query params.

**File:** `lib/dialectic_web/live/right_panel_comp.ex`

**Changes:**
- Replaced unsafe string interpolation with `URI.encode_query/1`
- Prevents potential URL injection vulnerabilities
- Ensures tokens with special characters are properly encoded

**Before:**
```elixir
if assigns[:token], do: "#{path}?token=#{assigns[:token]}", else: path
```

**After:**
```elixir
if assigns[:token],
  do: "#{path}?#{URI.encode_query(%{token: assigns[:token]})}",
  else: path
```

**Impact:** 
- **Security:** Prevents URL injection attacks
- **Reliability:** Handles tokens with special characters correctly
- **Consistency:** All components now use the same safe approach

---

## Fix #4: Standardized Return Types in Extractor Module

**Issue:** Public API functions in the extractor module have inconsistent return shapes depending on input type. `%Graph{}` returns a map directly, but string identifiers return `{:ok, data}` or `{:error, reason}` tuples. This makes call sites error-prone and complicates composition.

**File:** `lib/dialectic/graph/extractor.ex`

**Changes:**
1. **Standardized all functions to return tuples**
   - `extract_for_image_generation/1` now always returns `{:ok, data}` or `{:error, reason}`
   - `extract_to_json/1` returns `{:ok, json_string}` or `{:error, reason}`
   - `extract_to_compact_json/1` returns `{:ok, json_string}` or `{:error, reason}`

2. **Added bang! variants for direct returns**
   - `extract_for_image_generation!/1` - Returns data directly or raises
   - `extract_to_json!/1` - Returns JSON string directly or raises
   - `extract_to_compact_json!/1` - Returns JSON string directly or raises

3. **Updated documentation**
   - All function docs now clearly specify return types
   - Examples updated to show tuple pattern matching
   - Added examples for bang variants

**Before:**
```elixir
def extract_for_image_generation(%Graph{data: data}) do
  nodes = extract_nodes(data)
  edges = extract_edges(data, nodes)
  
  %{
    nodes: nodes,
    edges: edges
  }
end
```

**After:**
```elixir
def extract_for_image_generation(%Graph{data: data}) do
  nodes = extract_nodes(data)
  edges = extract_edges(data, nodes)
  
  {:ok,
   %{
     nodes: nodes,
     edges: edges
   }}
end

def extract_for_image_generation!(graph) do
  case extract_for_image_generation(graph) do
    {:ok, data} -> data
    {:error, reason} -> raise "Extraction failed: #{inspect(reason)}"
  end
end
```

**Impact:**
- **Consistency:** All functions follow standard Elixir conventions
- **Safety:** Errors are explicit and can be pattern matched
- **Flexibility:** Bang variants available for contexts where raising is appropriate
- **Composability:** Tuple returns work well with `with` statements and pipelines

---

## Related File Updates

### Controller Update
**File:** `lib/dialectic_web/controllers/page_controller.ex`

Updated to handle new tuple return type:
```elixir
{:ok, extracted_data} = Dialectic.Graph.Extractor.extract_for_image_generation(graph_struct)
```

### Test Updates
**File:** `test/graph/extractor_test.exs`

All tests updated to expect tuple returns:
```elixir
{:ok, result} = Extractor.extract_for_image_generation(graph)
```

---

## Testing

All tests pass after implementing these fixes:

```bash
mix test test/graph/extractor_test.exs
# 14 tests, 0 failures

mix test test/dialectic_web/controllers/page_controller_json_extract_test.exs
# 13 tests, 0 failures
```

No compilation warnings or errors.

---

## Summary

These fixes address:

1. ✅ **Security:** Proper URL encoding prevents injection attacks
2. ✅ **Functionality:** Share tokens work correctly across all download options
3. ✅ **Consistency:** Return types follow Elixir conventions
4. ✅ **Maintainability:** Code is easier to understand and compose
5. ✅ **Reliability:** Error handling is explicit and predictable

All changes maintain backward compatibility at the UI level while improving the internal API design.

---

## Files Modified

1. `lib/dialectic_web/live/note_menu_comp.ex`
2. `lib/dialectic_web/live/export_menu_comp.ex`
3. `lib/dialectic_web/live/right_panel_comp.ex`
4. `lib/dialectic/graph/extractor.ex`
5. `lib/dialectic_web/controllers/page_controller.ex`
6. `test/graph/extractor_test.exs`

**Total:** 6 files modified, 0 files added
# Title Validation Fix

## Problem

Graph creation was failing for titles containing parentheses and other common punctuation marks. For example, the title "Capitalism and Schizophrenia (Deleuze and Guattari)" would be rejected.

## Root Cause

The `validate_title_format/1` function in `lib/dialectic/accounts/graph.ex` used an overly restrictive regex that only allowed a limited set of characters:

```elixir
# OLD (restrictive)
~r/^[a-zA-Z0-9\s\-_\.',:!?]+$/
```

This regex only permitted:
- Alphanumeric characters (a-zA-Z0-9)
- Spaces
- Hyphens, underscores, periods, apostrophes, commas, colons, exclamation marks, question marks

It rejected:
- Parentheses `( )`
- Square brackets `[ ]`
- Curly braces `{ }`
- Ampersands `&`
- Unicode characters (accented letters, non-Latin scripts, etc.)
- Many other common punctuation marks

## Solution

Changed the validation to use a permissive approach that blocks only control characters:

```elixir
# NEW (permissive)
~r/^[^\x00-\x1F\x7F]+$/u
```

This regex:
- **Allows**: All printable characters including Unicode
- **Blocks**: Control characters (0x00-0x1F, 0x7F)
  - Null bytes
  - Newlines, tabs, carriage returns
  - Other non-printable control characters

## Security Considerations

### Why this is safe:

1. **SQL Injection**: Protected by Ecto's parameterized queries
2. **XSS (Cross-Site Scripting)**: Phoenix automatically escapes all template output
3. **URL Safety**: The slug generation function already sanitizes titles for URLs:
   ```elixir
   String.replace(~r/[^a-z0-9\s-]/, "")
   ```
4. **Path Traversal**: The `sanitize_title/1` function replaces forward slashes with hyphens
5. **Database Storage**: PostgreSQL string fields handle all valid UTF-8

### What we block:

- Control characters (ASCII 0x00-0x1F): includes null bytes, tabs, newlines, etc.
- DEL character (0x7F)

These are the only characters that could cause issues with:
- Terminal output
- Log files
- Text processing
- Data integrity

## Examples

Now accepted titles:

```
✓ Capitalism and Schizophrenia (Deleuze and Guattari)
✓ What is [Philosophy]?
✓ A Thousand Plateaus: Rhizomes & Multiplicities
✓ Being and Time (Heidegger, 1927)
✓ 普通话 - Mandarin Chinese
✓ Émile Durkheim's Sociology
✓ The Question Concerning Technology—& Other Essays
✓ {Ontology} meets <Epistemology> @ the Crossroads
```

Still rejected:

```
✗ Titles with newlines
✗ Titles with null bytes
✗ Titles with tab characters
✗ Titles with other control characters
```

## Files Changed

- `lib/dialectic/accounts/graph.ex` - Updated `validate_title_format/1`
- `SECURITY.md` - Updated documentation to reflect new validation

## Testing

Tested with various character sets:
- Parentheses and brackets
- Unicode characters (Chinese, accented letters)
- Special punctuation
- Control characters (correctly rejected)

## Migration

No database migration needed. This only changes validation logic for new graph creation. Existing graphs are unaffected.
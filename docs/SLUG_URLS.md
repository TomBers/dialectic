# Slug-Based URLs Documentation

## Overview

This document describes the slug-based URL system implemented to solve the social sharing problem with long, unfriendly URLs.

## The Problem

Previously, the application used graph titles as the primary key and URL identifier, which created several issues:

1. **Long URLs**: Titles like "Considering the cyclical nature of societal anxieties, what undercurrents from the anxieties of the late Roman Empire might we see echoed in" resulted in extremely long, URL-encoded paths
2. **Poor Social Sharing**: Twitter/LinkedIn shares became unreadable with long URLs and long titles combined
3. **User Experience**: URLs were hard to share verbally or remember

**Example of old URL:**
```
http://localhost:4000/Considering%20the%20cyclical%20nature%20of%20societal%20anxieties,%20what%20undercurrents%20from%20the%20anxieties%20of%20the%20late%20Roman%20Empire%20might%20we%20see%20echoed%20in
```

## The Solution

We implemented a slug-based URL system that:

1. Generates short, URL-friendly slugs for each graph
2. Uses the format: `/g/{slug}` for new-style URLs
3. Maintains backward compatibility with title-based URLs
4. Automatically applies to all new graphs created

**Example of new URL:**
```
http://localhost:4000/g/roman-empire-anxieties-k3m9
```

## Implementation Details

### Database Changes

- **Migration**: `20260108110254_add_slug_to_graphs.exs`
- **New Field**: `slug` (string, unique, nullable for backward compatibility)
- **Index**: Unique index on `slug` column for fast lookups

### Slug Generation

Slugs are generated automatically when graphs are created using the following algorithm:

1. Take the first 50 characters of the title
2. Convert to lowercase
3. Remove special characters (keep only a-z, 0-9, spaces, hyphens)
4. Replace spaces with hyphens
5. Add a 6-character random suffix for uniqueness (e.g., `a1b2c3`)

**Example transformations:**
- `"The Republic - Plato"` → `"the-republic-plato-7525e8"`
- `"What is consciousness?"` → `"what-is-consciousness-3f9a2b"`
- `"test"` → `"test-0642a3"`

### Router Changes

New routes with `/g/` prefix for slug-based URLs:

```elixir
# New slug-based routes (preferred)
live "/g/:graph_name", GraphLive
live "/g/:graph_name/linear", LinearGraphLive
live "/g/:graph_name/story/:node_id", StoryLive

# Legacy title-based routes (backward compatibility)
live "/:graph_name", GraphLive
live "/:graph_name/linear", LinearGraphLive
live "/:graph_name/story/:node_id", StoryLive
```

### Backward Compatibility

The system maintains full backward compatibility:

1. **Lookup Strategy**: When a URL is accessed, the system tries:
   - First: Look up by slug
   - Fallback: Look up by title (for old URLs)

2. **Function**: `Dialectic.DbActions.Graphs.get_graph_by_slug_or_title/1`

3. **Old URLs Still Work**: All existing title-based URLs continue to function

### Helper Functions

New helper module `DialecticWeb.GraphPathHelper` provides functions for generating graph URLs:

```elixir
# Basic graph path
graph_path(graph) 
# => "/g/my-slug-abc123"

# With node parameter
graph_path(graph, "5") 
# => "/g/my-slug-abc123?node=5"

# Linear view
graph_linear_path(graph) 
# => "/g/my-slug-abc123/linear"

# With node in linear view
graph_linear_path(graph, "5") 
# => "/g/my-slug-abc123/linear?node_id=5"

# Story view
graph_story_path(graph, "5") 
# => "/g/my-slug-abc123/story/5"
```

These helpers are automatically available in all LiveViews, LiveComponents, and templates via `use DialecticWeb, :live_view` or `:live_component`.

### Social Sharing Improvements

The share modal (`share_modal_comp.ex`) now generates clean URLs:

**Before:**
```
Check out this map on MuDG: Considering the cyclical nature of societal anxieties, what undercurrents from the anxieties of the late Roman Empire might we see echoed in http://localhost:4000/Considering%20the%20cyclical%20nature...
```

**After:**
```
Check out this map on MuDG: Considering the cyclical nature of societal anxieties, what undercurrents from the anxieties of the late Roman Empire might we see echoed in http://localhost:4000/g/roman-empire-anxieties-k3m9
```

## Backfilling Existing Graphs

For existing graphs without slugs, run the backfill task:

```bash
mix backfill_graph_slugs
```

This task:
- Finds all graphs without a slug
- Generates a unique slug for each
- Updates the database
- Is safe to run multiple times (only updates graphs without slugs)

**Example output:**
```
Starting graph slug backfill...
Found 200 graphs without slugs. Generating...
[1/200] ✓ Generated slug 'the-republic-plato-7525e8' for 'The Republic - Plato'
[2/200] ✓ Generated slug 'german-idealism-c07d51' for 'German Idealism'
...
==================================================
Backfill complete!
✓ Success: 200
==================================================
```

## Files Modified/Created

### New Files
- `lib/dialectic_web/graph_path_helper.ex` - URL generation helpers
- `lib/mix/tasks/backfill_graph_slugs.ex` - Backfill task
- `priv/repo/migrations/20260108110254_add_slug_to_graphs.exs` - Database migration

### Modified Files
- `lib/dialectic/accounts/graph.ex` - Added slug field and validation
- `lib/dialectic/db_actions/graphs.ex` - Added slug generation and lookup functions
- `lib/dialectic_web/router.ex` - Added `/g/` routes
- `lib/dialectic_web.ex` - Imported GraphPathHelper
- `lib/dialectic_web/live/graph_live.ex` - Updated to use slug_or_title lookup
- `lib/dialectic_web/live/linear_graph_live.ex` - Updated to use slug_or_title lookup
- `lib/dialectic_web/live/story_live.ex` - Updated to use slug_or_title lookup
- `lib/dialectic_web/live/share_modal_comp.ex` - Updated share_url to use slugs

## Testing

After implementation, verify:

1. **New Graphs**: Create a new graph and verify it has a slug
2. **New URLs**: Access via `/g/{slug}` format
3. **Old URLs**: Verify existing title-based URLs still work
4. **Social Sharing**: Check that share links use the short slug format
5. **Navigation**: Test all internal links (linear view, story view, etc.)

## Future Improvements

Potential enhancements:

1. **Custom Slugs**: Allow users to customize their graph slug
2. **Slug History**: Track slug changes if titles are updated
3. **Vanity URLs**: Support user-defined vanity URLs
4. **Analytics**: Track which URL format is used more often
5. **Redirects**: Add automatic redirects from old URLs to new slug URLs

## FAQ

**Q: What happens to old URLs?**  
A: They continue to work! The system checks both slug and title when looking up graphs.

**Q: Can two graphs have the same slug?**  
A: No. The slug field has a unique constraint, and the generation algorithm adds a random suffix to ensure uniqueness.

**Q: What if a graph doesn't have a slug?**  
A: The system falls back to using the title-based URL. Run `mix backfill_graph_slugs` to add slugs to all existing graphs.

**Q: Can I change a graph's slug?**  
A: Currently, slugs are generated once at creation and don't change. Custom slug editing could be added in the future.

**Q: How do I use slugs in my templates?**  
A: Use the `graph_path/2` helper function instead of manually building URLs:
```heex
<.link navigate={graph_path(@graph_struct)}>View Graph</.link>
```

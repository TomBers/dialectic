# Security Fixes - GitHub Copilot Code Review

**Date**: January 2025  
**PR**: https://github.com/TomBers/dialectic/pull/212

## Overview

This document details the security improvements implemented based on GitHub Copilot's automated code review. All 7 identified issues have been addressed.

---

## Issue #1 & #7: HTTP Header Injection Vulnerability

### Problem
The `content-disposition` header was built directly from user-controlled data (graph title or slug) without proper sanitization:
- Filenames were unnecessarily double-quoted
- No stripping of CR/LF characters
- Graph titles could contain newlines via `String.replace(~r/\n/, " ")`
- Could lead to HTTP response splitting attacks

### Fix
**File**: `lib/dialectic_web/controllers/page_controller.ex`

```elixir
# Before
filename = if graph_struct.slug, do: "#{graph_struct.slug}.md", else: "#{graph_struct.title}.md"
|> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")

# After
base_filename = if graph_struct.slug, do: graph_struct.slug, else: graph_struct.title
safe_filename = base_filename
  |> String.replace(~r/[^A-Za-z0-9_.-]/, "_")  # Only allow safe characters
  |> String.slice(0, 200)                       # Limit length
safe_filename = "#{safe_filename}.md"
|> put_resp_header("content-disposition", "attachment; filename=#{safe_filename}")
```

### Impact
- ✅ Prevents HTTP response splitting
- ✅ Prevents header injection attacks
- ✅ Complies with RFC standards for unquoted filenames
- ✅ Sanitizes all user input before use in headers

---

## Issue #6: Missing Access Control on Export Endpoint

### Problem
The `/api/graphs/md/:graph_name` endpoint exported graph contents without any authentication or authorization checks:
- Any user could download private graphs if they knew the slug/title
- No validation of share tokens
- No ownership checks
- Completely bypassed the security model used in LiveViews

### Fix
**File**: `lib/dialectic_web/controllers/page_controller.ex`

Added comprehensive access control matching the LiveView security model:

```elixir
def graph_md(conn, %{"graph_name" => graph_id_uri} = params) do
  current_user = conn.assigns[:current_user]
  graph_struct = Dialectic.DbActions.Graphs.get_graph_by_slug_or_title(graph_name)
  
  cond do
    is_nil(graph_struct) ->
      # 404 Not Found
      
    not has_access?(current_user, graph_struct, params) ->
      # 403 Forbidden
      
    true ->
      # Allow export
  end
end

defp has_access?(user, graph_struct, params) do
  token_param = Map.get(params, "token")
  
  Dialectic.DbActions.Sharing.can_access?(user, graph_struct) or
    (is_binary(token_param) and is_binary(graph_struct.share_token) and
       Plug.Crypto.secure_compare(token_param, graph_struct.share_token))
end
```

### Access Control Logic
1. ✅ **Public graphs**: Anyone can export
2. ✅ **Owner**: Graph creator can export
3. ✅ **Shared users**: Users with email invitations can export
4. ✅ **Token holders**: Users with valid share token can export
5. ✅ **Everyone else**: 403 Forbidden

### Impact
- ✅ Prevents unauthorized data exfiltration
- ✅ Enforces privacy settings on all endpoints
- ✅ Uses secure token comparison (constant-time)
- ✅ Consistent security model across entire application

---

## Issue #2: Incorrect Environment Check

### Problem
Environment checks used non-standard configuration key that would never be true:
```elixir
if Application.get_env(:dialectic, :env) == :prod do
```

This key is never set, so production-only features (API key validation, database warmup) were not running in production.

### Fix
**File**: `lib/dialectic/application.ex`

```elixir
# Before
if Application.get_env(:dialectic, :env) == :prod do

# After (Final Fix for Production Releases)
if System.get_env("PHX_SERVER") do
```

**Note**: Initial fix used `Mix.env()`, but Mix is not available in production releases. Final fix uses `PHX_SERVER` environment variable which is always set on Fly.io production deployments.

### Impact
- ✅ API key validation now runs in production
- ✅ Database warmup now runs in production
- ✅ Works correctly in both development and production releases
- ✅ No dependency on Mix module in release builds

---

## Issue #3: Blocking Database Warmup

### Problem
Database warmup ran synchronously during application startup:
```elixir
result = Supervisor.start_link(children, opts)
warm_up_database()  # Blocks here!
result
```

If the database query failed or was slow, it could significantly delay application startup or cause the application to fail to start.

### Fix
**File**: `lib/dialectic/application.ex`

```elixir
# Before
warm_up_database()

# After (Final Fix)
spawn(fn -> warm_up_database() end)
```

**Note**: Initial fix used `Task.Supervisor.start_child`, but this caused a race condition during startup. Final fix uses `spawn` to avoid timing issues.

Additionally, added better error handling and logging:
```elixir
defp warm_up_database do
  if System.get_env("PHX_SERVER") do
    require Logger
    try do
      Process.sleep(100)  # Give repo time to initialize
      case Ecto.Adapters.SQL.query(Dialectic.Repo, "SELECT 1", []) do
        {:ok, _} -> Logger.info("Database warmup completed successfully")
        {:error, error} -> Logger.warning("Database warmup failed: #{inspect(error)}")
      end
    rescue
      error -> Logger.warning("Database warmup error: #{inspect(error)}")
    end
  end
end
```

### Impact
- ✅ Application startup is no longer blocked by database operations
- ✅ Faster, more reliable deployments
- ✅ Database failures during warmup don't prevent application from starting
- ✅ No race condition with TaskSupervisor during startup
- ✅ Better error logging for troubleshooting

---

## Issue #4: Deprecated Function Still in Use

### Problem
The `gen_link/1` function was marked as deprecated but potentially still being called.

### Fix
**Status**: Already removed in the slug-only routing cleanup.

The function and all its usages were removed from:
- `lib/dialectic_web/live/home_live.ex`
- `lib/dialectic_web/controllers/page_html.ex`

### Impact
- ✅ No deprecated code in codebase
- ✅ All paths use `graph_path` helper consistently

---

## Issue #5: Slug Collision Vulnerability

### Problem
Fallback slug generation used millisecond timestamp:
```elixir
"#{base_slug}-#{System.system_time(:millisecond)}"
```

If two slug generation attempts happened in the same millisecond (likely under load), they would generate identical slugs, causing unique constraint violations.

### Fix
**Files**: 
- `lib/dialectic/db_actions/graphs.ex`
- `priv/repo/migrations/20260108110254_add_slug_to_graphs.exs`

```elixir
# Before
"#{base_slug}-#{System.system_time(:millisecond)}"

# After  
"#{base_slug}-#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
```

### Impact
- ✅ Eliminates race condition in slug generation
- ✅ Uses cryptographically secure random bytes
- ✅ 16-character hex string provides excellent collision resistance
- ✅ Prevents unique constraint violations under concurrent load

---

## Testing

### Compilation
```bash
mix compile
# ✅ 0 warnings, 0 errors
```

### Unit Tests
```bash
MIX_ENV=test mix test test/dialectic/db_actions/graphs_test.exs
# ✅ 12 tests, 0 failures
```

### Migration
```bash
mix ecto.rollback --step 1
mix ecto.migrate
# ✅ Successfully backfills 200 graphs with improved slug generation
```

---

## Security Impact Summary

| Issue | Severity | Status | Impact |
|-------|----------|--------|--------|
| HTTP Header Injection (#1, #7) | **High** | ✅ Fixed | Prevents response splitting attacks |
| Missing Access Control (#6) | **Critical** | ✅ Fixed | Prevents unauthorized data access |
| Slug Collision Race (#5) | **Medium** | ✅ Fixed | Prevents constraint violations |
| Environment Check (#2) | **Medium** | ✅ Fixed | Enables production security features |
| Blocking Warmup (#3) | **Low** | ✅ Fixed | Improves reliability |
| Deprecated Code (#4) | **Low** | ✅ Fixed | Code quality improvement |

---

## Files Modified

- `lib/dialectic_web/controllers/page_controller.ex` - Access control and header sanitization
- `lib/dialectic/application.ex` - Environment checks and async warmup
- `lib/dialectic/db_actions/graphs.ex` - Improved slug collision handling
- `priv/repo/migrations/20260108110254_add_slug_to_graphs.exs` - Improved slug collision handling
- `SLUG_IMPLEMENTATION_SUMMARY.md` - Documentation updates

---

## Deployment Notes

These changes are **backward compatible** and require no special deployment steps:

1. Deploy code as normal
2. Run `mix ecto.migrate` (if not already run)
3. All security fixes take effect immediately

No configuration changes needed.

---

## Credits

Security issues identified by: **GitHub Copilot Code Review**  
Implementation: Dialectic Engineering Team  
Review Date: January 2025
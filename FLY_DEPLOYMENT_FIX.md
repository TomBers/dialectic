# Fly.io Deployment Fix - Restart Loop Resolution

**Date**: January 2025  
**Issue**: Application restart loop on Fly.io with machine lease errors

## Problem

Application was experiencing a restart loop on Fly.io with the following errors:
```
machines API returned an error: "machine ID 4d899371f44187 lease currently held"
machines API returned an error: "rate limit exceeded"
```

This indicated the application was crashing during startup, causing Fly.io to rapidly restart it.

## Root Causes Identified

### 1. Fatal API Key Validation
**Problem**: The `validate_api_keys!()` function would raise exceptions if API keys were missing or empty, causing the entire application to crash during startup.

**Impact**: If environment variables weren't properly configured, the app would never start.

### 2. Mix.env() Not Available in Releases
**Problem**: Initial fix attempted to use `Mix.env()` to detect production environment, but the `Mix` module is not available in production releases.

**Impact**: Environment detection would fail in production, potentially causing unexpected behavior.

### 3. TaskSupervisor Race Condition
**Problem**: Initial database warmup fix used `Task.Supervisor.start_child()` immediately after `Supervisor.start_link()`, creating a race condition.

**Impact**: TaskSupervisor might not be fully initialized when warmup tried to use it.

### 4. Health Check Rate Limiting
**Problem**: Health check endpoints (`/health` and `/health/deep`) were going through the `:api` pipeline which includes rate limiting. Fly.io's frequent health checks were being rate-limited, returning `429 Too Many Requests`, causing health checks to fail.

**Impact**: Fly.io thought the application was unhealthy and kept restarting it, creating a restart loop.

## Solutions Implemented

### Fix #1: Non-Fatal API Key Validation

**File**: `lib/dialectic/application.ex`

Changed from:
```elixir
defp validate_api_keys! do
  if System.get_env("PHX_SERVER") do
    validate_key!("OPENAI_API_KEY", "OpenAI")
  end
end

defp validate_key!(env_var, provider_name) do
  case System.get_env(env_var) do
    nil -> raise "Missing required environment variable: #{env_var}"
    "" -> raise "Empty environment variable: #{env_var}"
    _key -> :ok
  end
end
```

To:
```elixir
defp validate_api_keys do
  require Logger
  
  if System.get_env("PHX_SERVER") do
    Logger.info("Running in production mode - validating API keys")
    validate_key("OPENAI_API_KEY", "OpenAI")
  else
    Logger.info("Running in development mode - skipping API key validation")
  end
  
  :ok
end

defp validate_key(env_var, provider_name) do
  require Logger
  
  case System.get_env(env_var) do
    nil ->
      Logger.error("""
      Missing required environment variable: #{env_var}
      Application will start but LLM features may not work.
      """)
      :ok
      
    "" ->
      Logger.error("""
      Empty environment variable: #{env_var}
      Application will start but LLM features may not work.
      """)
      :ok
      
    _key ->
      Logger.info("✓ #{provider_name} API key is configured")
      :ok
  end
end
```

**Benefits**:
- Application starts even with missing/invalid API keys
- Clear error logging for troubleshooting
- Production readiness without blocking deployment

### Fix #2: Production Environment Detection

**File**: `lib/dialectic/application.ex`

Changed from:
```elixir
if Mix.env() == :prod do  # Mix not available in releases!
```

To:
```elixir
if System.get_env("PHX_SERVER") do  # Always set on Fly.io
```

**Benefits**:
- Works in both development and production releases
- No dependency on Mix module
- Reliable production detection on Fly.io

### Fix #3: Safe Database Warmup

**File**: `lib/dialectic/application.ex`

Changed from:
```elixir
Task.Supervisor.start_child(Dialectic.TaskSupervisor, fn -> warm_up_database() end)
```

To:
```elixir
spawn(fn -> warm_up_database() end)
```

Plus improved error handling:
```elixir
defp warm_up_database do
  if System.get_env("PHX_SERVER") do
    require Logger
    
    try do
      Process.sleep(100)  # Give repo time to initialize
      
      case Ecto.Adapters.SQL.query(Dialectic.Repo, "SELECT 1", []) do
        {:ok, _} -> 
          Logger.info("Database warmup completed successfully")
          
        {:error, error} -> 
          Logger.warning("Database warmup failed: #{inspect(error)}")
      end
    rescue
      error -> 
        Logger.warning("Database warmup error: #{inspect(error)}")
    end
  end
end
```

**Benefits**:
- No race condition with supervisor startup
- Better error logging
- Non-blocking with proper initialization delay
- Graceful failure handling

### Fix #4: Remove Rate Limiting from Health Checks

**File**: `lib/dialectic_web/router.ex`

Changed from:
```elixir
# Health check endpoints
scope "/health", DialecticWeb do
  pipe_through :api  # This includes rate limiting!

  get "/", HealthController, :check
  get "/deep", HealthController, :deep
end
```

To:
```elixir
pipeline :health do
  plug :accepts, ["json"]
  # No rate limiting!
end

# Health check endpoints (no rate limiting)
scope "/health", DialecticWeb do
  pipe_through :health

  get "/", HealthController, :check
  get "/deep", HealthController, :deep
end
```

**File**: `lib/dialectic_web/controllers/health_controller.ex`

Simplified deep health check:
```elixir
def deep(conn, _params) do
  db_status = check_database()
  is_healthy = db_status == "ok"

  conn
  |> put_status(if is_healthy, do: 200, else: 503)
  |> json(%{
    status: if(is_healthy, do: "ok", else: "error"),
    database: db_status,
    timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
  })
end

defp check_database do
  case Ecto.Adapters.SQL.query(Dialectic.Repo, "SELECT 1", [], timeout: 1000) do
    {:ok, _} -> "ok"
    _ -> "error"
  end
rescue
  _ -> "error"
end
```

**Benefits**:
- Health checks no longer rate-limited
- Faster health check (1 second timeout)
- Fly.io can check health frequently without issues
- Removed Oban and application checks for speed

## Deployment Instructions

### 1. Verify Environment Variables on Fly.io

```bash
fly secrets list
```

Ensure you have one of:
- `OPENAI_API_KEY` (for OpenAI)
- `GOOGLE_API_KEY` (for Google/Gemini)

And optionally:
- `LLM_PROVIDER` (defaults to "openai")

### 2. Set Missing Secrets

```bash
# For OpenAI
fly secrets set OPENAI_API_KEY=sk-...

# For Google/Gemini
fly secrets set GOOGLE_API_KEY=... LLM_PROVIDER=google
```

### 3. Deploy

```bash
fly deploy
```

### 4. Monitor Logs

```bash
fly logs
```

Look for:
- `✓ OpenAI API key is configured` (success)
- `Running in production mode - validating API keys`
- `Database warmup completed successfully`

## Expected Behavior After Fix

### Successful Startup
**Expected log output**:
```
Running in production mode - validating API keys
LLM Provider: openai
✓ OpenAI API key is configured
Database warmup completed successfully
```

### Startup with Missing API Key (Non-Fatal)
```
Running in production mode - validating API keys
LLM Provider: openai
Missing required environment variable: OPENAI_API_KEY
Application will start but LLM features may not work.
```

Application will still start and serve requests, but LLM features won't work until the key is added.

### Health Check Behavior
```bash
# Basic health check (always fast)
curl https://your-app.fly.dev/health
# {"status":"ok","timestamp":"2025-01-08T13:20:00Z"}

# Deep health check (checks database)
curl https://your-app.fly.dev/health/deep
# {"status":"ok","database":"ok","timestamp":"2025-01-08T13:20:00Z"}
```

No rate limiting on health checks - Fly.io can poll as frequently as needed.

## Troubleshooting

### If restart loop continues:

1. **Check database connectivity**:
   ```bash
   fly postgres connect -a <your-db-app-name>
   ```

2. **Check application logs**:
   ```bash
   fly logs --app dialectic
   ```

3. **Check secrets**:
   ```bash
   fly secrets list
   ```

4. **Restart machines manually**:
   ```bash
   fly machine list
   fly machine restart <machine-id>
   ```

5. **Scale down and up**:
   ```bash
   fly scale count 0
   fly scale count 1
   ```

## Additional Safety Improvements

All fixes maintain backward compatibility:
- Development environment continues to work without API keys
- Test environment is unaffected
- Production becomes more resilient to configuration issues

## Related Changes

These fixes complement the security improvements from GitHub Copilot review:
- Access control on export endpoints
- HTTP header injection prevention  
- Improved slug collision handling

See `SECURITY_FIXES.md` for details on those changes.

---

**Status**: ✅ Fixed and ready for deployment
**Testing**: Verified in development and staging
**Production**: Safe to deploy
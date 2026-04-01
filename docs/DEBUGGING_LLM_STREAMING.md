# Debugging LLM Streaming Issues

## Overview

This guide helps diagnose issues where graphs are created successfully but LLM responses never return, leaving users with a loading screen.

## Symptoms

- Graph creation completes successfully
- User is redirected to the graph view
- Loading indicator appears but never completes
- No LLM response content appears
- Error logs show:
  - `GenServer #PID<...> terminating`
  - `navigate event to "..." failed because you are redirecting across live_sessions`

## Architecture Overview

### LLM Streaming Flow

```
HomeLive (graph creation)
  ↓
Dialectic.Graph.Creator.create/4
  ↓
RequestQueue.add() → Enqueues Oban job
  ↓
LLMWorker.perform() → Streams response
  ↓
Phoenix.PubSub.broadcast(live_view_topic, {:stream_chunk, ...})
  ↓
GraphLive.handle_info({:stream_chunk, ...}) → Updates UI
  ↓
Phoenix.PubSub.broadcast(live_view_topic, {:llm_request_complete, node_id})
  ↓
GraphLive.handle_info({:llm_request_complete, ...}) → Clears loading state
```

### Critical Components

1. **Socket Lifecycle**: Each LiveView mount creates a unique `socket.id`
2. **PubSub Topics**: 
   - `live_view_topic`: `"graph_update:#{socket.id}"` (per-socket)
   - `graph_topic`: `"graph_update:#{graph_id}"` (shared)
3. **GraphManager**: GenServer that holds graph state
4. **Oban Jobs**: Background workers for LLM requests

## Common Failure Points

### 1. Live Session Mismatch (FIXED)

**Problem**: Routes not wrapped in `live_session` causing cross-session navigation warnings.

**Symptoms**:
```
[warning] navigate event to "..." failed because you are redirecting across live_sessions
```

**Fix Applied**: All main routes (`HomeLive`, `GraphLive`, `LinearGraphLive`) now wrapped in `:main` live_session.

**Verify**:
```bash
# Check router configuration
grep -A 10 "live_session :main" lib/dialectic_web/router.ex
```

### 2. Socket ID Mismatch (FIXED)

**Problem**: LLM job enqueued with old `live_view_topic` from creation flow, but user redirected to new LiveView with different `socket.id`.

**Symptoms**: User creates graph, redirects to GraphLive, but never receives LLM streaming updates because they're broadcast to a dead socket.

**Debug**: Check logs for topic mismatch:
```
# Job enqueued with:
[info] Enqueueing LLM job graph_id=... node_id=... live_view_topic="graph_update:SOCKET_ID_1"

# But GraphLive subscribed with:
[info] GraphLive subscribed to PubSub topics socket_id=SOCKET_ID_2 live_view_topic="graph_update:SOCKET_ID_2"
```

**Fix Applied**: Workers now broadcast to **both** `live_view_topic` (socket-specific) AND `graph_topic` (shared) for reliability. This ensures messages reach the user even if they redirect during streaming.

### 3. GraphManager Crash

**Problem**: GraphManager GenServer terminates during graph creation or LLM streaming.

**Symptoms**:
```
[error] GenServer #PID<...> terminating
```

**Debug**: Check for:
- Graph not found in database
- Deserialization errors
- Digraph operation failures

**Fix Applied**: Added error handling to `GraphManager.init/1`:
```elixir
# Now returns {:stop, :graph_not_found} or {:stop, :deserialization_error}
# instead of crashing
```

**Verify**:
```bash
# Check GraphManager logs
grep -E "GraphManager init|Shutting Down GraphManager" production.log
```

### 4. Missing API Key

**Problem**: LLM provider API key not configured.

**Symptoms**:
```
[error] LLM job failed: missing API key
```

**Fix**: Set environment variable:
```bash
export OPENAI_API_KEY="sk-..."
# or
export GOOGLE_API_KEY="..."
```

## Diagnostic Logging

### New Log Messages

All LLM operations now include comprehensive logging:

#### 1. Job Enqueue
```
[info] Enqueueing LLM job graph_id=... node_id=... live_view_topic=...
[info] LLM job enqueued successfully job_id=... graph_id=... node_id=...
```

#### 2. Job Start
```
[info] LLM job started job_id=... attempt=1 max_attempts=3 graph_id=... node_id=...
```

#### 3. Streaming Start
```
[info] LLM streaming started successfully job_id=... graph_id=... node_id=... provider=OpenAI
```

#### 4. Job Completion
```
[info] LLM job completed successfully job_id=... graph_id=... node_id=... response_length=1234
[debug] Finalizing LLM response graph_id=... node_id=...
[debug] Broadcasting llm_request_complete graph_id=... node_id=...
```

#### 5. LiveView Subscription
```
[info] GraphLive subscribed to PubSub topics socket_id=... live_view_topic=... graph_topic=... graph_id=...
```

#### 6. Message Reception
```
[debug] [GraphLive] llm_request_complete node_id=... current=...
```

### Troubleshooting Workflow

#### Step 1: Check Job Enqueue
```bash
grep "Enqueueing LLM job" production.log | tail -5
```

**Expected**: Job should be enqueued with correct graph_id and node_id.

**If missing**: Check `Dialectic.Responses.LlmInterface` and `RequestQueue.add/5` calls.

#### Step 2: Check Job Execution
```bash
grep "LLM job started" production.log | tail -5
```

**Expected**: Job should start within seconds of enqueue.

**If delayed**: Check Oban queue status:
```elixir
# In IEx
Oban.check_queue(queue: :llm_request)
```

#### Step 3: Check API Key
```bash
grep "missing API key" production.log
```

**If found**: Set the appropriate environment variable and restart.

#### Step 4: Check Streaming
```bash
grep "LLM streaming started" production.log | tail -5
```

**Expected**: Streaming should start immediately after job starts.

**If missing**: Check network connectivity to LLM provider.

#### Step 5: Check Completion
```bash
grep "LLM job completed successfully" production.log | tail -5
```

**Expected**: Job should complete with response_length > 0.

**If stuck**: Check for timeouts or provider errors.

#### Step 6: Check PubSub Broadcast
```bash
grep "Broadcasting llm_request_complete" production.log | tail -5
```

**Expected**: Should occur immediately after job completion.

**If missing**: Check `finalize/3` function in `llm_worker.ex`.

#### Step 7: Check LiveView Subscription
```bash
grep "GraphLive subscribed" production.log | tail -10
```

**Expected**: Should see subscription with matching graph_id.

**If missing**: User may not have reached GraphLive (stuck on loading screen).

#### Step 8: Correlate Topics
```bash
# Get job topic
grep "Enqueueing LLM job.*graph_id=GRAPH_TITLE" production.log | grep -o "live_view_topic=[^ ]*"

# Get LiveView topic
grep "GraphLive subscribed.*graph_id=GRAPH_TITLE" production.log | grep -o "live_view_topic=[^ ]*"
```

**Expected**: Topics should match, OR job should use `graph_topic` instead of `live_view_topic`.

**If mismatch**: This is the root cause. Messages go to wrong topic.

## Solutions

### Solution: Dual Broadcast Pattern (IMPLEMENTED) ✅

The most robust solution is to broadcast to **both topics**:
- `live_view_topic` (socket-specific) for immediate response
- `graph_topic` (shared) for reliability across redirects

**Implementation**: All LLM workers now broadcast streaming updates and completion messages to both topics.

**Files modified**:
- `lib/dialectic/responses/utils.ex` - `set_node_content/4` broadcasts to both topics
- `lib/dialectic/responses/llm_worker.ex` - `finalize/3` broadcasts completion to both topics
- `lib/dialectic/responses/local_worker.ex` - Test worker also uses dual broadcast

**Benefits**:
- ✅ Handles race condition when user redirects during streaming
- ✅ Works even if original socket disconnects
- ✅ All viewers of the same graph receive updates
- ✅ No breaking changes to existing code

**Code example**:
```elixir
# In utils.ex - set_node_content/4
Phoenix.PubSub.broadcast(Dialectic.PubSub, live_view_topic, {:stream_chunk, ...})
Phoenix.PubSub.broadcast(Dialectic.PubSub, "graph_update:#{graph}", {:stream_chunk_broadcast, ...})

# In llm_worker.ex - finalize/3
Phoenix.PubSub.broadcast(Dialectic.PubSub, live_view_topic, {:llm_request_complete, ...})
Phoenix.PubSub.broadcast(Dialectic.PubSub, "graph_update:#{graph}", {:llm_request_complete, ...})
```

## Verification

After applying fixes, verify with:

```bash
# 1. Create a new graph
# 2. Watch logs in real-time
tail -f production.log | grep -E "Enqueueing|subscribed|llm_request_complete|stream_chunk"

# 3. Verify sequence:
#    a. "Enqueueing LLM job"
#    b. "GraphLive subscribed to PubSub topics"
#    c. "LLM job started"
#    d. "LLM streaming started successfully"
#    e. "LLM job completed successfully"
#    f. "Broadcasting llm_request_complete"
#    g. "[GraphLive] llm_request_complete"
```

## Quick Fixes for Production

### Immediate Workaround

If users are stuck with loading screens:

1. **Refresh the page**: New mount creates new socket, resubscribes
2. **Check Oban dashboard**: `/dev/dashboard` (development) to see job status
3. **Retry failed jobs**: 
   ```elixir
   # In IEx
   Oban.retry_all_failed()
   ```

### Monitor Health

```elixir
# Check GraphManager processes
Registry.count(:global) # Should show active graphs

# Check Oban queues
Oban.check_queue(queue: :llm_request)

# Check PubSub subscriptions
Phoenix.PubSub.subscribers(Dialectic.PubSub, "graph_update:GRAPH_TITLE")
```

## Further Investigation

If issue persists after fixes:

1. **Enable debug logging**:
   ```elixir
   # In config/runtime.exs
   config :logger, level: :debug
   ```

2. **Add telemetry events**:
   ```elixir
   :telemetry.attach(
     "pubsub-broadcast",
     [:phoenix, :channel, :broadcast],
     fn event, measurements, metadata, _config ->
       IO.inspect({event, measurements, metadata})
     end,
     nil
   )
   ```

3. **Check Oban job details**:
   ```elixir
   # Get failed jobs
   Oban.Job
   |> where([j], j.state == "discarded" or j.state == "retryable")
   |> order_by([j], desc: j.attempted_at)
   |> limit(10)
   |> Repo.all()
   ```

4. **Verify WebSocket connection**:
   - Open browser DevTools → Network → WS
   - Should see active WebSocket connection to LiveView
   - Messages should flow bidirectionally

## Related Files

- `lib/dialectic_web/router.ex` - Live session configuration
- `lib/dialectic/graph/graph_manager.ex` - GenServer for graph state
- `lib/dialectic/responses/llm_worker.ex` - Oban worker for LLM streaming
- `lib/dialectic/responses/request_queue.ex` - Job enqueue logic
- `lib/dialectic_web/live/graph_live.ex` - Main graph LiveView
- `lib/dialectic_web/live/graph_streaming.ex` - Streaming message handlers

## Summary

Three critical issues have been fixed to prevent intermittent streaming failures:

### 1. **Dual Broadcast Pattern** (Fixes Race Condition) ✅
All LLM streaming messages now broadcast to both socket-specific and graph-wide topics. This prevents the race condition where a user redirects during streaming and loses the messages.

### 2. **Live Session Grouping** (Prevents Navigation Errors) ✅
All main routes (`HomeLive`, `GraphLive`, `LinearGraphLive`) wrapped in a single `live_session` to prevent cross-session navigation warnings.

### 3. **GraphManager Error Handling** (Prevents Crashes) ✅
Added proper error handling to prevent crashes when graphs don't exist or have invalid data.

### Additional Improvements:
- Comprehensive logging throughout the streaming pipeline
- Better error messages for missing API keys
- Detailed diagnostic guide for troubleshooting

**Why the issue was intermittent**: The race condition only occurred when the user's redirect happened in the brief window between job enqueue and job start. The dual broadcast pattern now ensures messages reach the user regardless of timing.

**Next Steps**: Monitor production logs using the diagnostic workflow above to confirm streaming works end-to-end. The new logging will help identify any remaining edge cases.
</text>

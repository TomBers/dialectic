# 🚨 Deploy Health Check Fix NOW

## Current Situation
Your app is in a restart loop because health checks are being rate-limited (429 errors).

## The Fix (Already Committed)
✅ Removed rate limiting from health check endpoints
✅ Simplified `/health/deep` to be faster
✅ Code is committed and ready to deploy

## Deploy Steps

### Step 1: Deploy to Fly.io
```bash
fly deploy --app dialectic --strategy immediate
```

Or use the helper script:
```bash
./deploy_fix.sh
```

### Step 2: Monitor Deployment
```bash
fly logs --app dialectic
```

Look for:
- ✅ `GET /health` returning 200 (not 429!)
- ✅ `GET /health/deep` returning 200 (not 429!)
- ✅ No "Health check failed" messages

### Step 3: Verify Health Checks
```bash
./test_health.sh
```

This will hammer the health endpoint 10 times. All should return `200 OK`.

## Expected Results

### Before (Current - BAD)
```
GET /health/deep
Sent 429 in 275µs  ❌ RATE LIMITED
Health check failed ❌
```

### After (Fixed - GOOD)
```
GET /health
Sent 200 in <1ms  ✅ SUCCESS
GET /health/deep
Sent 200 in 2ms   ✅ SUCCESS
Health check passed ✅
```

## If Still Seeing 429 Errors

1. **Verify deployment succeeded**:
   ```bash
   fly releases --app dialectic
   ```
   
2. **Force restart machines**:
   ```bash
   fly machine list --app dialectic
   fly machine restart <machine-id>
   ```

3. **Check the router is correct**:
   ```bash
   fly ssh console --app dialectic
   grep -A 3 "pipeline :health" /app/lib/dialectic_web/router.ex
   ```

4. **Nuclear option - scale down and up**:
   ```bash
   fly scale count 0 --app dialectic
   sleep 10
   fly scale count 1 --app dialectic
   ```

## Quick Deploy Command
```bash
fly deploy --app dialectic && sleep 30 && ./test_health.sh
```

This will deploy and automatically test after 30 seconds.

---

**STATUS**: ⏳ Waiting for deployment
**ACTION REQUIRED**: Run `fly deploy` now!

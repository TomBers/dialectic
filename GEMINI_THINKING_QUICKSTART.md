# Gemini Thinking Level - Quick Start Guide

## TL;DR

Control how much reasoning your Gemini model uses by setting:

```bash
export GEMINI_THINKING_LEVEL=low
```

**Options:** `minimal`, `low` (default), `medium`, `high`

## Why This Matters

Gemini 3 models think before responding. More thinking = better quality but slower responses.

| Level | Speed | Token Budget | When to Use |
|-------|-------|--------------|-------------|
| `minimal` | ⚡⚡⚡ Fastest | 512 tokens | Chat, simple queries, high traffic |
| `low` | ⚡⚡ Fast | 2048 tokens | **Default** - Most use cases |
| `medium` | ⚡ Moderate | 8192 tokens | Complex questions, analysis |
| `high` | 🐌 Slow | Dynamic | Advanced math, coding, reasoning |

## Quick Setup

### Local Development

1. Add to your `.env` file:
   ```bash
   GEMINI_THINKING_LEVEL=low
   ```

2. Restart your server:
   ```bash
   mix phx.server
   ```

### Production (Fly.io)

```bash
fly secrets set GEMINI_THINKING_LEVEL=low
fly deploy
```

## Real-World Examples

### Scenario 1: High-Traffic Chat App
**Problem:** Users complain about slow responses  
**Solution:**
```bash
GEMINI_THINKING_LEVEL=minimal
```
**Result:** 2-3x faster responses, good enough for chat

### Scenario 2: Code Generation Tool
**Problem:** Generated code has bugs or misses edge cases  
**Solution:**
```bash
GEMINI_THINKING_LEVEL=high
```
**Result:** Slower but more thorough, better code quality

### Scenario 3: General Q&A Service
**Problem:** Need balance between speed and quality  
**Solution:**
```bash
GEMINI_THINKING_LEVEL=low  # This is already the default!
```
**Result:** Good balance for most queries

## Verification

Check your server logs on startup:

```
[info] LLM Provider: google
[info] Gemini thinking level: low
```

## Cost Impact

Higher thinking levels use more "thinking tokens" which are billed as output tokens:

- `minimal`: ~512 extra tokens per response
- `low`: ~2048 extra tokens per response  
- `medium`: ~8192 extra tokens per response
- `high`: Variable (can be 10k+ tokens)

**Example:** 1000 requests/day on `high` vs `minimal` could cost $5-10 more per day.

## Performance Tips

1. **Start with `low`** (the default) - it's a good balance
2. **Use `minimal` for chat** - users expect fast responses
3. **Use `high` for complex tasks** - worth the wait for quality
4. **Monitor your costs** - check thinking token usage in your API logs

## Troubleshooting

### Not seeing any effect?

1. Check env var is set: `echo $GEMINI_THINKING_LEVEL`
2. Verify you're using Google provider: `LLM_PROVIDER=google`
3. Restart your server after changing variables
4. Check logs for "Gemini thinking level" message

### Still too slow on `minimal`?

The model may still think a bit for complex prompts. Consider:
- Simplifying your prompts
- Breaking complex tasks into smaller steps
- Using a different model for simple queries

## Need More Details?

See [GEMINI_THINKING_CONFIG.md](./GEMINI_THINKING_CONFIG.md) for comprehensive documentation.

## Quick Reference

```bash
# Copy-paste configs for different scenarios

# Fast chat/simple queries
export GEMINI_THINKING_LEVEL=minimal

# Balanced (default)
export GEMINI_THINKING_LEVEL=low

# Complex analysis
export GEMINI_THINKING_LEVEL=medium

# Advanced reasoning/coding
export GEMINI_THINKING_LEVEL=high
```

---

**Questions?** Check [GEMINI_THINKING_CONFIG.md](./GEMINI_THINKING_CONFIG.md) or [GEMINI_THINKING_IMPLEMENTATION.md](./GEMINI_THINKING_IMPLEMENTATION.md)
# Gemini Thinking Level Configuration

## Overview

The Gemini 3 series models (like `gemini-3-flash-preview`) use an internal "thinking process" that significantly improves their reasoning and multi-step planning abilities. This makes them highly effective for complex tasks such as coding, advanced mathematics, and data analysis.

By default, Dialectic configures the thinking level to `"low"` (2048 thinking tokens) to optimize for speed and cost, but you can adjust this based on your needs.

**Technical Note:** While Gemini 3 models support the newer `thinkingLevel` parameter, ReqLLM (the HTTP library we use) currently only exposes the `thinkingBudget` parameter. Dialectic automatically maps thinking levels to appropriate token budgets for backward compatibility.

## Configuration

Set the `GEMINI_THINKING_LEVEL` environment variable to control how much reasoning the model performs:

```bash
export GEMINI_THINKING_LEVEL=low
```

### Available Thinking Levels

| Level | Token Budget | Description | Best For | Trade-offs |
|-------|-------------|-------------|----------|------------|
| `minimal` | 512 tokens | Minimizes latency for chat or high throughput. | Simple queries, chat, high-throughput applications | Fastest, but may produce lower quality responses for complex tasks |
| `low` | 2048 tokens | Minimizes latency and cost. Best for simple instruction following. | Simple instruction following, basic questions | **Default** - Good balance for most simple tasks |
| `medium` | 8192 tokens | Balanced thinking for most tasks. | General purpose, moderately complex tasks | Moderate speed and quality |
| `high` | Dynamic (-1) | Maximizes reasoning depth. Uses dynamic token budget. | Complex math, advanced coding, multi-step reasoning | Slowest, but highest quality for complex problems |

**Note:** The thinking budget controls the maximum number of internal reasoning tokens the model can use. Higher budgets allow more thorough reasoning but increase latency and cost.

## Usage Examples

### Development (.env file)

```bash
# For fastest responses (good for chat/simple queries)
GEMINI_THINKING_LEVEL=minimal

# For balanced performance (default)
GEMINI_THINKING_LEVEL=low

# For complex reasoning tasks
GEMINI_THINKING_LEVEL=high
```

### Production (Fly.io)

```bash
# Set the thinking level secret
fly secrets set GEMINI_THINKING_LEVEL=low --app your-app-name

# Verify it's set
fly secrets list --app your-app-name
```

### Docker

```bash
docker run -e GEMINI_THINKING_LEVEL=low your-image
```

## When to Use Each Level

### Use `minimal` or `low` when:
- Building a chat interface where latency matters
- Processing high volumes of simple requests
- Doing basic fact retrieval or classification
- Cost optimization is a priority
- Example: "Where was DeepMind founded?"
- Example: "Is this email asking for a meeting?"

### Use `medium` when:
- Tasks require moderate reasoning
- You need a balance between speed and quality
- Example: "Compare and contrast electric cars and hybrid cars"
- Example: "Analogize photosynthesis and growing up"

### Use `high` when:
- Solving complex mathematical problems
- Writing sophisticated code with multiple components
- Multi-step planning and reasoning tasks
- Quality is more important than speed
- Example: "Solve this AIME problem: Find the sum of all integer bases b > 9..."
- Example: "Write Python code for a web application with authentication and real-time data visualization"

## Performance Impact

The thinking level directly affects:

1. **Latency**: Higher levels = longer time to first token
   - `minimal`: ~fastest response time
   - `low`: ~10-20% slower than minimal
   - `medium`: ~30-50% slower than minimal
   - `high`: Can be 2-5x slower than minimal

2. **Cost**: Thinking tokens are billed as output tokens
   - Higher thinking levels generate more thinking tokens
   - You can monitor thinking token usage in API responses

3. **Quality**: Higher levels generally produce better results for complex tasks
   - `minimal/low`: May miss nuances in complex problems
   - `high`: More thorough reasoning, catches edge cases

## Troubleshooting

### Problem: Responses are too slow

**Solution**: Lower the thinking level to `minimal` or `low`

```bash
export GEMINI_THINKING_LEVEL=minimal
```

### Problem: Responses lack depth for complex tasks

**Solution**: Increase the thinking level to `medium` or `high`

```bash
export GEMINI_THINKING_LEVEL=high
```

### Problem: Configuration not taking effect

**Checklist:**
1. Verify the environment variable is set: `echo $GEMINI_THINKING_LEVEL`
2. Restart your Phoenix server after changing the variable
3. Check that you're using the Google provider: `LLM_PROVIDER=google`
4. Verify you have `GOOGLE_API_KEY` set

## Technical Details

### How It Works

Dialectic maps thinking levels to thinking budgets (token limits) and passes them to the Gemini API:

```elixir
# In Dialectic.LLM.Providers.Google
def provider_options do
  thinking_level = System.get_env("GEMINI_THINKING_LEVEL", "low")
  thinking_budget = thinking_level_to_budget(thinking_level)
  
  [google_thinking_budget: thinking_budget]
end

# Mapping function
defp thinking_level_to_budget("minimal"), do: 512
defp thinking_level_to_budget("low"), do: 2048
defp thinking_level_to_budget("medium"), do: 8192
defp thinking_level_to_budget("high"), do: -1  # Dynamic
```

The `google_thinking_budget` is then passed through ReqLLM to the Gemini API as the `thinkingBudget` parameter.

### Model Compatibility

This configuration is supported on:
- ✅ Gemini 3 Flash (`gemini-3-flash-preview`) - all levels supported (budgets: 512-24576)
- ✅ Gemini 3 Pro - all levels supported (budgets: 128-32768)
- ✅ Gemini 2.5 Flash - all levels supported (budgets: 0-24576)
- ✅ Gemini 2.5 Pro - all levels supported (budgets: 128-32768, cannot disable thinking)

**Note:** We use the `thinkingBudget` parameter which is supported across all Gemini model versions for backward compatibility.

## Further Reading

- [Official Gemini Thinking Mode Documentation](https://ai.google.dev/gemini-api/docs/thinking-mode)
- [Gemini API Pricing](https://ai.google.dev/pricing)
- [Best Practices for Prompt Engineering](https://ai.google.dev/gemini-api/docs/prompting-strategies)

## Questions?

If you have questions or issues with the thinking level configuration, please:
1. Check the server logs for any API errors
2. Verify your Gemini API key is valid and has quota
3. Review the [DEPLOYMENT.md](./DEPLOYMENT.md) for general environment variable setup
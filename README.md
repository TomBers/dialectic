# Dialectic

A visual thinking tool that transforms linear conversations into branching knowledge graphs.

## Quick Start

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Configure your environment variables (see Configuration below)
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Configuration

### Required Environment Variables

Copy `config.example.env` to `.env` and configure:

```bash
# Database
DATABASE_URL=ecto://postgres:postgres@localhost/dialectic_dev

# Secret key (generate with: mix phx.gen.secret)
SECRET_KEY_BASE=your_secret_key_base_here

# LLM Provider (choose one)
LLM_PROVIDER=google  # or "openai"

# API Keys
GOOGLE_API_KEY=your-google-api-key-here
# OR
OPENAI_API_KEY=sk-your-openai-api-key-here
```

### Optional: Gemini Thinking Level

Control the reasoning depth for Gemini models to optimize speed vs. quality:

```bash
# Options: minimal, low (default), medium, high
GEMINI_THINKING_LEVEL=low
```

| Level | Speed | Best For |
|-------|-------|----------|
| `minimal` | Fastest | Chat, simple queries, high throughput |
| `low` | Fast | Simple tasks, basic questions (default) |
| `medium` | Moderate | General purpose, moderate complexity |
| `high` | Slower | Complex reasoning, advanced coding, math |

For detailed information, see [GEMINI_THINKING_CONFIG.md](./GEMINI_THINKING_CONFIG.md)

## Documentation

- [Deployment Guide](./DEPLOYMENT.md) - Production deployment instructions
- [Gemini Thinking Configuration](./GEMINI_THINKING_CONFIG.md) - Optimize LLM performance
- [Security Guide](./SECURITY.md) - Security best practices

## Production Deployment

Ready to run in production? See:
- [DEPLOYMENT.md](./DEPLOYMENT.md) for complete deployment instructions
- [SECURITY.md](./SECURITY.md) for security checklist

## Learn more about Phoenix

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix

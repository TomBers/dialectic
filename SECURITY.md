# Security Configuration Guide

This document outlines the security features and configurations implemented in the Dialectic application for production deployment.

## Table of Contents

1. [Overview](#overview)
2. [HTTPS and SSL/TLS](#https-and-ssltls)
3. [Security Headers](#security-headers)
4. [Rate Limiting](#rate-limiting)
5. [Database Security](#database-security)
6. [API Key Management](#api-key-management)
7. [Input Validation](#input-validation)
8. [Logging Security](#logging-security)
9. [Production Checklist](#production-checklist)
10. [Environment Variables](#environment-variables)

## Overview

The application implements multiple layers of security to protect against common web vulnerabilities and ensure data safety in production environments.

## HTTPS and SSL/TLS

### Forced HTTPS Redirect

All HTTP requests are automatically redirected to HTTPS in production:

```elixir
# config/runtime.exs
config :dialectic, DialecticWeb.Endpoint,
  force_ssl: [hsts: true, rewrite_on: [:x_forwarded_proto]]
```

**Features:**
- HTTP Strict Transport Security (HSTS) enabled
- Respects `X-Forwarded-Proto` header from load balancers
- Prevents man-in-the-middle attacks

### Database SSL

Database connections use SSL/TLS encryption by default:

```elixir
# config/runtime.exs
config :dialectic, Dialectic.Repo,
  ssl: true
```

**Override for Development:**
Set `DATABASE_SSL=false` in your environment if using a local database without SSL.

## Security Headers

The application sets comprehensive security headers on all responses:

### Content Security Policy (CSP)
- Restricts resource loading to prevent XSS attacks
- Allows WebSocket connections for LiveView
- Permits inline scripts and styles (required for Phoenix)

### Additional Headers
- **X-Frame-Options**: `SAMEORIGIN` - Prevents clickjacking
- **X-Content-Type-Options**: `nosniff` - Prevents MIME sniffing
- **X-XSS-Protection**: `1; mode=block` - Enables browser XSS protection
- **Referrer-Policy**: `strict-origin-when-cross-origin` - Limits referrer information
- **Permissions-Policy**: Restricts access to sensitive browser APIs

## Rate Limiting

### Implementation

Rate limiting is implemented using the Hammer library with per-endpoint configurations:

#### Authentication Endpoints
- **Limit**: 5 requests per minute
- **Applies to**: Login, registration, password reset
- **Purpose**: Prevents brute force attacks

#### API Endpoints
- **Limit**: 60 requests per minute
- **Applies to**: General API routes
- **Purpose**: Prevents API abuse

#### LLM Endpoints
- **Limit**: 20 requests per minute
- **Applies to**: AI generation endpoints
- **Purpose**: Controls costs and prevents quota exhaustion

### Configuration

Rate limits are tracked per user (when authenticated) or per IP address (for anonymous users).

**Location**: `lib/dialectic_web/plugs/rate_limiter.ex`

### Customization

Adjust rate limits by modifying the `get_limits/1` function:

```elixir
defp get_limits(:auth) do
  # {max_requests, time_window_ms}
  {5, 60_000}
end
```

## Database Security

### Connection Pooling

Configured for optimal performance and stability:

```elixir
pool_size: 10              # Maximum connections
queue_target: 5000         # Target queue time (ms)
queue_interval: 1000       # Queue check interval
timeout: 15_000            # Query timeout
connect_timeout: 15_000    # Connection timeout
```

### Indexes

Critical database indexes are implemented for:
- User graph queries (`user_id`)
- Public graph filtering (`is_public`, `inserted_at`)
- Deleted graph filtering (`is_deleted`)
- Graph sharing lookups (`share_token`)
- Highlight queries (`mudg_id`, `node_id`, `inserted_at`)

### Data Validation

All database writes go through Ecto changesets with validation:

```elixir
# Graph title validation
- Length: 1-255 characters
- Format: Letters, numbers, spaces, hyphens, underscores, periods only
- Maximum data size: 10MB

# User password validation
- Minimum length: 12 characters
- Maximum length: 72 characters (bcrypt limit)
- Hashed using bcrypt with appropriate cost factor
```

## API Key Management

### Startup Validation

API keys are validated at application startup to fail fast:

- Checks for required LLM provider keys (OpenAI or Google)
- Only enforced in production environment
- Provides clear error messages for missing keys

### Required Environment Variables

**Production requires one of:**
- `OPENAI_API_KEY` - If using OpenAI (default)
- `GOOGLE_API_KEY` - If using Google/Gemini

**Specify provider with:**
- `LLM_PROVIDER` - Set to "openai" or "google"

### Storage Best Practices

**DO:**
- Store API keys in environment variables
- Use secret management services (e.g., Fly.io Secrets, AWS Secrets Manager)
- Rotate keys regularly
- Use different keys for development and production

**DON'T:**
- Commit API keys to version control
- Hardcode keys in application code
- Share keys between environments
- Log API key values

## Input Validation

### Graph Data

```elixir
# Title validation
validate_length(:title, min: 1, max: 255)
validate_format(:title, ~r/^[a-zA-Z0-9\s\-_\.]+$/)

# Data size validation
Maximum JSON size: 10MB
```

### User Input

All user input is sanitized and validated:
- Email format validation
- Password complexity requirements
- CSRF token verification on all state-changing operations

## Logging Security

### Safe Logging Utility

Use `Dialectic.Utils.SafeLogger` to prevent sensitive data leaks:

```elixir
# Instead of:
Logger.error("Error: #{inspect(data)}")

# Use:
SafeLogger.error("Error occurred", data: data)
```

### Redacted Fields

The following fields are automatically redacted from logs:
- `password`
- `api_key`
- `secret`
- `token`
- `access_token`
- `refresh_token`
- `private_key`
- `client_secret`
- `authorization`
- `cookie`
- `hashed_password`
- `secret_key_base`

### Example

```elixir
SafeLogger.error("Authentication failed", %{
  user: "john@example.com",
  password: "secret123",  # Will be redacted
  api_key: "sk-123456"     # Will be redacted
})

# Logs: Authentication failed, user: "john@example.com", password: "[REDACTED]", api_key: "[REDACTED]"
```

## Production Checklist

### Pre-Deployment

- [ ] Set `SECRET_KEY_BASE` environment variable
- [ ] Configure database with SSL enabled
- [ ] Set appropriate `PHX_HOST` for your domain
- [ ] Configure LLM provider API keys
- [ ] Set `DATABASE_URL` with production credentials
- [ ] Review and adjust rate limits if needed
- [ ] Configure email adapter (Resend or other)
- [ ] Set up health check monitoring

### Post-Deployment

- [ ] Verify HTTPS is enforced (test HTTP redirect)
- [ ] Check security headers using [securityheaders.com](https://securityheaders.com)
- [ ] Test rate limiting on auth endpoints
- [ ] Verify health check endpoints respond correctly
- [ ] Monitor database connection pool usage
- [ ] Review application logs for security issues
- [ ] Set up alerts for failed authentication attempts
- [ ] Enable database backups

### Monitoring

- [ ] Monitor `/health` endpoint for service availability
- [ ] Monitor `/health/deep` for database connectivity
- [ ] Track rate limit violations
- [ ] Monitor Oban job failures
- [ ] Set up alerts for application errors

## Environment Variables

### Required for Production

```bash
# Application
SECRET_KEY_BASE=<generate with: mix phx.gen.secret>
PHX_HOST=yourdomain.com
PORT=8080
PHX_SERVER=true

# Database
DATABASE_URL=ecto://user:pass@host/database
DATABASE_SSL=true  # Default, can be false for dev
POOL_SIZE=10       # Adjust based on load

# LLM Provider (choose one)
LLM_PROVIDER=openai  # or "google"
OPENAI_API_KEY=sk-...
# OR
GOOGLE_API_KEY=...

# Optional: Email
RESEND_API_KEY=re_...
```

### Optional Configuration

```bash
# Oban Queue Concurrency
OBAN_API_CONCURRENCY=10
OBAN_LLM_CONCURRENCY=5
OBAN_DB_CONCURRENCY=5

# Database
ECTO_IPV6=true  # Enable IPv6 if needed

# DNS Cluster (for distributed deployments)
DNS_CLUSTER_QUERY=...
```

## Health Checks

### Basic Health Check

**Endpoint**: `GET /health`

**Response**:
```json
{
  "status": "ok",
  "timestamp": "2024-01-06T11:27:00Z"
}
```

### Deep Health Check

**Endpoint**: `GET /health/deep`

**Response**:
```json
{
  "status": "ok",
  "checks": {
    "database": "ok",
    "oban": "ok",
    "application": "ok"
  },
  "timestamp": "2024-01-06T11:27:00Z"
}
```

**Status Codes**:
- `200`: All systems healthy
- `503`: One or more systems degraded

### Configure Load Balancer

Point your load balancer health checks to `/health` for optimal performance.

## Graceful Shutdown

The application implements graceful shutdown for critical processes:

### GraphManager
- Traps exit signals
- Synchronously saves graph data before termination
- Prevents data loss during deployments

### Task Supervision
- All background tasks run under supervision
- Failed tasks are logged but don't crash the application
- LLM generation tasks are supervised and recoverable

## Security Incident Response

### If API Keys are Compromised

1. **Immediately** rotate the compromised key with your provider
2. Update the environment variable with the new key
3. Restart the application
4. Review logs for suspicious activity
5. Monitor for unusual API usage patterns

### If Database Credentials are Compromised

1. **Immediately** change database password
2. Update `DATABASE_URL` environment variable
3. Restart the application
4. Review database audit logs
5. Check for unauthorized data access

### Reporting Security Issues

Please report security vulnerabilities to your security team immediately. Do not open public GitHub issues for security problems.

## Additional Resources

- [Phoenix Security Guide](https://hexdocs.pm/phoenix/security.html)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Elixir Security Working Group](https://erlef.org/wg/security)

## Version History

- **v1.0** (2024-01-06): Initial security implementation
  - HTTPS enforcement
  - Security headers
  - Rate limiting
  - Database SSL
  - API key validation
  - Input validation
  - Safe logging
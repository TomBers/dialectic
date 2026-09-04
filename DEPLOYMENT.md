# Deployment Guide

This guide covers deploying the Dialectic application to production with all security features enabled.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Database Setup](#database-setup)
4. [Fly.io Deployment](#flyio-deployment)
5. [Post-Deployment](#post-deployment)
6. [Monitoring](#monitoring)
7. [Troubleshooting](#troubleshooting)
8. [Rolling Back](#rolling-back)

## Prerequisites

### Required Tools

- Elixir 1.14 or later
- Erlang/OTP 27.2 or later
- PostgreSQL 14+ (production)
- Node.js 18+ (for asset compilation)
- Fly.io CLI (for Fly.io deployments)

### Required Accounts

- Fly.io account (or your preferred hosting platform)
- Database hosting (e.g., Fly.io Postgres, AWS RDS)
- Google AI account with access to the Gemini API
- Email service (optional: Resend)

## Environment Setup

### 1. Generate Secrets

```bash
# Generate SECRET_KEY_BASE
mix phx.gen.secret

# Save this value - you'll need it for environment variables
```

### 2. Required Environment Variables

Create a `.env.prod` file (DO NOT commit to git):

```bash
# Application
SECRET_KEY_BASE=<your-generated-secret>
PHX_HOST=yourdomain.com
PORT=8080
PHX_SERVER=true

# Database
DATABASE_URL=ecto://user:pass@host:5432/database
DATABASE_SSL=true
POOL_SIZE=10

# Gemini API
GOOGLE_API_KEY=...

# Optional: Email
RESEND_API_KEY=re_...

# Optional: Oban Configuration
OBAN_API_CONCURRENCY=10
OBAN_LLM_CONCURRENCY=5
OBAN_DB_CONCURRENCY=5
```

### 3. Security Checklist

- [ ] `SECRET_KEY_BASE` is unique and not reused from development
- [ ] All API keys are production keys (not test/dev keys)
- [ ] Database credentials are secure and unique
- [ ] `.env.prod` is in `.gitignore`
- [ ] Secrets are stored in your platform's secret manager

## Database Setup

### Option 1: Fly.io Postgres

```bash
# Create Postgres cluster
fly postgres create --name dialectic-db

# Attach to your app
fly postgres attach dialectic-db --app your-app-name

# This automatically sets DATABASE_URL
```

### Option 2: External Database (RDS, etc.)

Ensure your database:
- Is PostgreSQL 14 or later
- Has SSL/TLS enabled
- Is accessible from your application servers
- Has appropriate connection limits

### Database Initialization

After setting up the database, run migrations:

```bash
# If using Fly.io
fly ssh console --app your-app-name
/app/bin/migrate

# OR locally against production database (be careful!)
MIX_ENV=prod mix ecto.migrate
```

### Database Indexes

The application includes critical indexes. Verify they were created:

```sql
-- Check indexes on graphs table
\d graphs

-- Should see indexes for:
-- - user_id
-- - is_public, inserted_at
-- - is_deleted
-- - share_token
```

## Fly.io Deployment

### 1. Install Fly CLI

```bash
# macOS
brew install flyctl

# Linux
curl -L https://fly.io/install.sh | sh

# Windows
iwr https://fly.io/install.ps1 -useb | iex
```

### 2. Login to Fly

```bash
fly auth login
```

### 3. Review fly.toml

The `fly.toml` is pre-configured with:
- Min 1 machine running (no cold starts)
- 4GB memory (adjust based on needs)
- Health checks on `/health`
- HTTPS enforcement
- Graceful shutdown handling

```toml
# Key settings in fly.toml
min_machines_running = 1    # Prevents cold starts
memory = '4gb'              # Adjust based on graph size
force_https = true          # Enforces HTTPS
```

### 4. Set Secrets

```bash
# Set all required secrets
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
fly secrets set PHX_HOST=your-app.fly.dev
fly secrets set GOOGLE_API_KEY=...

# Optional secrets
fly secrets set RESEND_API_KEY=re_...
fly secrets set OBAN_LLM_CONCURRENCY=5

# List all secrets (values are hidden)
fly secrets list
```

### 5. Deploy

```bash
# First deployment
fly launch

# Follow prompts:
# - Choose app name
# - Select region
# - Decline to set up Postgres if already done

# Subsequent deployments
fly deploy

# Watch deployment logs
fly logs
```

### 6. Scale (if needed)

```bash
# Scale horizontally (add more machines)
fly scale count 2

# Scale vertically (increase memory)
fly scale memory 8192

# Check current scaling
fly scale show
```

## Post-Deployment

### 1. Verify Deployment

#### Check Health

```bash
curl https://your-app.fly.dev/health
# Expected: {"status":"ok","timestamp":"..."}

curl https://your-app.fly.dev/health/deep
# Expected: {"status":"ok","checks":{...},"timestamp":"..."}
```

#### Check HTTPS Redirect

```bash
curl -I http://your-app.fly.dev
# Expected: 301 redirect to https://
```

#### Check Security Headers

```bash
curl -I https://your-app.fly.dev
# Should include:
# - strict-transport-security
# - content-security-policy
# - x-frame-options
# - x-content-type-options
```

### 2. Test Rate Limiting

```bash
# Test authentication rate limit (should block after 5 requests)
for i in {1..10}; do
  curl -X POST https://your-app.fly.dev/users/log_in \
    -H "Content-Type: application/json" \
    -d '{"user":{"email":"test@test.com","password":"wrong"}}'
  echo "Request $i"
done
# Expected: 429 Too Many Requests after 5 attempts
```

### 3. Test Application

- [ ] Visit your app URL
- [ ] Create a new user account
- [ ] Test login/logout
- [ ] Create a graph
- [ ] Test LLM generation
- [ ] Verify data persistence (reload page)
- [ ] Check that graphs save properly

### 4. Set Up Monitoring

#### Fly.io Metrics

```bash
# View application metrics
fly dashboard

# Watch logs in real-time
fly logs

# Check application status
fly status
```

#### External Monitoring

Set up external monitoring for:
- Health check endpoint (`/health`)
- Response times
- Error rates
- Database connections
- API usage (LLM provider)

Recommended tools:
- UptimeRobot (free uptime monitoring)
- Better Uptime
- PagerDuty
- DataDog

### 5. Set Up Alerts

Configure alerts for:
- Application downtime
- Health check failures
- High error rates
- Database connection issues
- Rate limit violations
- LLM API quota warnings

## Monitoring

### Application Logs

```bash
# Real-time logs
fly logs

# Filter by level
fly logs --level error

# Follow specific instance
fly logs --instance <instance-id>
```

### Key Metrics to Monitor

#### Application Health
- HTTP response times
- Error rates (4xx, 5xx)
- Request throughput
- Memory usage
- CPU usage

#### Database
- Connection pool usage
- Query performance
- Disk usage
- Replication lag (if applicable)

#### Background Jobs (Oban)
- Queue depth
- Job success/failure rate
- Processing time
- Failed job count

#### LLM Usage
- API call volume
- Response times
- Error rates
- Quota consumption
- Cost tracking

### Performance Benchmarks

Expected performance (adjust based on your setup):
- Health check: < 10ms
- Page load: < 500ms
- Graph creation: 1-3s (depends on LLM)
- LLM generation: 5-30s (depends on response length)

## Troubleshooting

### Application Won't Start

```bash
# Check logs for errors
fly logs

# Common issues:
# 1. Missing environment variables
fly secrets list

# 2. Database connection issues
fly ssh console
/app/bin/dialectic rpc "Dialectic.Repo.query!(\"SELECT 1\")"

# 3. Migration issues
fly ssh console
/app/bin/migrate
```

### Database Connection Errors

```bash
# Check database status
fly postgres db list

# Check connection from app
fly ssh console
/app/bin/dialectic rpc "Dialectic.Repo.query!(\"SELECT 1\")"

# Common fixes:
# - Verify DATABASE_URL is set correctly
# - Check database is accepting connections
# - Verify SSL settings (DATABASE_SSL=true)
# - Check connection pool settings
```

### Out of Memory

```bash
# Check current memory usage
fly vm status

# Scale up memory
fly scale memory 8192

# Or reduce memory usage by:
# - Reducing POOL_SIZE
# - Reducing Oban concurrency
# - Optimizing graph data size
```

### Rate Limiting Issues

If legitimate users are being rate limited:

```bash
# Adjust rate limits in code:
# lib/dialectic_web/plugs/rate_limiter.ex

# Increase limits:
defp get_limits(:api) do
  {120, 60_000}  # 120 requests per minute instead of 60
end

# Deploy changes
fly deploy
```

### LLM API Errors

```bash
# Check API key is set
fly secrets list | grep API_KEY

# Test API connectivity
fly ssh console
/app/bin/dialectic rpc "System.get_env(\"GOOGLE_API_KEY\")"

# Check Oban job failures
fly ssh console
/app/bin/dialectic rpc "Oban.check_queue(:llm_request)"
```

### SSL Certificate Issues

Fly.io automatically manages SSL certificates. If issues occur:

```bash
# Check certificate status
fly certs show

# Force certificate renewal
fly certs create yourdomain.com
```

## Rolling Back

### Rollback Deployment

```bash
# List recent releases
fly releases

# Rollback to previous release
fly releases rollback

# Rollback to specific version
fly releases rollback v42
```

### Rollback Database Migration

```bash
# SSH into app
fly ssh console

# Rollback one migration
/app/bin/dialectic eval "Dialectic.Release.rollback(Dialectic.Repo, 20260106112233)"

# Note: Only rollback migrations that are safe to rollback
# Some data migrations cannot be safely reversed
```

### Emergency Shutdown

```bash
# Stop all machines
fly machine stop --all

# Restart when ready
fly machine start --all
```

## Backup and Recovery

### Database Restore Runbook

Production uses the unmanaged Fly Postgres app `mudg-db`. It has continuous WAL backups for point-in-time recovery and daily Fly volume snapshots. Prefer a WAL restore; use a volume snapshot only if WAL restore is unavailable.

Never restore over `mudg-db`. Restore into a new Postgres app, validate it, and only then point `mudg` at it. Keep the original database until the restored service has been stable long enough to provide a rollback path.

#### 1. Identify the recovery point

```bash
fly pg backup config show --app mudg-db
fly pg backup list --app mudg-db
```

For accidental deletion or a bad migration, choose a UTC timestamp immediately before the incident in RFC3339 format, such as `2026-08-21T10:30:00Z`. If no timestamp is supplied, Fly restores to the latest available point.

#### 2. Restore into a new cluster

Use a unique destination app name:

```bash
fly pg backup restore mudg-db-restore-YYYYMMDD \
  --app mudg-db \
  --restore-target-time 2026-08-21T10:30:00Z
```

To restore a named full backup instead of a timestamp, use `--restore-target-name <backup-id>`. Do not pass both target options.

Wait for the restored cluster to become healthy:

```bash
fly status --app mudg-db-restore-YYYYMMDD
fly checks list --app mudg-db-restore-YYYYMMDD
fly pg db list --app mudg-db-restore-YYYYMMDD
```

#### 3. Validate before cutover

Connect to the restored cluster and inspect the `mudg` database:

```bash
fly pg connect --app mudg-db-restore-YYYYMMDD --database mudg
```

At minimum, check representative users, graphs, notes, highlights, and the latest timestamps. Check `schema_migrations` against the application release you intend to run. Also inspect `oban_jobs`: restoring starts with the historical job table, so jobs that were pending at the recovery point may execute when the application reconnects.

For a high-impact incident, connect a temporary staging application to the restored cluster and perform login and graph-loading smoke tests before production cutover.

#### 4. Cut over production

Announce a write freeze or maintenance window first. Writes accepted by the old database after the selected recovery point will not exist in the restored database.

Stop or otherwise block writes from `mudg`, then attach the restored cluster. Use the existing database name and a new attachment user to avoid colliding with the restored `mudg` role. Fly creates this user with its default attachment privileges, which are currently required to access and migrate the restored schema:

```bash
fly pg attach mudg-db-restore-YYYYMMDD \
  --app mudg \
  --database-name mudg \
  --database-user mudg_restore
```

Confirm any prompt to replace `DATABASE_URL`. Rotate or reduce the attachment user's privileges after the incident if the application no longer requires them. If Fly refuses because `mudg-db` is still registered as attached, detach it while the application is stopped, then repeat the attach command:

```bash
fly pg detach mudg-db --app mudg
```

Verify production immediately:

```bash
fly checks list --app mudg
fly logs --app mudg
```

Test login, graph loading, writes, and background jobs. Do not destroy `mudg-db` during the incident. Record the recovery timestamp and new database app name.

#### Volume snapshot fallback

If WAL backup restore is unavailable, list the database volume and snapshots, then restore using the same Postgres image version:

```bash
fly volumes list --app mudg-db
fly volumes snapshots list <volume-id> --app mudg-db
fly image show --app mudg-db
fly pg create \
  --snapshot-id <snapshot-id> \
  --image-ref flyio/postgres-flex:<matching-version>
```

Validate and cut over using the same procedure above. Volume snapshots currently have a shorter and less precise recovery window than WAL backups.

### Application State

Graph and account data is stored in Postgres. Uploaded avatars and banners are stored separately in Tigris and are not recovered by a database restore.

## Production Maintenance

### Regular Tasks

#### Weekly
- [ ] Review error logs
- [ ] Check health check status
- [ ] Monitor resource usage trends
- [ ] Review rate limit violations
- [ ] Check LLM API usage and costs

#### Monthly
- [ ] Review and rotate API keys (if policy requires)
- [ ] Update dependencies (`mix deps.update --all`)
- [ ] Review database performance
- [ ] Clean up old Oban jobs
- [ ] Review application metrics

#### Quarterly
- [ ] Security audit
- [ ] Load testing
- [ ] Disaster recovery drill
- [ ] Review and update documentation
- [ ] Capacity planning

### Updating Dependencies

```bash
# Check for outdated dependencies
mix hex.outdated

# Update dependencies
mix deps.update --all

# Run tests
mix test

# Deploy if all tests pass
fly deploy
```

### Security Updates

```bash
# Check for security advisories
mix hex.audit

# Update vulnerable dependencies immediately
mix deps.update <vulnerable-package>

# Deploy security updates
fly deploy
```

## Cost Optimization

### Reduce Fly.io Costs

```bash
# Scale down when not needed
fly scale count 1
fly scale memory 2048

# Use auto-stop (but increases cold starts)
# Edit fly.toml:
# auto_stop_machines = 'stop'
# min_machines_running = 0
```

### Reduce LLM API Costs

- Set `OBAN_LLM_CONCURRENCY=3` to limit concurrent requests
- Implement per-user quotas
- Monitor and alert on high usage
- Cache common responses (if applicable)

### Optimize Database

- Regular VACUUM and ANALYZE
- Remove old data
- Optimize indexes
- Consider read replicas for scaling

## Support and Resources

### Documentation
- [Fly.io Docs](https://fly.io/docs/)
- [Phoenix Deployment Guide](https://hexdocs.pm/phoenix/deployment.html)
- [Elixir Releases](https://hexdocs.pm/mix/Mix.Tasks.Release.html)

### Getting Help
- Fly.io Community Forum
- Elixir Forum
- Phoenix Discord
- Your team's internal documentation

### Emergency Contacts
- Database Admin: [contact info]
- DevOps Lead: [contact info]
- Security Team: [contact info]
- LLM Provider Support: [provider support URL]

---

**Last Updated**: 2024-01-06
**Version**: 1.0
**Maintained By**: [Your Team Name]
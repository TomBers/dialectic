# Production Deployment Checklist

**Date**: _________________  
**Deployed By**: _________________  
**Version**: _________________

---

## Pre-Deployment Checklist

### Code & Dependencies
- [ ] All tests passing (`mix test`)
- [ ] Code formatted (`mix format`)
- [ ] No compilation warnings (`mix compile --warnings-as-errors`)
- [ ] Dependencies updated and audited (`mix hex.audit`)
- [ ] Git repository is clean (no uncommitted changes)
- [ ] Changes reviewed and approved

### Environment Variables
- [ ] `SECRET_KEY_BASE` set (generate with `mix phx.gen.secret`)
- [ ] `PHX_HOST` configured with your domain
- [ ] `DATABASE_URL` configured
- [ ] `DATABASE_SSL=true` (or `false` if using local DB)
- [ ] LLM provider API key set:
  - [ ] `OPENAI_API_KEY` (if using OpenAI)
  - [ ] `GOOGLE_API_KEY` (if using Google/Gemini)
  - [ ] `LLM_PROVIDER` set correctly
- [ ] `PORT` configured (default: 8080)
- [ ] `PHX_SERVER=true` for production

### Database
- [ ] Database created and accessible
- [ ] Database SSL enabled (if production)
- [ ] Connection string tested
- [ ] Backup strategy in place
- [ ] Migration scripts tested

### Infrastructure
- [ ] fly.toml reviewed and configured
- [ ] Memory allocation appropriate (4GB recommended)
- [ ] Min machines set to 1 (prevents cold starts)
- [ ] Health check configured (`/health`)
- [ ] Secrets set in hosting platform

---

## Deployment Steps

### 1. Run Migrations
```bash
# For Fly.io
fly ssh console --app your-app-name
/app/bin/migrate

# Or locally (be careful!)
MIX_ENV=prod mix ecto.migrate
```
- [ ] Migrations completed successfully
- [ ] No errors in migration logs

### 2. Deploy Application
```bash
# For Fly.io
fly deploy

# Watch deployment
fly logs
```
- [ ] Deployment completed successfully
- [ ] Application started without errors
- [ ] No crash loops detected

### 3. Verify Basic Functionality
```bash
# Check health endpoint
curl https://your-app.fly.dev/health
# Expected: {"status":"ok","timestamp":"..."}
```
- [ ] Health check returns 200 OK
- [ ] Application responds to requests

---

## Post-Deployment Verification

### Security Checks

#### HTTPS Enforcement
```bash
curl -I http://your-app.fly.dev
# Expected: 301 redirect to https://
```
- [ ] HTTP redirects to HTTPS
- [ ] HSTS header present

#### Security Headers
```bash
curl -I https://your-app.fly.dev
```
- [ ] `strict-transport-security` header present
- [ ] `content-security-policy` header present
- [ ] `x-frame-options: SAMEORIGIN` present
- [ ] `x-content-type-options: nosniff` present
- [ ] `x-xss-protection` header present

#### Rate Limiting
```bash
# Test auth endpoint (should block after 5 attempts)
for i in {1..10}; do
  curl -X POST https://your-app.fly.dev/users/log_in \
    -H "Content-Type: application/json" \
    -d '{"user":{"email":"test@test.com","password":"wrong"}}'
  echo "Request $i"
done
```
- [ ] Rate limiting active
- [ ] 429 response after limit exceeded

### Deep Health Check
```bash
curl https://your-app.fly.dev/health/deep
```
- [ ] Database check: "ok"
- [ ] Oban check: "ok"
- [ ] Application check: "ok"

### Functional Tests
- [ ] Can access homepage
- [ ] User registration works
- [ ] User login works
- [ ] Can create a new graph
- [ ] LLM generation works
- [ ] Data persists after page reload
- [ ] Graphs save correctly

### Performance Tests
- [ ] Page load time < 2 seconds
- [ ] Health check response < 50ms
- [ ] Database queries fast (check logs)
- [ ] No memory leaks detected

---

## Monitoring Setup

### Configure Alerts
- [ ] Health check monitoring configured
  - [ ] URL: `https://your-app.fly.dev/health`
  - [ ] Frequency: Every 30 seconds
  - [ ] Alert on: Non-200 responses
- [ ] Error rate monitoring
  - [ ] Alert on: > 1% 5xx responses
  - [ ] Window: 5 minutes
- [ ] Rate limit violations
  - [ ] Alert on: > 100 429s per hour
- [ ] Database connection pool
  - [ ] Alert on: > 80% utilization

### Set Up Logging
- [ ] Log aggregation configured
- [ ] Log retention policy set
- [ ] Error notifications enabled
- [ ] Sensitive data redaction verified

### Dashboard Access
- [ ] Team has access to Fly.io dashboard
- [ ] Monitoring tools configured
- [ ] Alert channels set up (email, Slack, etc.)

---

## Documentation

- [ ] Deployment documented in team wiki
- [ ] Environment variables documented
- [ ] Rollback procedure reviewed
- [ ] Team trained on new features
- [ ] SECURITY.md reviewed by team
- [ ] DEPLOYMENT.md available to team

---

## Rollback Plan

### If Issues Occur

**Immediate Rollback:**
```bash
fly releases rollback
```

**Database Rollback (if needed):**
```bash
fly ssh console
/app/bin/dialectic eval "Dialectic.Release.rollback(Dialectic.Repo, 20260106112233)"
```

- [ ] Rollback procedure tested
- [ ] Team knows how to rollback
- [ ] Database backup available

---

## Production Readiness Score

Rate each category from 1-5 (5 = excellent):

- Security: _____ / 5
- Performance: _____ / 5
- Monitoring: _____ / 5
- Documentation: _____ / 5
- Team Readiness: _____ / 5

**Overall Score**: _____ / 25

**Minimum passing score**: 20/25

---

## Sign-Off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Developer | | | |
| Tech Lead | | | |
| DevOps | | | |
| Security | | | |

---

## Post-Deployment Tasks (First 24 Hours)

- [ ] Monitor error rates
- [ ] Check database performance
- [ ] Review application logs
- [ ] Verify rate limiting effectiveness
- [ ] Monitor LLM API usage and costs
- [ ] Check health check uptime
- [ ] Review user feedback

## Post-Deployment Tasks (First Week)

- [ ] Review performance metrics
- [ ] Analyze rate limit violations
- [ ] Check database query performance
- [ ] Review Oban job success rates
- [ ] Monitor memory usage trends
- [ ] Verify backups are working
- [ ] Update documentation based on learnings

## Post-Deployment Tasks (First Month)

- [ ] Conduct load testing
- [ ] Review security logs
- [ ] Optimize slow queries
- [ ] Review and adjust rate limits
- [ ] Plan for scaling if needed
- [ ] Conduct post-mortem meeting
- [ ] Document lessons learned

---

## Emergency Contacts

- **On-Call Engineer**: ________________
- **Database Admin**: ________________
- **Security Team**: ________________
- **Fly.io Support**: https://community.fly.io
- **OpenAI Support**: https://help.openai.com (if using OpenAI)
- **Google Cloud Support**: https://cloud.google.com/support (if using Google)

---

## Notes

_Use this space to document any deployment-specific notes, issues encountered, or deviations from the standard process._

---

**Checklist Version**: 1.0  
**Last Updated**: 2024-01-06
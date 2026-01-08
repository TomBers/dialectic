#!/bin/bash
set -e

echo "🚀 Deploying health check fix to Fly.io..."
echo ""
echo "Changes include:"
echo "  ✅ Removed rate limiting from health check endpoints"
echo "  ✅ Simplified /health/deep for faster responses"
echo ""

# Deploy
echo "Deploying..."
fly deploy --app dialectic --strategy immediate

echo ""
echo "Deployment complete! Monitoring logs..."
echo "Press Ctrl+C to stop monitoring"
echo ""

# Monitor logs for health checks
fly logs --app dialectic | grep -E "(health|Health|429|503)"

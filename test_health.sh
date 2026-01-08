#!/bin/bash

APP_URL="https://mudg.fly.dev"

echo "Testing health endpoints..."
echo ""

echo "1. Testing /health (should always work):"
for i in {1..5}; do
  response=$(curl -s -w "\n%{http_code}" "$APP_URL/health" 2>/dev/null)
  code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)
  
  if [ "$code" == "200" ]; then
    echo "  ✅ Request $i: HTTP $code"
  else
    echo "  ❌ Request $i: HTTP $code - $body"
  fi
  sleep 0.5
done

echo ""
echo "2. Testing /health/deep (should not be rate limited):"
for i in {1..10}; do
  response=$(curl -s -w "\n%{http_code}" "$APP_URL/health/deep" 2>/dev/null)
  code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)
  
  if [ "$code" == "200" ]; then
    echo "  ✅ Request $i: HTTP $code"
  elif [ "$code" == "429" ]; then
    echo "  ❌ Request $i: HTTP $code (RATE LIMITED - THIS IS BAD!)"
  else
    echo "  ⚠️  Request $i: HTTP $code - $body"
  fi
  sleep 0.5
done

echo ""
echo "If you see any 429 errors above, the fix didn't deploy correctly."
echo "All requests should return 200 OK."

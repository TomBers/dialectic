#!/bin/bash
echo "Checking router configuration..."
grep -A 3 "pipeline :health" lib/dialectic_web/router.ex
echo ""
echo "Checking if health uses :health pipeline..."
grep -A 3 "scope \"/health\"" lib/dialectic_web/router.ex
echo ""
echo "Git status:"
git status --short
echo ""
echo "Last commit:"
git log -1 --oneline

#!/bin/bash

# Pre-Run Checks
# Run this before `flutter run` to verify tests pass

set -e

echo "========================================="
echo "🔍 Pre-Run Checks"
echo "========================================="
echo ""

# Run tests in fast mode (no coverage)
./test_runner.sh

echo ""
echo "${GREEN}✅ All checks passed! Safe to run app.${NC}"
echo ""
echo "To run the app:"
echo "  flutter run"
echo ""


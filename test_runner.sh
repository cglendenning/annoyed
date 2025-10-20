#!/bin/bash

# Auth State Machine Test Runner
# Runs all authentication tests and reports results

set -e

echo "========================================="
echo "🧪 Running Auth State Machine Tests"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "${RED}❌ Flutter not found. Please install Flutter first.${NC}"
    exit 1
fi

echo "${YELLOW}📦 Installing dependencies...${NC}"
flutter pub get

echo ""
echo "${YELLOW}🔨 Generating mocks...${NC}"
flutter pub run build_runner build --delete-conflicting-outputs

echo ""
echo "${YELLOW}🧪 Running unit tests...${NC}"
echo "---"
flutter test test/auth_state_manager_test.dart --reporter expanded

echo ""
echo "${YELLOW}🎨 Running widget tests...${NC}"
echo "---"
flutter test test/auth_gate_widget_test.dart --reporter expanded

echo ""
echo "${YELLOW}🔄 Running integration tests...${NC}"
echo "---"
flutter test test/auth_flows_integration_test.dart --reporter expanded

echo ""
echo "========================================="
echo "${GREEN}✅ All auth tests completed!${NC}"
echo "========================================="
echo ""

# Generate coverage report (optional)
if [ "$1" = "--coverage" ]; then
    echo "${YELLOW}📊 Generating coverage report...${NC}"
    flutter test --coverage
    genhtml coverage/lcov.info -o coverage/html
    echo "${GREEN}Coverage report generated at: coverage/html/index.html${NC}"
    
    # Open in browser if on macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open coverage/html/index.html
    fi
fi

echo ""
echo "To run specific test files:"
echo "  flutter test test/auth_state_manager_test.dart"
echo "  flutter test test/auth_gate_widget_test.dart"
echo "  flutter test test/auth_flows_integration_test.dart"
echo ""
echo "To run with coverage:"
echo "  ./test_runner.sh --coverage"
echo ""


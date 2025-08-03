#!/bin/bash

# iOS Test Runner Script for Botany Battle
# Runs all tests with proper configuration and reporting

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Botany Battle iOS Test Runner${NC}"
echo "=================================="

# Configuration
PROJECT_PATH="BotanyBattle.xcodeproj"
SCHEME="BotanyBattle"
TEST_SCHEME="Botany BattleTests"
SIMULATOR_NAME="iPhone 15"
SIMULATOR_OS="17.5"
DERIVED_DATA_PATH="./DerivedData"
TEST_RESULTS_PATH="./TestResults"

# Clean up previous test results
echo -e "${YELLOW}🧹 Cleaning up previous test results...${NC}"
rm -rf "$DERIVED_DATA_PATH"
rm -rf "$TEST_RESULTS_PATH"
mkdir -p "$TEST_RESULTS_PATH"

# Check if project exists
if [ ! -d "$PROJECT_PATH" ]; then
    echo -e "${RED}❌ Error: Xcode project not found at $PROJECT_PATH${NC}"
    exit 1
fi

# List available simulators
echo -e "${BLUE}📱 Available iOS Simulators:${NC}"
xcrun simctl list devices iOS | grep "iPhone\|iPad" | head -5

# Boot simulator if not running
echo -e "${YELLOW}🚀 Ensuring simulator is booted...${NC}"
SIMULATOR_UDID=$(xcrun simctl list devices | grep "$SIMULATOR_NAME" | grep "$SIMULATOR_OS" | grep -oE '[A-F0-9-]{36}' | head -1)

if [ -z "$SIMULATOR_UDID" ]; then
    echo -e "${RED}❌ Error: Could not find simulator '$SIMULATOR_NAME' with iOS $SIMULATOR_OS${NC}"
    echo "Available simulators:"
    xcrun simctl list devices iOS
    exit 1
fi

echo -e "${BLUE}Using simulator: $SIMULATOR_NAME ($SIMULATOR_UDID)${NC}"
xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true

# Wait for simulator to be ready
echo -e "${YELLOW}⏳ Waiting for simulator to be ready...${NC}"
sleep 5

# Run unit tests
echo -e "${GREEN}🔬 Running Unit Tests...${NC}"
xcodebuild test \
    -project "$PROJECT_PATH" \
    -scheme "$TEST_SCHEME" \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=$SIMULATOR_OS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -resultBundlePath "$TEST_RESULTS_PATH/UnitTests.xcresult" \
    -testPlan "UnitTests" \
    | xcpretty --color --report junit --output "$TEST_RESULTS_PATH/unit-tests.xml" || {
        echo -e "${RED}❌ Unit tests failed${NC}"
        UNIT_TEST_FAILED=true
    }

# Run integration tests
echo -e "${GREEN}🔗 Running Integration Tests...${NC}"
xcodebuild test \
    -project "$PROJECT_PATH" \
    -scheme "$TEST_SCHEME" \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=$SIMULATOR_OS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -resultBundlePath "$TEST_RESULTS_PATH/IntegrationTests.xcresult" \
    -testPlan "IntegrationTests" \
    | xcpretty --color --report junit --output "$TEST_RESULTS_PATH/integration-tests.xml" || {
        echo -e "${RED}❌ Integration tests failed${NC}"
        INTEGRATION_TEST_FAILED=true
    }

# Run multiplayer tests
echo -e "${GREEN}🎮 Running Multiplayer Tests...${NC}"
xcodebuild test \
    -project "$PROJECT_PATH" \
    -scheme "$TEST_SCHEME" \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME,OS=$SIMULATOR_OS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -resultBundlePath "$TEST_RESULTS_PATH/MultiplayerTests.xcresult" \
    -testPlan "MultiplayerTests" \
    | xcpretty --color --report junit --output "$TEST_RESULTS_PATH/multiplayer-tests.xml" || {
        echo -e "${RED}❌ Multiplayer tests failed${NC}"
        MULTIPLAYER_TEST_FAILED=true
    }

# Generate code coverage report
echo -e "${BLUE}📊 Generating Code Coverage Report...${NC}"
xcrun xccov view --report --json "$DERIVED_DATA_PATH/Logs/Test/"*.xcresult > "$TEST_RESULTS_PATH/coverage.json" || {
    echo -e "${YELLOW}⚠️  Could not generate coverage report${NC}"
}

# Extract coverage percentage
if [ -f "$TEST_RESULTS_PATH/coverage.json" ]; then
    COVERAGE=$(python3 -c "
import json
import sys
try:
    with open('$TEST_RESULTS_PATH/coverage.json') as f:
        data = json.load(f)
        coverage = data.get('lineCoverage', 0) * 100
        print(f'{coverage:.2f}%')
except:
    print('N/A')
")
    echo -e "${BLUE}Code Coverage: $COVERAGE${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}📋 Test Summary${NC}"
echo "================"

if [ -z "$UNIT_TEST_FAILED" ]; then
    echo -e "Unit Tests: ${GREEN}✅ PASSED${NC}"
else
    echo -e "Unit Tests: ${RED}❌ FAILED${NC}"
fi

if [ -z "$INTEGRATION_TEST_FAILED" ]; then
    echo -e "Integration Tests: ${GREEN}✅ PASSED${NC}"
else
    echo -e "Integration Tests: ${RED}❌ FAILED${NC}"
fi

if [ -z "$MULTIPLAYER_TEST_FAILED" ]; then
    echo -e "Multiplayer Tests: ${GREEN}✅ PASSED${NC}"
else
    echo -e "Multiplayer Tests: ${RED}❌ FAILED${NC}"
fi

echo -e "Test Results: ${BLUE}$TEST_RESULTS_PATH${NC}"
echo -e "Coverage Report: ${BLUE}$TEST_RESULTS_PATH/coverage.json${NC}"

# Shutdown simulator
echo -e "${YELLOW}🔄 Shutting down simulator...${NC}"
xcrun simctl shutdown "$SIMULATOR_UDID" 2>/dev/null || true

# Exit with error if any tests failed
if [ -n "$UNIT_TEST_FAILED" ] || [ -n "$INTEGRATION_TEST_FAILED" ] || [ -n "$MULTIPLAYER_TEST_FAILED" ]; then
    echo -e "${RED}❌ Some tests failed. Check the results above.${NC}"
    exit 1
else
    echo -e "${GREEN}🎉 All tests passed successfully!${NC}"
    exit 0
fi
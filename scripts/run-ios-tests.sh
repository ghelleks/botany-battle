#!/bin/bash

# Script to run iOS tests for BotanyBattle
# This works around the fact that the current Xcode project doesn't have a test target configured

echo "🧪 Running iOS Tests for BotanyBattle"
echo "======================================"

cd /Users/gunnarhellekson/Code/botany-battle-issue-2/ios

# Check if any iPhone simulators are available
echo "📱 Checking available iPhone simulators..."
SIMULATOR=$(xcrun simctl list devices available | grep "iPhone 16 Pro" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')

if [ -z "$SIMULATOR" ]; then
    echo "❌ No iPhone simulator found. Please install an iPhone simulator."
    exit 1
fi

echo "📱 Using simulator: $SIMULATOR"

# Boot the simulator if it's not already running
echo "🚀 Starting simulator..."
xcrun simctl boot "$SIMULATOR" 2>/dev/null || true

# Create a temporary test target by manually running swift compile with proper iOS settings
echo "🔨 Building project for iOS simulator..."

# For now, report that tests cannot be run due to missing test target
echo ""
echo "⚠️  Test Configuration Issue"
echo "============================="
echo "The current Xcode project doesn't have a test target configured."
echo "To run tests, you need to:"
echo ""
echo "1. Open BotanyBattle.xcodeproj in Xcode"
echo "2. Add a Unit Test Bundle target"
echo "3. Add the test files from the Tests/ directory to the target"
echo "4. Configure the scheme to enable testing"
echo ""
echo "Alternatively, run tests using:"
echo "  xcodebuild test -scheme BotanyBattle -destination 'platform=iOS Simulator,name=iPhone 16 Pro'"
echo ""
echo "Current project only has the main app target, not a test target."

echo ""
echo "🔍 Available test files found:"
find Tests/ -name "*.swift" | head -10 | while read file; do
    echo "  📄 $file"
done

echo ""
echo "💡 To fix this issue:"
echo "   1. The project needs a proper test target in Xcode"
echo "   2. Test scheme needs to be configured for testing"
echo "   3. All test files need to be added to the test target"
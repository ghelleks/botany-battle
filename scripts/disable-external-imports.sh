#!/bin/bash

echo "🔧 Temporarily disabling external imports in test files"
echo "====================================================="

cd /Users/gunnarhellekson/Code/botany-battle-issue-2/ios/Tests

# List of files that import external dependencies
FILES_WITH_EXTERNAL_DEPS=(
    "UserServiceIntegrationTests.swift"
    "GameModeSelectionIntegrationTest.swift"
    "SingleUserGameFlowTests.swift"
    "AuthFeatureTests.swift"
    "SingleUserGameTests.swift"
    "EndToEndIntegrationTests.swift"
    "GameTimerTests.swift"
    "AppFeatureTests.swift"
    "PerformanceIntegrationTests.swift"
    "AuthenticationIntegrationTests.swift"
)

echo "📁 Backing up files..."
for file in "${FILES_WITH_EXTERNAL_DEPS[@]}"; do
    if [[ -f "$file" ]]; then
        cp "$file" "$file.backup"
        echo "   ✅ Backed up $file"
    fi
done

echo ""
echo "🚫 Commenting out external imports..."
for file in "${FILES_WITH_EXTERNAL_DEPS[@]}"; do
    if [[ -f "$file" ]]; then
        # Comment out ComposableArchitecture imports
        sed -i '' 's/^import ComposableArchitecture$/\/\/ import ComposableArchitecture/' "$file"
        # Comment out Dependencies imports  
        sed -i '' 's/^import Dependencies$/\/\/ import Dependencies/' "$file"
        # Comment out Starscream imports
        sed -i '' 's/^import Starscream$/\/\/ import Starscream/' "$file"
        echo "   🔧 Modified $file"
    fi
done

echo ""
echo "✅ Done! Now you can run basic tests with:"
echo "   xcodebuild test -scheme BotanyBattle -destination 'platform=iOS Simulator,name=iPhone 16 Pro'"
echo ""
echo "⚠️  Note: Tests that depend on external frameworks will be disabled"
echo "📄 To restore: run scripts/restore-external-imports.sh"
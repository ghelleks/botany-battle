#!/bin/bash

echo "🔧 Setting up Unit Test Bundle for BotanyBattle"
echo "==============================================="

cd /Users/gunnarhellekson/Code/botany-battle-issue-2/ios

echo "📂 Current project structure:"
xcodebuild -list

echo ""
echo "📝 Instructions to add Unit Test Bundle manually:"
echo ""
echo "1. Open Xcode:"
echo "   open BotanyBattle.xcodeproj"
echo ""
echo "2. In Xcode project navigator:"
echo "   • Select 'BotanyBattle' project (top level)"
echo "   • In the main editor, you'll see TARGETS section"
echo "   • Click the '+' button below the targets list"
echo ""
echo "3. In the template chooser:"
echo "   • Select 'iOS' tab"
echo "   • Choose 'Unit Testing Bundle'"
echo "   • Click 'Next'"
echo ""
echo "4. Configure the test bundle:"
echo "   • Product Name: BotanyBattleTests"
echo "   • Target to be Tested: BotanyBattle"
echo "   • Click 'Finish'"
echo ""
echo "5. Add existing test files:"
echo "   • Delete the default BotanyBattleTests.swift file Xcode creates"
echo "   • Right-click 'BotanyBattleTests' group in navigator"
echo "   • Choose 'Add Files to BotanyBattle'"
echo "   • Navigate to Tests/ folder"
echo "   • Select all .swift files"
echo "   • Ensure 'BotanyBattleTests' target is checked"
echo "   • Click 'Add'"
echo ""
echo "6. Configure test scheme:"
echo "   • Product → Scheme → Edit Scheme"
echo "   • Select 'Test' on the left"
echo "   • Verify 'BotanyBattleTests' is listed and enabled"
echo ""
echo "7. Run tests:"
echo "   • Product → Test (⌘+U)"
echo "   • Or: xcodebuild test -scheme BotanyBattle -destination 'platform=iOS Simulator,name=iPhone 15'"
echo ""

echo "📁 Test files to be added ($(find Tests/ -name "*.swift" | wc -l) files):"
find Tests/ -name "*.swift" | sort | while read file; do
    echo "   📄 $file"
done

echo ""
echo "💡 After setup, verify with:"
echo "   xcodebuild -list"
echo "   # Should show BotanyBattleTests in targets"
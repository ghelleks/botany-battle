#!/bin/bash

echo "🔄 Restoring external imports in test files"
echo "==========================================="

cd /Users/gunnarhellekson/Code/botany-battle-issue-2/ios/Tests

echo "📁 Restoring from backups..."
for backup in *.backup; do
    if [[ -f "$backup" ]]; then
        original="${backup%.backup}"
        mv "$backup" "$original"
        echo "   ✅ Restored $original"
    fi
done

echo ""
echo "✅ All external imports restored!"
echo "💡 Make sure to add Swift packages to Xcode project for full functionality"
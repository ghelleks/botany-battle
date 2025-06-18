# Swift Package Dependencies Setup for BotanyBattle

## 🎯 Goal
Add Swift Package Manager dependencies to the Xcode project so tests can access external frameworks.

## 📦 Required Packages

Add these to your Xcode project:

### 1. ComposableArchitecture
- **URL**: `https://github.com/pointfreeco/swift-composable-architecture`
- **Version**: 1.0.0 or later
- **Product**: `ComposableArchitecture`

### 2. Dependencies
- **URL**: `https://github.com/pointfreeco/swift-dependencies`
- **Version**: 1.0.0 or later  
- **Product**: `Dependencies`

### 3. Alamofire
- **URL**: `https://github.com/Alamofire/Alamofire.git`
- **Version**: 5.8.0 or later
- **Product**: `Alamofire`

### 4. Starscream
- **URL**: `https://github.com/daltoniam/Starscream.git`
- **Version**: 4.0.0 or later
- **Product**: `Starscream`

### 5. SDWebImageSwiftUI
- **URL**: `https://github.com/SDWebImage/SDWebImageSwiftUI.git`
- **Version**: 2.2.0 or later
- **Product**: `SDWebImageSwiftUI`

## 🔧 Step-by-Step Instructions

### In Xcode:

1. **Open Project**:
   ```bash
   open ios/BotanyBattle.xcodeproj
   ```

2. **Add Package Dependencies**:
   - Go to **File** → **Add Package Dependencies...**
   - Enter each URL above, one by one
   - Choose appropriate version requirements
   - **Important**: Add to BOTH targets:
     - ✅ `BotanyBattle` (main app)
     - ✅ `Botany BattleTests` (test target)

3. **Verify Setup**:
   - Project Navigator should show "Package Dependencies" section
   - Both targets should list the packages under "Frameworks and Libraries"

## 🧪 Test After Setup

Once packages are added, run tests:
```bash
xcodebuild test -scheme BotanyBattle -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## 🔄 Alternative: Temporary Testing

If you want to test basic functionality without external dependencies:
```bash
# Temporarily disable external imports
./scripts/disable-external-imports.sh

# Run tests (only basic tests will work)
xcodebuild test -scheme BotanyBattle -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Restore when packages are configured
./scripts/restore-external-imports.sh
```

## ✅ Expected Result

After adding packages, all 22 test files should compile and run successfully.

## 🐛 Troubleshooting

If packages don't appear:
1. Clean build folder: **Product** → **Clean Build Folder**
2. Reset package caches: **File** → **Packages** → **Reset Package Caches**
3. Make sure both targets are selected when adding packages

## 📊 Current Status

- ✅ Test target created successfully
- ✅ 22 test files added to test target
- ❌ Swift package dependencies not configured
- ✅ Basic Xcode project builds successfully

The test infrastructure is complete - just needs package dependencies!
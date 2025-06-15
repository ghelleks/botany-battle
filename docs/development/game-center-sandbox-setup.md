# Game Center Sandbox Setup Guide

This guide walks through setting up Game Center sandbox accounts for testing the Botany Battle multiplayer functionality.

## Prerequisites

- Apple Developer Program membership
- Xcode with a valid Apple ID signed in
- Access to App Store Connect

## Step 1: App Store Connect Configuration

### 1.1 Create App Record
1. Log into [App Store Connect](https://appstoreconnect.apple.com)
2. Go to "My Apps" and create a new app if needed
3. Set Bundle ID to `com.botanybattle.app`
4. Enable Game Center for the app

### 1.2 Configure Game Center
1. In App Store Connect, select your app
2. Go to "Services" → "Game Center"
3. Enable Game Center for the app
4. Configure the following:

#### Leaderboards
- **Plant Master Rankings**: Track ELO ratings
- **Weekly Champions**: Weekly win counts
- **Identification Streak**: Longest correct identification streak

#### Achievements
- **First Victory**: Win your first game
- **Plant Expert**: Identify 100 plants correctly
- **Winning Streak**: Win 5 games in a row
- **Botanist**: Reach ELO rating of 1500
- **Master Botanist**: Reach ELO rating of 2000

## Step 2: Create Sandbox Test Accounts

### 2.1 Test Account Creation
1. In App Store Connect, go to "Users and Access"
2. Select "Sandbox Testers"
3. Create at least 3 test accounts for proper matchmaking testing:

#### Test Account 1: Beginner Player
- **Email**: `botanybattle.test1@icloud.com`
- **First Name**: `Test`
- **Last Name**: `Beginner`
- **Password**: `TestPass123!`
- **Region**: United States

#### Test Account 2: Intermediate Player  
- **Email**: `botanybattle.test2@icloud.com`
- **First Name**: `Test`
- **Last Name**: `Intermediate`
- **Password**: `TestPass123!`
- **Region**: United States

#### Test Account 3: Advanced Player
- **Email**: `botanybattle.test3@icloud.com`
- **First Name**: `Test`
- **Last Name**: `Advanced`
- **Password**: `TestPass123!`
- **Region**: United States

### 2.2 Device Configuration
For each test device/simulator:

1. **Sign out of Game Center**:
   - Settings → Game Center → Sign Out

2. **Clear Simulator Data** (if using simulator):
   ```bash
   xcrun simctl erase all
   ```

3. **Sign in with test account**:
   - Settings → Game Center → Sign In
   - Use one of the sandbox test accounts

## Step 3: Testing Scenarios

### 3.1 Authentication Testing
- **Single Player Login**: Verify each test account can authenticate
- **Account Switching**: Test switching between different sandbox accounts
- **Profile Data**: Verify Game Center profile information is loaded correctly

### 3.2 Matchmaking Testing
- **Same Skill Level**: Test matching players with similar ELO ratings
- **Cross Skill Level**: Test matchmaking across different skill levels
- **Wait Time**: Verify matchmaking timeout and range expansion
- **Multiple Devices**: Test real-time matching between different devices

### 3.3 Game Flow Testing
- **Real-time Sync**: Verify game state synchronization
- **Disconnect Handling**: Test behavior when one player disconnects
- **Completion**: Test full game completion and result recording

## Step 4: Development Testing Setup

### 4.1 Xcode Configuration
1. In Xcode, select your development team
2. Ensure Game Center capability is enabled
3. Set proper bundle identifier
4. Build and run on device (Game Center requires real device for full testing)

### 4.2 Testing Commands
```bash
# Build for device testing
xcodebuild -scheme BotanyBattle -destination 'platform=iOS,name=YOUR_DEVICE_NAME' build

# Run unit tests
xcodebuild test -scheme BotanyBattle -destination 'platform=iOS Simulator,name=iPhone 15'

# Run Game Center integration tests (requires real device)
xcodebuild test -scheme BotanyBattleGameCenterTests -destination 'platform=iOS,name=YOUR_DEVICE_NAME'
```

### 4.3 Debug Mode Features
Enable debug logging for Game Center in development:

```swift
// Add to AppDelegate or App struct
#if DEBUG
GKLocalPlayer.local.authenticateHandler = { viewController, error in
    print("Game Center Debug: Authentication result")
    print("View Controller: \(String(describing: viewController))")
    print("Error: \(String(describing: error))")
}
#endif
```

## Step 5: Common Testing Issues

### Issue: "Game Center Unavailable"
**Solution**: Ensure you're testing on a real device with proper Apple ID

### Issue: "No Multiplayer Support"  
**Solution**: Verify Game Center is enabled in device settings

### Issue: "Sandbox Account Not Working"
**Solution**: 
1. Sign out completely from Game Center
2. Clear app data
3. Sign in with correct sandbox credentials

### Issue: "Matchmaking Not Finding Players"
**Solution**: Use multiple devices or test accounts to populate the player pool

## Step 6: Production Transition

### 6.1 Before App Store Submission
- [ ] Test all Game Center features with sandbox accounts
- [ ] Verify leaderboards and achievements work correctly
- [ ] Test matchmaking with various skill levels
- [ ] Confirm all error handling works properly

### 6.2 Post-Launch Monitoring
- Monitor Game Center analytics in App Store Connect
- Track authentication success rates
- Monitor matchmaking performance metrics
- Gather user feedback on multiplayer experience

## Useful Resources

- [Game Center Programming Guide](https://developer.apple.com/documentation/gamekit)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [Game Center Sandbox Testing](https://developer.apple.com/documentation/gamekit/testing_game_center_apps)

## Support

For issues with Game Center sandbox setup:
1. Check Apple Developer Forums
2. Review Game Center documentation
3. Contact Apple Developer Support
4. Check project documentation in `/docs/troubleshooting/`
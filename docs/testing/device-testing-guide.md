# Device Testing Guide for Multi-player Features

**Phase**: Physical Device Testing  
**Goal**: Validate Game Center authentication and multi-player functionality on real iOS devices

## Prerequisites Checklist

### Hardware Requirements
- [ ] 2+ iOS devices (iPhone/iPad) running iOS 15.0+
- [ ] Apple Developer account with valid certificates
- [ ] Devices registered in Apple Developer portal
- [ ] Stable WiFi network for both devices

### Software Requirements
- [ ] Xcode 15.0+ with valid development team
- [ ] Game Center enabled in device Settings
- [ ] iTunes/Finder for device deployment

## Step 1: Game Center Sandbox Account Setup

### Create Sandbox Test Accounts
1. **Go to App Store Connect**:
   - Visit [https://appstoreconnect.apple.com](https://appstoreconnect.apple.com)
   - Navigate to "Users and Access" → "Sandbox Testers"

2. **Create Test Accounts**:
   ```
   Account 1 (Player 1):
   Email: botanybattle.test1@icloud.com
   Password: TestPass123!
   First Name: Test
   Last Name: Player1
   Country: United States
   
   Account 2 (Player 2):
   Email: botanybattle.test2@icloud.com  
   Password: TestPass123!
   First Name: Test
   Last Name: Player2
   Country: United States
   ```

### Configure Devices
1. **Device 1 Setup**:
   ```bash
   # Sign out of existing Game Center account
   Settings → Game Center → Sign Out
   
   # Sign in with test account 1
   Settings → Game Center → Sign In
   # Use: botanybattle.test1@icloud.com
   ```

2. **Device 2 Setup**:
   ```bash
   # Sign out of existing Game Center account
   Settings → Game Center → Sign Out
   
   # Sign in with test account 2  
   Settings → Game Center → Sign In
   # Use: botanybattle.test2@icloud.com
   ```

## Step 2: Build and Deploy iOS App

### Build Configuration
```bash
# Navigate to iOS project
cd /Users/gunnarhellekson/Code/botany-battle/ios

# Clean previous builds
xcodebuild clean -project BotanyBattle.xcodeproj -scheme BotanyBattle

# Build for device (replace YOUR_DEVICE_NAME with actual device name)
xcodebuild build -project BotanyBattle.xcodeproj -scheme BotanyBattle -destination 'platform=iOS,name=YOUR_DEVICE_NAME'
```

### Deploy to Devices
1. **Connect Device 1**:
   - Connect via USB
   - Trust computer if prompted
   - Select device in Xcode
   - Build and run (⌘+R)

2. **Connect Device 2**:
   - Repeat process for second device
   - Ensure different Game Center account is signed in

## Step 3: Authentication Testing

### Test Sequence
1. **Launch App on Device 1**:
   ```
   Expected: Game Center authentication prompt appears
   Action: Accept authentication
   Verify: User profile loads with Player1 information
   ```

2. **Launch App on Device 2**:
   ```
   Expected: Game Center authentication prompt appears  
   Action: Accept authentication
   Verify: User profile loads with Player2 information
   ```

### Validation Points
- [ ] Game Center authentication succeeds on both devices
- [ ] User profiles show correct sandbox account information
- [ ] No authentication errors in debug console
- [ ] App doesn't crash during authentication

## Step 4: Matchmaking Testing

### Backend Verification
```bash
# Monitor backend logs during testing
cd /Users/gunnarhellekson/Code/botany-battle/backend
serverless logs -f gamecenterAuth -t --stage dev
```

### Matchmaking Flow
1. **Device 1 - Start Matchmaking**:
   ```
   Action: Tap "Find Game" button
   Expected: Matchmaking starts, shows "Looking for opponent..."
   Verify: Backend receives authentication token
   ```

2. **Device 2 - Join Matchmaking**:
   ```
   Action: Tap "Find Game" button  
   Expected: Both devices matched within 30 seconds
   Verify: Game session created, both players connected
   ```

### WebSocket Testing
```bash
# Test WebSocket connectivity separately if needed
websocat wss://zkkql6e4db.execute-api.us-west-2.amazonaws.com/dev
# Send test message: {"action":"ping","playerId":"test"}
```

## Step 5: Game Flow Testing

### Complete Game Session
1. **Game Initialization**:
   - [ ] Both devices show the same plant image
   - [ ] Question appears simultaneously  
   - [ ] Timer starts in sync

2. **Answer Submission**:
   - [ ] Player 1 selects answer
   - [ ] Player 2 selects different answer
   - [ ] Results show immediately
   - [ ] Scores update correctly

3. **Round Progression**:
   - [ ] Next round loads automatically
   - [ ] Round counter updates (1/5, 2/5, etc.)
   - [ ] Game state stays synchronized

4. **Game Completion**:
   - [ ] Final scores displayed
   - [ ] Winner determined correctly
   - [ ] Trophies awarded
   - [ ] Results saved to backend

## Step 6: Network Resilience Testing

### Disconnect Scenarios
1. **WiFi Disconnect Test**:
   ```
   Action: Turn off WiFi on Device 1 mid-game
   Expected: Connection lost notification
   Action: Reconnect WiFi
   Expected: Game resumes or graceful recovery
   ```

2. **Background/Foreground Test**:
   ```
   Action: Put app in background during game
   Expected: Game pauses or maintains connection
   Action: Return to foreground
   Expected: Game resumes correctly
   ```

## Step 7: Performance Testing

### Metrics to Monitor
- [ ] Authentication time (< 5 seconds)
- [ ] Matchmaking time (< 30 seconds)  
- [ ] Game start latency (< 2 seconds)
- [ ] Answer submission latency (< 1 second)
- [ ] Memory usage (< 100MB)
- [ ] Battery impact (< 5% per hour)

### Load Testing
```bash
# Run backend stress test
cd /Users/gunnarhellekson/Code/botany-battle
./scripts/simple-backend-test.sh

# Monitor concurrent connections
# (Would need multiple device pairs for full load testing)
```

## Troubleshooting Guide

### Common Issues

#### "Game Center Unavailable"
```
Solution:
1. Verify device is signed into correct sandbox account
2. Check Game Center is enabled in Settings
3. Ensure internet connectivity
4. Try signing out and back in
```

#### "Authentication Failed"
```
Solution:
1. Check backend logs for token validation errors
2. Verify sandbox account credentials
3. Ensure bundle ID matches App Store Connect
4. Check device date/time settings
```

#### "No Opponent Found"
```
Solution:  
1. Ensure both devices are on same network
2. Check backend matchmaking logs
3. Verify both accounts are different
4. Try restarting matchmaking
```

#### "Connection Lost"
```
Solution:
1. Check WiFi stability
2. Verify WebSocket endpoint accessibility
3. Monitor backend connection logs
4. Test WebSocket directly with websocat
```

## Testing Checklist

### Core Functionality
- [ ] Game Center authentication works on both devices
- [ ] Matchmaking connects two players successfully
- [ ] Real-time game synchronization works
- [ ] Scoring and results are accurate
- [ ] Currency/trophies are awarded correctly

### Edge Cases
- [ ] Network disconnection handling
- [ ] App backgrounding/foregrounding
- [ ] Multiple rapid matchmaking attempts
- [ ] Game abandonment scenarios
- [ ] Device rotation during game

### Performance
- [ ] No memory leaks during extended play
- [ ] Smooth animations and transitions
- [ ] Responsive touch interactions
- [ ] Stable frame rate during gameplay
- [ ] Reasonable battery consumption

## Success Criteria

### Must Pass
1. ✅ Both devices authenticate successfully
2. ✅ Matchmaking works within 30 seconds
3. ✅ Complete game flow works end-to-end
4. ✅ Real-time synchronization is reliable
5. ✅ No crashes during normal gameplay

### Should Pass
1. ✅ Network disconnection handled gracefully
2. ✅ Performance metrics within acceptable ranges
3. ✅ UI remains responsive under load
4. ✅ Error messages are user-friendly
5. ✅ Game state recovers after interruption

## Next Steps After Testing

1. **Document Results**: Record all test outcomes and issues
2. **Performance Optimization**: Address any performance bottlenecks
3. **Bug Fixes**: Resolve critical issues found during testing
4. **Production Readiness**: Prepare for App Store submission
5. **Monitoring Setup**: Implement production analytics

---

**Testing Team**: Development Team  
**Environment**: iOS 17.5, Game Center Sandbox  
**Backend**: AWS dev stage  
**Last Updated**: June 15, 2025
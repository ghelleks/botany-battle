# Game Center Device Testing Guide

This guide provides instructions for testing the Botany Battle Game Center authentication with real devices and sandbox accounts.

## Prerequisites

- ✅ Game Center migration implementation completed
- ✅ Game Center sandbox accounts created
- ✅ Apple Developer Program membership
- ✅ Physical iOS devices (Game Center requires real devices for full testing)
- ✅ Xcode with proper signing certificates

## Testing Environment Setup

### 1. Device Configuration

#### 1.1 Primary Test Device Setup
```bash
# Device 1 (iPhone/iPad for Player 1)
- Sign out of Game Center completely
- Go to Settings → Game Center → Sign Out
- Clear any cached data
- Sign in with: botanybattle.test1@icloud.com
```

#### 1.2 Secondary Test Device Setup  
```bash
# Device 2 (iPhone/iPad for Player 2)
- Sign out of Game Center completely
- Go to Settings → Game Center → Sign Out
- Clear any cached data  
- Sign in with: botanybattle.test2@icloud.com
```

#### 1.3 Optional Third Device
```bash
# Device 3 (for advanced testing)
- Sign in with: botanybattle.test3@icloud.com
```

### 2. Build and Deploy

#### 2.1 Build for Device Testing
```bash
# Navigate to iOS project
cd /Users/gunnarhellekson/Code/botany-battle/ios

# Build for device (replace with your device name)
xcodebuild -scheme BotanyBattle \
  -destination 'platform=iOS,name=YOUR_DEVICE_NAME' \
  -configuration Debug \
  build

# Or open in Xcode and build to device
open BotanyBattle.xcworkspace
```

#### 2.2 Deploy Backend Changes
```bash
# Deploy backend with Game Center auth
cd /Users/gunnarhellekson/Code/botany-battle/backend
npm run deploy:dev

# Verify deployment
curl -X POST https://your-api-endpoint/auth/gamecenter \
  -H "Content-Type: application/json" \
  -d '{"token":"test"}'
```

## Testing Scenarios

### Scenario 1: Single Player Authentication

#### Test Steps:
1. **Launch App** on Device 1
2. **Tap "Sign in with Game Center"**
3. **Verify Game Center Authentication Flow**
   - Game Center dialog should appear (if not already signed in)
   - Authentication should complete successfully
   - User should be redirected to main game screen

#### Expected Results:
- ✅ Game Center authentication dialog appears
- ✅ User successfully authenticates
- ✅ App displays user's Game Center display name
- ✅ User profile shows correct Game Center player ID
- ✅ Backend receives valid Game Center token

#### Verification Commands:
```bash
# Check backend logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/botany-battle-backend-dev-gamecenterAuth \
  --start-time $(date -d '5 minutes ago' +%s)000

# Check DynamoDB for user creation
aws dynamodb scan \
  --table-name botany-battle-backend-dev \
  --filter-expression "begins_with(id, :prefix)" \
  --expression-attribute-values '{":prefix":{"S":"G:"}}'
```

### Scenario 2: Two-Player Matchmaking

#### Test Steps:
1. **Device 1**: Launch app and authenticate
2. **Device 1**: Start matchmaking for "Medium" difficulty
3. **Device 2**: Launch app and authenticate  
4. **Device 2**: Start matchmaking for "Medium" difficulty
5. **Verify Match Connection**

#### Expected Results:
- ✅ Both devices find each other
- ✅ Game starts simultaneously on both devices
- ✅ Real-time synchronization works
- ✅ Plant images load correctly
- ✅ Answer submission works for both players

#### Testing Commands:
```bash
# Monitor WebSocket connections
aws logs filter-log-events \
  --log-group-name /aws/lambda/botany-battle-backend-dev-game \
  --filter-pattern "WebSocket" \
  --start-time $(date -d '5 minutes ago' +%s)000

# Check Redis for active games
redis-cli -h your-redis-endpoint.cache.amazonaws.com -p 6379
> KEYS game:*
> GET game:active-games
```

### Scenario 3: Friend Invitation Testing

#### Test Steps:
1. **Device 1**: Add Device 2's Game Center account as friend
2. **Device 1**: Send direct game invitation
3. **Device 2**: Accept invitation notification
4. **Verify Direct Match**

#### Expected Results:
- ✅ Invitation sent successfully
- ✅ Device 2 receives Game Center notification
- ✅ Direct match created bypassing matchmaking queue
- ✅ Game starts immediately for both players

### Scenario 4: Network Resilience Testing

#### Test Steps:
1. **Start game** between two devices
2. **Temporarily disable WiFi** on one device (use cellular)
3. **Re-enable WiFi** and verify reconnection
4. **Test answer submission** during poor connectivity

#### Expected Results:
- ✅ App gracefully handles network interruptions
- ✅ Reconnection works automatically
- ✅ Game state synchronizes correctly after reconnection
- ✅ No data loss during network switches

### Scenario 5: Multiple Account Testing

#### Test Steps:
1. **Device 1**: Sign out of Game Center
2. **Device 1**: Sign in with different sandbox account
3. **Verify new user creation**
4. **Test account switching** multiple times

#### Expected Results:
- ✅ New user profile created for each Game Center account
- ✅ No data conflicts between accounts
- ✅ ELO ratings isolated per account
- ✅ Currency and progress separated per account

## Performance Testing

### Latency Tests
```bash
# Test authentication latency
time curl -X POST https://your-api-endpoint/auth/gamecenter \
  -H "Content-Type: application/json" \
  -d '{"token":"VALID_GAME_CENTER_TOKEN"}'

# Should complete in <2 seconds
```

### Concurrent User Testing
```bash
# Test multiple simultaneous authentications
for i in {1..10}; do
  curl -X POST https://your-api-endpoint/auth/gamecenter \
    -H "Content-Type: application/json" \
    -d '{"token":"VALID_TOKEN_'$i'"}' &
done
wait

# All requests should succeed
```

## Troubleshooting

### Common Issues and Solutions

#### Issue: "Game Center Not Available"
**Solutions:**
- Verify device is signed into Game Center
- Check device has internet connection
- Ensure app bundle ID matches Game Center configuration
- Restart Game Center in device settings

#### Issue: "Authentication Failed"
**Solutions:**
- Verify sandbox account credentials
- Check App Store Connect Game Center configuration
- Ensure proper development team signing
- Clear app data and retry

#### Issue: "Players Can't Find Each Other"
**Solutions:**
- Verify both devices are using sandbox accounts
- Check that both accounts are in same region
- Ensure backend matchmaking service is running
- Check Redis connectivity

#### Issue: "WebSocket Connection Failed"
**Solutions:**
- Verify API Gateway WebSocket endpoint
- Check Lambda function permissions
- Test WebSocket endpoint manually
- Review CloudWatch logs for errors

### Debug Commands

#### Check Game Center Status
```bash
# On device, use Xcode console to check:
# GKLocalPlayer.local.isAuthenticated
# GKLocalPlayer.local.gamePlayerID
# GKLocalPlayer.local.displayName
```

#### Monitor Backend Logs
```bash
# Real-time log monitoring
aws logs tail /aws/lambda/botany-battle-backend-dev-gamecenterAuth --follow

# Filter for errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/botany-battle-backend-dev-gamecenterAuth \
  --filter-pattern "ERROR"
```

#### Check Database State
```bash
# List all Game Center users
aws dynamodb scan \
  --table-name botany-battle-backend-dev \
  --projection-expression "id, username, displayName, stats" \
  --filter-expression "begins_with(id, :prefix)" \
  --expression-attribute-values '{":prefix":{"S":"G:"}}'
```

## Test Results Documentation

### Test Report Template
```markdown
## Game Center Testing Report

**Date:** [Date]
**Tester:** [Name]
**Devices:** [List devices used]
**Backend Version:** [Git commit hash]

### Authentication Tests
- [ ] Single player authentication: PASS/FAIL
- [ ] Multiple account switching: PASS/FAIL  
- [ ] Token validation: PASS/FAIL

### Matchmaking Tests
- [ ] Two-player matchmaking: PASS/FAIL
- [ ] Friend invitations: PASS/FAIL
- [ ] Cross-skill matching: PASS/FAIL

### Network Tests
- [ ] WiFi to cellular handoff: PASS/FAIL
- [ ] Poor connectivity handling: PASS/FAIL
- [ ] Reconnection logic: PASS/FAIL

### Performance Tests
- [ ] Authentication latency < 2s: PASS/FAIL
- [ ] Matchmaking time < 30s: PASS/FAIL
- [ ] Game response time < 200ms: PASS/FAIL

### Issues Found
[Document any issues with steps to reproduce]

### Recommendations
[Suggestions for improvements]
```

## Success Criteria

### Must Pass Tests
- ✅ Authentication works on all test devices
- ✅ Two-player matchmaking completes successfully
- ✅ Real-time gameplay synchronization works
- ✅ Network interruption recovery functions
- ✅ Multiple account switching works correctly

### Performance Criteria
- ✅ Authentication completes in <2 seconds
- ✅ Matchmaking finds opponent in <30 seconds
- ✅ Game responses under 200ms latency
- ✅ App memory usage <100MB during gameplay
- ✅ Battery drain <5% per hour of gameplay

## Next Steps After Testing

### If Tests Pass:
1. Document test results
2. Create production deployment plan
3. Schedule App Store Connect configuration
4. Plan rollout strategy

### If Tests Fail:
1. Document failures with reproduction steps
2. Fix identified issues
3. Re-run failed test scenarios
4. Update Game Center sandbox configuration if needed

---

**Note:** Game Center testing requires physical devices and sandbox accounts. Simulator testing is limited and may not reflect real-world behavior.
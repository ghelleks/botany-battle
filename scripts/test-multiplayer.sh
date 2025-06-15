#!/bin/bash

# Multi-player Testing Script for Botany Battle
# This script helps coordinate testing across multiple devices/simulators

set -e

echo "🌿 Botany Battle Multi-player Testing Script"
echo "==========================================="

# Configuration
BACKEND_ENDPOINT="https://fsmiubpnza.execute-api.us-west-2.amazonaws.com/dev"
WS_ENDPOINT="wss://zkkql6e4db.execute-api.us-west-2.amazonaws.com/dev"
PROJECT_DIR="/Users/gunnarhellekson/Code/botany-battle"
IOS_PROJECT="$PROJECT_DIR/ios/BotanyBattle.xcodeproj"

# Test accounts for reference
echo "📱 Game Center Sandbox Test Accounts:"
echo "1. botanybattle.test1@icloud.com (Beginner)"
echo "2. botanybattle.test2@icloud.com (Intermediate)" 
echo "3. botanybattle.test3@icloud.com (Advanced)"
echo ""

# Function to check backend health
check_backend_health() {
    echo "🔍 Checking backend health..."
    
    # Test Game Center auth endpoint
    if curl -s -X POST "$BACKEND_ENDPOINT/auth/gamecenter" -H "Content-Type: application/json" -d '{}' | grep -q "error"; then
        echo "✅ Game Center auth endpoint is responding"
    else
        echo "❌ Game Center auth endpoint may have issues"
    fi
    
    # Test plant endpoint
    if curl -s "$BACKEND_ENDPOINT/plant" | grep -q "plants\|error"; then
        echo "✅ Plant endpoint is responding"
    else
        echo "❌ Plant endpoint may have issues"
    fi
    
    echo ""
}

# Function to prepare iOS builds
prepare_ios_builds() {
    echo "📱 Preparing iOS builds for testing..."
    
    cd "$PROJECT_DIR/ios"
    
    # Clean previous builds
    echo "Cleaning previous builds..."
    xcodebuild clean -project BotanyBattle.xcodeproj -scheme BotanyBattle
    
    # Build for simulator testing
    echo "Building for iOS Simulator..."
    xcodebuild build -project BotanyBattle.xcodeproj -scheme BotanyBattle -destination 'platform=iOS Simulator,name=iPhone 15'
    
    # Build for device testing (uncomment if you have a device connected)
    # echo "Building for iOS Device..."
    # xcodebuild build -project BotanyBattle.xcodeproj -scheme BotanyBattle -destination 'platform=iOS,name=YOUR_DEVICE_NAME'
    
    echo "✅ iOS builds prepared"
    echo ""
}

# Function to run Game Center tests
run_gamecenter_tests() {
    echo "🎮 Running Game Center tests..."
    
    cd "$PROJECT_DIR/ios"
    
    # Run Game Center unit tests
    echo "Running Game Center unit tests..."
    xcodebuild test -project BotanyBattle.xcodeproj -scheme BotanyBattle -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:BotanyBattleTests/GameCenterServiceTests
    
    # Run Game Center integration tests
    echo "Running Game Center integration tests..."
    xcodebuild test -project BotanyBattle.xcodeproj -scheme BotanyBattle -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:BotanyBattleTests/GameCenterIntegrationTests
    
    echo "✅ Game Center tests completed"
    echo ""
}

# Function to test WebSocket connectivity
test_websocket() {
    echo "🔌 Testing WebSocket connectivity..."
    
    # Use websocat if available, otherwise skip
    if command -v websocat &> /dev/null; then
        echo "Testing WebSocket connection to $WS_ENDPOINT"
        timeout 5 websocat "$WS_ENDPOINT" <<< '{"action":"ping"}' || echo "WebSocket test completed (timeout expected)"
    else
        echo "⚠️  websocat not found. Install with: brew install websocat"
        echo "Skipping WebSocket direct test"
    fi
    
    echo ""
}

# Function to setup multiple simulators
setup_multiple_simulators() {
    echo "📱 Setting up multiple simulators for testing..."
    
    # List available simulators
    echo "Available iOS Simulators:"
    xcrun simctl list devices | grep iPhone
    
    # Create additional simulators if needed
    echo "Creating test simulators..."
    xcrun simctl create "BotanyBattle-Player1" com.apple.CoreSimulator.SimDeviceType.iPhone-15 com.apple.CoreSimulator.SimRuntime.iOS-17-5 || echo "Simulator already exists"
    xcrun simctl create "BotanyBattle-Player2" com.apple.CoreSimulator.SimDeviceType.iPhone-15 com.apple.CoreSimulator.SimRuntime.iOS-17-5 || echo "Simulator already exists"
    
    # Boot simulators
    echo "Booting test simulators..."
    xcrun simctl boot "BotanyBattle-Player1" || echo "Already booted"
    xcrun simctl boot "BotanyBattle-Player2" || echo "Already booted"
    
    echo "✅ Multiple simulators ready"
    echo ""
}

# Function to display testing instructions
show_testing_instructions() {
    echo "📋 Multi-player Testing Instructions:"
    echo "===================================="
    echo ""
    echo "1. 🔐 Authentication Testing:"
    echo "   - Open app on multiple devices/simulators"
    echo "   - Sign in with different Game Center sandbox accounts"
    echo "   - Verify profile information loads correctly"
    echo ""
    echo "2. 🎯 Matchmaking Testing:"
    echo "   - Start matchmaking on one device"
    echo "   - Start matchmaking on second device" 
    echo "   - Verify players are matched within 30 seconds"
    echo "   - Test with accounts of different skill levels"
    echo ""
    echo "3. 🎮 Game Flow Testing:"
    echo "   - Start a game between two players"
    echo "   - Verify plant images load simultaneously"
    echo "   - Test answer selection and timing"
    echo "   - Verify score updates in real-time"
    echo "   - Complete full 5-round game"
    echo ""
    echo "4. 🔌 Connection Testing:"
    echo "   - Start a game and simulate network disconnect"
    echo "   - Verify reconnection behavior"
    echo "   - Test background/foreground transitions"
    echo ""
    echo "5. 💰 Economy Testing:"
    echo "   - Verify Trophy rewards after game completion"
    echo "   - Test shop purchases with Game Center users"
    echo "   - Verify inventory synchronization"
    echo ""
    echo "⚠️  Important Notes:"
    echo "   - Game Center requires real devices for full testing"
    echo "   - Ensure different sandbox accounts on each device"
    echo "   - Monitor backend logs during testing"
    echo "   - Document any issues found"
    echo ""
}

# Function to monitor backend logs
monitor_backend_logs() {
    echo "📊 Monitoring backend logs (press Ctrl+C to stop)..."
    echo "Watching for Game Center authentication and game events..."
    echo ""
    
    # Use serverless logs if available
    if command -v serverless &> /dev/null; then
        serverless logs -f gamecenterAuth -t --stage dev &
        serverless logs -f game -t --stage dev &
        wait
    else
        echo "⚠️  Serverless CLI not found. Check AWS CloudWatch logs manually."
    fi
}

# Main execution
main() {
    case "${1:-help}" in
        "health")
            check_backend_health
            ;;
        "build")
            prepare_ios_builds
            ;;
        "test")
            run_gamecenter_tests
            ;;
        "websocket")
            test_websocket
            ;;
        "simulators")
            setup_multiple_simulators
            ;;
        "instructions")
            show_testing_instructions
            ;;
        "logs")
            monitor_backend_logs
            ;;
        "full")
            check_backend_health
            prepare_ios_builds
            run_gamecenter_tests
            test_websocket
            setup_multiple_simulators
            show_testing_instructions
            ;;
        *)
            echo "Usage: $0 {health|build|test|websocket|simulators|instructions|logs|full}"
            echo ""
            echo "Commands:"
            echo "  health       - Check backend health"
            echo "  build        - Prepare iOS builds"
            echo "  test         - Run Game Center tests"
            echo "  websocket    - Test WebSocket connectivity"
            echo "  simulators   - Setup multiple simulators"
            echo "  instructions - Show testing instructions"
            echo "  logs         - Monitor backend logs"
            echo "  full         - Run complete testing setup"
            ;;
    esac
}

main "$@"
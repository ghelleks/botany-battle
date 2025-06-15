#!/bin/bash

# Device Testing Script for Botany Battle Multi-player
echo "🌿 Botany Battle - Device Testing Script"
echo "========================================"

PROJECT_DIR="/Users/gunnarhellekson/Code/botany-battle"
IOS_PROJECT="$PROJECT_DIR/ios/BotanyBattle.xcodeproj"
BACKEND_URL="https://fsmiubpnza.execute-api.us-west-2.amazonaws.com/dev"

# Function to list available devices
list_devices() {
    echo "📱 Available Devices:"
    xcrun xctrace list devices | grep -E "== Devices ==" -A 50 | grep -v "== Simulators ==" | grep -v "== Devices ==" | head -20
    echo ""
}

# Function to build for device
build_for_device() {
    local device_name="$1"
    echo "🔨 Building for device: $device_name"
    
    cd "$PROJECT_DIR/ios"
    
    # Clean previous builds
    echo "Cleaning previous builds..."
    xcodebuild clean -project BotanyBattle.xcodeproj -scheme BotanyBattle
    
    # Build for specific device
    echo "Building for $device_name..."
    xcodebuild build -project BotanyBattle.xcodeproj -scheme BotanyBattle -destination "platform=iOS,name=$device_name" -configuration Debug
    
    if [ $? -eq 0 ]; then
        echo "✅ Build successful for $device_name"
        return 0
    else
        echo "❌ Build failed for $device_name"
        return 1
    fi
}

# Function to install on device
install_on_device() {
    local device_name="$1"
    echo "📲 Installing on device: $device_name"
    
    cd "$PROJECT_DIR/ios"
    
    # Build and install
    xcodebuild install -project BotanyBattle.xcodeproj -scheme BotanyBattle -destination "platform=iOS,name=$device_name" -configuration Debug
    
    if [ $? -eq 0 ]; then
        echo "✅ Installation successful on $device_name"
        return 0
    else
        echo "❌ Installation failed on $device_name"
        return 1
    fi
}

# Function to test Game Center connectivity
test_gamecenter_auth() {
    echo "🎮 Testing Game Center Authentication..."
    echo ""
    echo "📋 Game Center Sandbox Account Setup:"
    echo "Account 1: botanybattle.test1@icloud.com / TestPass123!"
    echo "Account 2: botanybattle.test2@icloud.com / TestPass123!"
    echo ""
    echo "🔧 Device Setup Instructions:"
    echo "1. Settings → Game Center → Sign Out (if already signed in)"
    echo "2. Settings → Game Center → Sign In"
    echo "3. Use sandbox account credentials above"
    echo ""
    echo "⚠️  Important: Use DIFFERENT accounts on each device!"
}

# Function to monitor backend during testing
monitor_backend() {
    echo "📊 Monitoring backend for multi-player activity..."
    echo "Backend URL: $BACKEND_URL"
    echo ""
    echo "Monitoring Game Center authentication and game events..."
    echo "Press Ctrl+C to stop monitoring"
    echo ""
    
    # Monitor backend logs if serverless is available
    if command -v serverless &> /dev/null; then
        cd "$PROJECT_DIR/backend"
        echo "Starting log monitoring..."
        serverless logs -f gamecenterAuth -t --stage dev &
        AUTH_PID=$!
        serverless logs -f game -t --stage dev &
        GAME_PID=$!
        
        # Wait for user to stop
        trap "echo 'Stopping monitoring...'; kill $AUTH_PID $GAME_PID 2>/dev/null; exit 0" INT
        wait
    else
        echo "⚠️  Serverless CLI not available. Check AWS CloudWatch logs manually."
        echo "Game Center Auth: /aws/lambda/botany-battle-backend-dev-gamecenterAuth"
        echo "Game Logic: /aws/lambda/botany-battle-backend-dev-game"
    fi
}

# Function to run device testing checklist
testing_checklist() {
    echo "✅ Device Testing Checklist"
    echo "=========================="
    echo ""
    echo "Phase 1: Setup"
    echo "□ Physical devices connected and trusted"
    echo "□ Different Game Center sandbox accounts on each device"
    echo "□ App built and installed on both devices"
    echo "□ Backend monitoring active"
    echo ""
    echo "Phase 2: Authentication"
    echo "□ Device 1: Game Center auth succeeds"
    echo "□ Device 2: Game Center auth succeeds"
    echo "□ User profiles load correctly"
    echo "□ No authentication errors in logs"
    echo ""
    echo "Phase 3: Matchmaking"
    echo "□ Device 1: Start matchmaking"
    echo "□ Device 2: Start matchmaking"
    echo "□ Players matched within 30 seconds"
    echo "□ Game session created successfully"
    echo ""
    echo "Phase 4: Gameplay"
    echo "□ Both devices show same plant image"
    echo "□ Answers submit correctly"
    echo "□ Scores update in real-time"
    echo "□ Game completes successfully"
    echo ""
    echo "Phase 5: Network Resilience"
    echo "□ WiFi disconnect/reconnect handling"
    echo "□ App background/foreground transitions"
    echo "□ Connection loss recovery"
    echo ""
}

# Function to test basic connectivity
test_connectivity() {
    echo "🔌 Testing Backend Connectivity..."
    
    # Test plant endpoint
    echo "Testing plant endpoint..."
    curl -s "$BACKEND_URL/plant" | head -100
    echo ""
    
    # Test WebSocket endpoint
    echo "Testing WebSocket endpoint..."
    if command -v websocat &> /dev/null; then
        echo "WebSocket test (will timeout after 3 seconds):"
        timeout 3 websocat "$BACKEND_URL" <<< '{"action":"ping","playerId":"test"}' || echo "WebSocket connection available"
    else
        echo "⚠️  websocat not found. WebSocket endpoint: wss://zkkql6e4db.execute-api.us-west-2.amazonaws.com/dev"
    fi
    echo ""
}

# Main function
main() {
    case "${1:-help}" in
        "devices")
            list_devices
            ;;
        "build")
            if [ -z "$2" ]; then
                echo "Usage: $0 build <device_name>"
                echo "Available devices:"
                list_devices
                exit 1
            fi
            build_for_device "$2"
            ;;
        "install")
            if [ -z "$2" ]; then
                echo "Usage: $0 install <device_name>"
                echo "Available devices:"
                list_devices
                exit 1
            fi
            install_on_device "$2"
            ;;
        "setup")
            test_gamecenter_auth
            ;;
        "monitor")
            monitor_backend
            ;;
        "checklist")
            testing_checklist
            ;;
        "connectivity")
            test_connectivity
            ;;
        "full-test")
            echo "🚀 Starting Full Device Testing Process"
            echo "======================================"
            test_connectivity
            test_gamecenter_auth
            testing_checklist
            ;;
        *)
            echo "Usage: $0 {devices|build|install|setup|monitor|checklist|connectivity|full-test}"
            echo ""
            echo "Commands:"
            echo "  devices      - List available iOS devices"
            echo "  build        - Build app for specific device"
            echo "  install      - Install app on specific device"
            echo "  setup        - Show Game Center setup instructions"
            echo "  monitor      - Monitor backend logs during testing"
            echo "  checklist    - Show testing checklist"
            echo "  connectivity - Test backend connectivity"
            echo "  full-test    - Run complete testing setup"
            echo ""
            echo "Example:"
            echo "  $0 devices                    # List devices"
            echo "  $0 build \"Too-Ticky\"          # Build for device"
            echo "  $0 install \"Too-Ticky\"       # Install on device"
            echo "  $0 monitor                    # Monitor backend"
            ;;
    esac
}

main "$@"
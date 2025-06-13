# Botany Battle iOS App

## Overview
The iOS application for Botany Battle, a plant identification game where players compete against each other to identify plants correctly and quickly.

## Architecture
This app is built using:
- **SwiftUI** for the user interface
- **The Composable Architecture (TCA)** for state management
- **Swift Package Manager** for dependency management
- **Amplify** for authentication
- **Starscream** for WebSocket communication
- **Alamofire** for HTTP networking

## Project Structure
```
ios/
├── BotanyBattle.xcodeproj/          # Xcode project files
├── BotanyBattle/                    # Main app bundle
│   ├── BotanyBattleApp.swift       # App entry point
│   ├── ContentView.swift           # Root view
│   ├── Assets.xcassets/            # App assets
│   └── Preview Content/            # Preview assets
├── Sources/                         # Source code
│   ├── App/                        # App-level components
│   │   ├── Configuration/          # App configuration
│   │   ├── DesignSystem/           # Design system components
│   │   └── Navigation/             # Navigation views
│   ├── Core/                       # Core business logic
│   │   ├── Models/                 # Data models
│   │   └── Services/               # Service layer
│   └── Features/                   # Feature modules
│       ├── Auth/                   # Authentication
│       ├── Game/                   # Game functionality
│       ├── Profile/                # User profile
│       └── Shop/                   # In-app shop
├── Tests/                          # Unit tests
├── Package.swift                   # Swift Package Manager
└── README.md                       # This file
```

## Features
- **Authentication**: User registration and login via AWS Cognito
- **Game Play**: Real-time multiplayer plant identification games
- **Profile Management**: User statistics, achievements, and leaderboards
- **Shop System**: In-app purchases for power-ups and cosmetics
- **Design System**: Consistent UI components and theming

## Dependencies
- [Alamofire](https://github.com/Alamofire/Alamofire) - HTTP networking
- [Starscream](https://github.com/daltoniam/Starscream) - WebSocket client
- [Amplify](https://github.com/aws-amplify/amplify-swift) - AWS integration
- [Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) - State management
- [Dependencies](https://github.com/pointfreeco/swift-dependencies) - Dependency injection
- [SDWebImageSwiftUI](https://github.com/SDWebImage/SDWebImageSwiftUI) - Image loading

## Getting Started

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0 or later
- Swift 5.9 or later

### Building the Project
1. Open `BotanyBattle.xcodeproj` in Xcode
2. Wait for Swift Package Manager to resolve dependencies
3. Select your target device or simulator
4. Build and run the project (⌘+R)

### Configuration
The app uses different configurations for development and production:

**Development Configuration:**
- API Base URL: `https://fsmiubpnza.execute-api.us-west-2.amazonaws.com/dev`
- WebSocket URL: `wss://zkkql6e4db.execute-api.us-west-2.amazonaws.com/dev`
- Debug logging enabled
- AWS Cognito User Pool: `us-west-2_iMuY9Xgu6`
- Client ID: `6h2274uf0e73fl2t438orc0oc2`

**Production Configuration:**
- API Base URL: `https://fsmiubpnza.execute-api.us-west-2.amazonaws.com/prod`
- WebSocket URL: `wss://zkkql6e4db.execute-api.us-west-2.amazonaws.com/prod`
- Debug logging disabled
- Production AWS services

**Amplify Setup:**
Amplify is automatically configured on app launch via `AppConfiguration.configure()` in `BotanyBattleApp.swift`.

## Testing
Run tests using Xcode's test navigator or:
```bash
xcodebuild test -scheme BotanyBattle -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Design System
The app includes a comprehensive design system with:
- **Colors**: Botanical-themed color palette
- **Typography**: Custom font styles and text components
- **Components**: Reusable UI components (buttons, cards, text fields)
- **Themes**: Support for light and dark modes

## State Management
The app uses The Composable Architecture for predictable state management:
- Each feature has its own reducer and state
- Actions flow unidirectionally through the system
- Side effects are handled through dependencies
- Easy testing and debugging

## Networking
The app communicates with the backend through:
- **REST API**: For standard operations (authentication, data fetching)
- **WebSocket**: For real-time game updates and communication

## Contributing
When contributing to the iOS app:
1. Follow the existing architecture patterns
2. Use the design system components
3. Write tests for new features
4. Ensure code follows Swift style guidelines
5. Update documentation as needed

## Deployment
The app will be deployed to the App Store following standard iOS deployment practices:
1. Archive the app for distribution
2. Upload to App Store Connect
3. Submit for review
4. Release to users

## Troubleshooting
Common issues and solutions:
- **Dependencies not resolving**: Clean build folder and reset package caches
- **Build errors**: Ensure Xcode and iOS versions meet requirements
- **Runtime crashes**: Check console logs and crash reports
- **Networking issues**: Verify backend service availability
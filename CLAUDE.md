# General Guidance

   * @project-requirements.md is the canonical set of requirements for this project. All work product and documentation must comply with these instructions. When they are in conflict, make that clear.
   * @TODO.md is the project plan. There, we mark what is complete (marked with a ✅), what is in process (marked with a ⌛️), and what is yet to be done. Update this after each interaction.
   * You will always update @TODO.md when a step in the @TODO.md plan is complete.
   * @README.md provides a developer-focused orientation. It is there to help users get started with the project. It does not contain project status, which belongs in @TODO.md.

# Architecture & Code Quality Standards

## iOS Development Guidelines

### File Organization & Architecture
- **CRITICAL**: Break down `SimpleContentView.swift` (1,800+ lines) into feature-based modules
- **Module Structure**: Follow the documented architecture in `docs/architecture/ios-design.md`
  ```
  Sources/
  ├── App/          // App entry point & coordination
  ├── Features/     // Game, Profile, Shop, Auth features
  ├── Core/         // Shared services, networking, persistence
  └── Resources/    // Assets, strings, constants
  ```
- **View Hierarchy**: Maximum 200 lines per SwiftUI view. Extract subviews for complex UI.
- **Single Responsibility**: Each view should handle exactly one UI concern

### State Management Standards
- **Centralized State**: Replace scattered `@State` variables with feature-specific `ObservableObject` stores
- **Game State**: Implement persistent game state that survives app termination
- **Threading**: Use `@MainActor` for UI updates, `async/await` for network calls
- **Example Pattern**:
  ```swift
  @MainActor
  class GameState: ObservableObject {
      @Published var currentQuestion: Int = 1
      @Published var score: Int = 0
      @Published var isLoading: Bool = false
  }
  ```

### Performance Requirements
- **Timer Management**: Use single `Timer.publish()` with `onReceive` instead of `Timer.scheduledTimer`
- **Image Loading**: Implement proper AsyncImage caching with size limits
- **API Caching**: Cache iNaturalist responses locally for offline gameplay
- **Memory Management**: Ensure proper cleanup in `onDisappear` and view destruction

### Code Quality Standards
- **Constants**: Replace magic numbers with named constants
  ```swift
  enum GameConstants {
      static let practiceTimeLimit = 60
      static let timeAttackLimit = 15
      static let maxRounds = 5
  }
  ```
- **Error Handling**: Never use force unwrapping (`!`) - always provide fallbacks
- **Documentation**: Add inline documentation for complex game logic and API interactions
- **Naming**: Remove `Simple*` prefixes once proper architecture is implemented

## Backend Development Guidelines

### AWS Lambda Best Practices
- **Function Size**: Keep Lambda functions under 500 lines
- **Cold Start Optimization**: Initialize AWS clients outside handler functions
- **Error Handling**: Always return proper HTTP status codes with structured error responses
- **Database Connections**: Implement proper connection pooling for DynamoDB and Redis

### API Design Standards
- **RESTful Design**: Follow REST conventions for HTTP endpoints
- **WebSocket Management**: Implement proper connection lifecycle management
- **Rate Limiting**: Add rate limiting to prevent API abuse
- **Response Format**: Standardize API response format across all endpoints

### Testing Requirements
- **Coverage**: Maintain minimum 80% test coverage for core game logic
- **Integration Tests**: Test full user flows, not just unit functions
- **Load Testing**: Use existing load test infrastructure for multiplayer features
- **Mock Data**: Create comprehensive mock data for offline development
- **Always use test-driven development best practices**

## Data & API Management

### iNaturalist API Integration
- **Rate Limiting**: Respect API limits and implement exponential backoff
- **Data Validation**: Validate all plant data before storing
- **Image Optimization**: Resize and cache plant images locally
- **Fallback Strategy**: Maintain local plant database for offline functionality

### Plant Data Quality
- **Fact Generation**: Replace hardcoded plant facts with API-sourced data
- **Image Quality**: Implement image quality checks before displaying
- **Difficulty Rating**: Add systematic difficulty rating based on observation counts
- **Localization**: Support multiple languages for plant names and facts

## Security & Privacy Standards

### Authentication Flow
- **Guest Mode First**: Ensure all single-player features work without authentication
- **Game Center Integration**: Implement proper Game Center authentication flow
- **Token Management**: Secure storage of authentication tokens
- **Privacy**: Minimize data collection in guest mode

### Data Protection
- **Local Storage**: Use Keychain for sensitive data storage
- **Network Security**: Implement certificate pinning for API calls
- **User Privacy**: Follow iOS privacy guidelines for location and photo access
- **GDPR Compliance**: Implement data export and deletion capabilities

## Common Pitfalls to Avoid

### SwiftUI Anti-Patterns
- ❌ Massive view files (current: 1,800 lines)
- ❌ Direct Timer usage in views without cleanup
- ❌ Synchronous API calls on main thread
- ❌ Force unwrapping of optional values
- ❌ Hardcoded strings and magic numbers

### Game Logic Issues
- ❌ Timer memory leaks in game modes
- ❌ Race conditions in multiplayer state
- ❌ Inconsistent scoring algorithms
- ❌ Missing offline functionality

### Backend Concerns
- ❌ Unhandled WebSocket disconnections
- ❌ Missing input validation
- ❌ Inadequate error logging
- ❌ Poor connection pooling

## Quick Reference Checklist

Before committing code, verify:
- [ ] No file exceeds 200 lines for views, 500 for services
- [ ] All `@State` variables have clear ownership
- [ ] Timer cleanup implemented in `onDisappear`
- [ ] Error handling covers network failures
- [ ] Magic numbers replaced with named constants
- [ ] Tests cover new functionality
- [ ] Documentation updated for complex logic
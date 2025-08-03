# iOS Refactoring Sprint Plan

## **Executive Summary**

This sprint plan addresses the critical refactoring of the 1,803-line `SimpleContentView.swift` file to meet iOS development guidelines outlined in CLAUDE.md. The refactor will implement proper MVVM architecture, state management, and modular design patterns.

## **Current State Analysis**

### **Critical Issues Identified**
- **1,803-line monolithic file** violating maintainability standards (target: <200 lines per view)
- **17 distinct structs/classes** in a single file requiring separation
- **Embedded API service** needs extraction to Core layer
- **Mixed concerns**: UI, business logic, and data access intertwined
- **State management**: Scattered `@State` variables without centralization
- **Memory leaks**: Timer usage without proper cleanup
- **No offline support** despite requirements

### **Architecture Violations**
- MVVM pattern not implemented despite documentation
- No separation between Features, Core, and App layers
- API services mixed with UI components
- Game logic embedded in view controllers

---

## **Sprint 1: Foundation & Architecture Setup (Week 1)**

### **Sprint 1.1: Project Structure Creation**
**Duration**: 2 days  
**Priority**: Critical

#### Tasks:
1. **Create proper directory structure**
   ```
   Sources/
   ├── App/
   │   ├── BotanyBattleApp.swift
   │   └── AppCoordinator.swift
   ├── Features/
   │   ├── Auth/
   │   ├── Game/
   │   ├── Profile/
   │   ├── Shop/
   │   └── Settings/
   ├── Core/
   │   ├── Models/
   │   ├── Services/
   │   ├── Networking/
   │   └── Persistence/
   └── Resources/
       ├── Constants/
       └── Extensions/
   ```

2. **Extract data models to Core/Models/**
   - `PlantData.swift`
   - `PlantQuestion.swift`
   - `TutorialStep.swift`
   - `ShopItem.swift`
   - `iNaturalistModels.swift`

3. **Create GameConstants.swift**
   ```swift
   enum GameConstants {
       static let practiceTimeLimit = 60
       static let timeAttackLimit = 15
       static let speedrunQuestionCount = 25
       static let maxRounds = 5
   }
   ```

### **Sprint 1.2: Service Layer Extraction**
**Duration**: 3 days  
**Priority**: Critical

#### Tasks:
1. **Extract SimplePlantAPIService → Core/Services/PlantAPIService.swift**
   - Implement proper async/await patterns
   - Add error handling and retry logic
   - Add caching mechanism for offline support
   - Add rate limiting compliance

2. **Create GameCenterService.swift**
   - Extract Game Center authentication logic
   - Implement proper lifecycle management

3. **Create UserDefaultsService.swift**
   - Centralize all UserDefaults operations
   - Type-safe property wrappers

4. **Create TimerService.swift**
   - Replace direct Timer usage with managed service
   - Implement proper cleanup and memory management

---

## **Sprint 2: Feature Decomposition (Week 2)**

### **Sprint 2.1: Authentication Feature**
**Duration**: 2 days  
**Priority**: High

#### Tasks:
1. **Create Features/Auth/ module**
   - `AuthFeature.swift` (ObservableObject)
   - `AuthView.swift` (UI only, <200 lines)
   - `AuthCoordinator.swift` (navigation logic)

2. **Extract SimpleAuthView logic**
   - Move authentication state to AuthFeature
   - Implement proper error handling
   - Add guest mode support

### **Sprint 2.2: Game Feature Module**
**Duration**: 3 days  
**Priority**: Critical

#### Tasks:
1. **Create Features/Game/ structure**
   ```
   Features/Game/
   ├── GameFeature.swift          // Main game state
   ├── GameModeSelectionView.swift
   ├── GamePlayView.swift
   ├── GameResultsView.swift
   └── Components/
       ├── AnswerButtonsView.swift
       ├── TimerDisplayView.swift
       ├── ScoreDisplayView.swift
       └── PlantImageView.swift
   ```

2. **Extract game modes from SimpleGameView**
   - Beat the Clock logic → `BeatTheClockFeature.swift`
   - Practice mode logic → `PracticeFeature.swift`
   - Speedrun logic → `SpeedrunFeature.swift`

3. **Create GameState ObservableObject**
   ```swift
   @MainActor
   class GameState: ObservableObject {
       @Published var currentMode: GameMode = .practice
       @Published var currentQuestion: Int = 1
       @Published var score: Int = 0
       @Published var timeRemaining: Int = 60
       @Published var isGameActive: Bool = false
       @Published var plants: [PlantData] = []
   }
   ```

---

## **Sprint 3: UI Component Breakdown (Week 3)**

### **Sprint 3.1: Profile & Shop Features**
**Duration**: 2 days  
**Priority**: Medium

#### Tasks:
1. **Features/Profile/ module**
   - `ProfileFeature.swift` (state management)
   - `ProfileView.swift` (main UI)
   - `AchievementRow.swift` (component)
   - `StatsDisplayView.swift` (component)

2. **Features/Shop/ module**
   - `ShopFeature.swift` (state management)
   - `ShopView.swift` (main UI)
   - `ShopItemCard.swift` (component)

### **Sprint 3.2: Settings & Tutorial**
**Duration**: 2 days  
**Priority**: Low

#### Tasks:
1. **Features/Settings/ module**
   - `SettingsFeature.swift`
   - `SettingsView.swift`

2. **Features/Tutorial/ module**
   - `TutorialFeature.swift`
   - `TutorialView.swift`

3. **Extract SimpleMainTabView**
   - Move to `App/MainTabView.swift`
   - Implement proper navigation coordination

### **Sprint 3.3: Game Screen Decomposition**
**Duration**: 1 day  
**Priority**: High

#### Tasks:
1. **Break down massive GameScreenView (400+ lines)**
   - `GamePlayView.swift` (main game UI)
   - `Components/TimerView.swift`
   - `Components/QuestionCounterView.swift`
   - `Components/AnswerOptionsView.swift`
   - `Components/PlantDisplayView.swift`

---

## **Sprint 4: State Management & Performance (Week 4)**

### **Sprint 4.1: Centralized State Management**
**Duration**: 3 days  
**Priority**: Critical

#### Tasks:
1. **Replace scattered @State with ObservableObjects**
   - Remove all `@State var isSignedIn`, `@State var plants`, etc.
   - Implement proper state ownership hierarchy
   - Add state persistence for game progress

2. **Implement AppState coordinator**
   ```swift
   @MainActor
   class AppState: ObservableObject {
       @Published var authState = AuthState()
       @Published var gameState = GameState()
       @Published var profileState = ProfileState()
       @Published var shopState = ShopState()
   }
   ```

3. **Add Core Data integration**
   - Persistent storage for game progress
   - Offline data caching
   - Personal best tracking

### **Sprint 4.2: Performance Optimization**
**Duration**: 2 days  
**Priority**: High

#### Tasks:
1. **Fix timer memory leaks**
   - Replace `Timer.scheduledTimer` with `Timer.publish()`
   - Add proper cleanup in `onDisappear`
   - Implement timer pause/resume functionality

2. **Optimize image loading**
   - Implement AsyncImage with caching
   - Add image size optimization
   - Preload images for smooth gameplay

3. **Add offline support**
   - Cache iNaturalist responses locally
   - Implement fallback plant database
   - Handle network failure gracefully

---

## **Sprint 5: Testing & Quality Assurance (Week 5)**

### **Sprint 5.1: Unit Testing**
**Duration**: 2 days  
**Priority**: High

#### Tasks:
1. **Test core business logic**
   - GameState test coverage
   - PlantAPIService test coverage
   - Scoring algorithm tests
   - Timer management tests

2. **Mock data setup**
   - Create comprehensive plant data mocks
   - API response mocking
   - Game state mocks

### **Sprint 5.2: Integration Testing**
**Duration**: 2 days  
**Priority**: Medium

#### Tasks:
1. **Feature integration tests**
   - Authentication flow tests
   - Game mode transition tests
   - State persistence tests

2. **UI testing**
   - Navigation flow tests
   - Game interaction tests
   - Accessibility tests

### **Sprint 5.3: Performance Testing**
**Duration**: 1 day  
**Priority**: Medium

#### Tasks:
1. **Memory leak detection**
   - Timer lifecycle testing
   - View controller deallocation
   - Image caching validation

2. **Performance benchmarks**
   - App launch time measurement
   - Game mode transition timing
   - API response time validation

---

## **Success Criteria**

### **Architecture Compliance**
- ✅ No file exceeds 200 lines for views, 500 for services
- ✅ Proper MVVM implementation with clear separation
- ✅ Feature-based module organization
- ✅ Centralized state management with ObservableObjects

### **Performance Requirements**
- ✅ No timer memory leaks
- ✅ App launch time < 2 seconds
- ✅ Smooth 60fps gameplay
- ✅ Offline functionality for single-player modes

### **Code Quality Standards**
- ✅ No force unwrapping (`!`) in production code
- ✅ All magic numbers replaced with named constants
- ✅ Comprehensive error handling
- ✅ 80%+ test coverage for core logic

### **User Experience**
- ✅ Guest mode works without authentication
- ✅ Seamless Game Center integration
- ✅ Responsive UI on all iPhone models
- ✅ Graceful network failure handling

---

## **Risk Mitigation**

### **High Risk Items**
1. **State migration complexity** - Gradual migration strategy with fallbacks
2. **Game Center integration breaking** - Thorough testing with staging environment
3. **Performance regression** - Continuous performance monitoring
4. **API rate limiting** - Implement proper caching and fallback strategies

### **Rollback Strategy**
- Keep original `SimpleContentView.swift` until full migration complete
- Feature flags for gradual rollout
- Automated testing before each deployment
- Quick rollback procedures documented

---

## **Timeline Summary**

| Sprint | Duration | Focus Area | Critical Path |
|--------|----------|------------|---------------|
| Sprint 1 | Week 1 | Foundation & Architecture | ✅ Critical |
| Sprint 2 | Week 2 | Feature Decomposition | ✅ Critical |
| Sprint 3 | Week 3 | UI Component Breakdown | ⚠️ High |
| Sprint 4 | Week 4 | State Management & Performance | ✅ Critical |
| Sprint 5 | Week 5 | Testing & QA | ⚠️ Medium |

**Total Estimated Duration**: 5 weeks  
**Critical Path Items**: 15 tasks  
**Team Size**: 1-2 iOS developers  

---

## **Post-Refactor Maintenance**

### **Code Review Checklist**
- [ ] File size compliance (<200 lines for views)
- [ ] State management patterns followed
- [ ] Timer cleanup implemented
- [ ] Error handling comprehensive
- [ ] Tests cover new functionality
- [ ] Documentation updated
- [ ] Performance benchmarks met

### **Monitoring & Alerts**
- Set up automated file size monitoring
- Performance regression detection
- Memory leak alerts
- Test coverage reporting
- User experience metrics tracking

This refactoring plan transforms the monolithic 1,803-line file into a maintainable, testable, and scalable iOS architecture following industry best practices and the guidelines established in CLAUDE.md.
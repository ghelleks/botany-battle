# Single-User Competitions Architecture Analysis

## Overview
Analysis of existing Botany Battle codebase to identify reusable components and required modifications for implementing single-user game modes (Beat the Clock and Speedrun).

## Existing Architecture Summary

### Core Components

#### 1. Game Models (`Game.swift`)
**Reusable:**
- `Game.Difficulty` enum with time limits
- `Game.Player.Answer` struct for tracking responses
- `Round` struct with timing functionality

**Modifications Needed:**
- Add `GameMode` enum (multiplayer, beatTheClock, speedrun)
- Extend `Game` struct to support single-user scenarios
- Add single-user specific fields (personal best tracking)

#### 2. Game Logic (`GameFeature.swift`)
**Reusable:**
- Timer implementation with `timerTick` action
- Answer submission flow
- Error handling patterns
- State management using TCA (The Composable Architecture)

**Modifications Needed:**
- Refactor to support mode-agnostic gameplay
- Add single-user scoring logic
- Implement personal best comparison
- Add pause/resume for app lifecycle events

#### 3. Game Service (`GameService.swift`)
**Reusable:**
- Network abstraction patterns
- Error handling
- Async/await implementation

**NOT Reusable:**
- WebSocket connections (multiplayer-specific)
- Matchmaking logic
- Real-time updates

**New Requirements:**
- Local game session management
- Plant fetching for single-user modes
- Local scoring/timing services

#### 4. UI Components (`MainTabView.swift`)
**Reusable:**
- Game menu structure (`GameMenuView`)
- Timer display patterns (`GameProgressHeader`)
- Plant display (`PlantImageView`)
- Answer selection (`AnswerOptionsView`)
- Results screen patterns (`GameResultsView`)

**Modifications Needed:**
- Add mode selection to game menu
- Extend timer display for different mode requirements
- Add personal best displays to results

### Supporting Infrastructure

#### 1. Storage (`UserDefaultsService.swift`)
**Reusable:**
- Basic key-value storage abstraction
- Dependency injection pattern

**Extensions Needed:**
- Personal best storage methods
- Game history for single-user modes

#### 2. Design System
**Fully Reusable:**
- `BotanicalButton`, `BotanicalCard` components
- Color scheme and typography
- Navigation patterns

#### 3. Plant Models (`Plant.swift`)
**Reusable:**
- Plant data structure
- Image handling

## Reusability Assessment

### High Reusability (90%+)
- Design system components
- Plant models and display
- Timer infrastructure
- Answer submission UI
- Results display patterns

### Medium Reusability (50-90%)
- Game state management (needs mode abstraction)
- Scoring logic (needs single-user adaptations)
- Game menu (needs mode selection)
- Storage service (needs new methods)

### Low Reusability (< 50%)
- GameService networking (multiplayer-focused)
- WebSocket functionality
- Matchmaking logic

### Not Reusable
- WebSocket real-time updates
- Opponent finding
- Turn-based logic

## Recommended Refactoring Strategy

### 1. Create Mode Abstraction
```swift
enum GameMode: String, CaseIterable {
    case multiplayer = "multiplayer"
    case beatTheClock = "beat_the_clock"
    case speedrun = "speedrun"
}
```

### 2. Extend Game Model
- Add mode-specific properties
- Support single-player scenarios
- Add personal best tracking

### 3. Refactor GameFeature
- Extract mode-agnostic game logic
- Add single-user specific actions
- Implement local plant fetching

### 4. Create SingleUserGameService
- Local game session management
- Plant fetching without networking
- Local persistence for scores

### 5. Extend UI Components
- Mode selection interface
- Personal best displays
- Single-user specific progress indicators

## Implementation Impact

### Low Impact Changes
- Adding new UI components
- Extending existing models
- Adding storage methods

### Medium Impact Changes
- Refactoring GameFeature for mode support
- Extending game menu
- Adding timer pause/resume

### High Impact Changes
- Creating new service layer for single-user games
- Significant Game model extensions

## Dependencies

### Existing Dependencies (Reusable)
- The Composable Architecture (TCA)
- SwiftUI
- Starscream (not needed for single-user)
- Dependencies framework

### No New Dependencies Required
- All functionality can be implemented with existing dependencies
- Core Data would be beneficial but UserDefaults sufficient for MVP

## Conclusion

The existing architecture is well-suited for extension to single-user modes:

**Strengths:**
- Clean separation of concerns
- Composable architecture enables easy feature addition
- Robust UI component system
- Existing timer and scoring infrastructure

**Key Modifications Required:**
1. Mode abstraction layer
2. Single-user game service
3. Extended data models
4. UI extensions for mode selection

**Estimated Implementation Effort:**
- Step 2-6 (Core implementation): 2-3 days
- Step 7-10 (UI and persistence): 1-2 days
- Step 11-12 (Testing and polish): 1 day

The architecture analysis reveals a solid foundation that requires strategic extensions rather than major refactoring.
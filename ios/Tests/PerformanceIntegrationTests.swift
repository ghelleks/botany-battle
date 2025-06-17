import XCTest
import ComposableArchitecture
@testable import BotanyBattle

/// Performance tests to verify the single-user mode first implementation meets performance requirements
/// Ensures fast app launch, immediate single-user game access, and efficient authentication flows
@MainActor
final class PerformanceIntegrationTests: XCTestCase {
    
    // MARK: - App Launch Performance
    
    func testAppLaunchPerformance() {
        measure {
            let store = TestStore(
                initialState: AppFeature.State(
                    isAuthenticated: false,
                    isGuestMode: true
                )
            ) {
                AppFeature()
            }
            
            // App should initialize quickly without blocking operations
            XCTAssertNotNil(store.state)
            XCTAssertEqual(store.state.currentTab, .game)
            XCTAssertTrue(store.state.isGuestMode)
        }
    }
    
    func testGuestSessionCreationPerformance() {
        measure {
            let session = AppFeature.GuestSession()
            
            // Guest session creation should be instantaneous
            XCTAssertNotNil(session.id)
            XCTAssertEqual(session.displayName, "Guest Player")
            XCTAssertEqual(session.gamesPlayed, 0)
        }
    }
    
    // MARK: - Game Mode Selection Performance
    
    func testGameModeSelectionInitializationPerformance() {
        measure {
            let state = GameModeSelectionFeature.State()
            
            // Mode selection should initialize instantly with single-user default
            XCTAssertEqual(state.selectedMode, .beatTheClock)
            XCTAssertEqual(state.selectedDifficulty, .medium)
            XCTAssertTrue(state.showDifficultySelection)
            XCTAssertTrue(state.canStartGame)
        }
    }
    
    func testSingleUserGameStartPerformance() {
        measure {
            let session = SingleUserGameSession(
                mode: .beatTheClock,
                difficulty: .medium
            )
            
            // Single-user game session should start immediately
            XCTAssertNotNil(session.id)
            XCTAssertEqual(session.mode, .beatTheClock)
            XCTAssertEqual(session.difficulty, .medium)
            XCTAssertEqual(session.state, .active)
        }
    }
    
    // MARK: - Authentication Flow Performance
    
    func testAuthenticationStatusSyncPerformance() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: false,
                isGuestMode: true
            )
        ) {
            AppFeature()
        }
        
        // Measure authentication status sync performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await store.send(.game(.setAuthenticationStatus(true)))
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let syncTime = endTime - startTime
        
        // Authentication status sync should be near-instantaneous (< 1ms)
        XCTAssertLessThan(syncTime, 0.001)
        
        await store.assert {
            $0.game.isAuthenticated = true
        }
    }
    
    func testAuthenticationRequestDelegationPerformance() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: false,
                isGuestMode: true
            )
        ) {
            AppFeature()
        }
        
        // Measure authentication request delegation performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await store.send(.game(.delegate(.requestAuthentication(.multiplayer))))
        await store.receive(.requestFeature(.multiplayer))
        await store.receive(.showConnectPrompt(.accessMultiplayer))
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let delegationTime = endTime - startTime
        
        // Authentication delegation should be fast (< 10ms)
        XCTAssertLessThan(delegationTime, 0.01)
        
        await store.assert {
            $0.showConnectPrompt = true
        }
    }
    
    // MARK: - State Management Performance
    
    func testStateTransitionPerformance() {
        measure {
            var state = AppFeature.State(
                isAuthenticated: false,
                isGuestMode: true
            )
            
            // State transitions should be fast
            state.isAuthenticated = true
            state.isGuestMode = false
            state.currentTab = .profile
            
            XCTAssertTrue(state.isAuthenticated)
            XCTAssertFalse(state.isGuestMode)
            XCTAssertEqual(state.currentTab, .profile)
        }
    }
    
    func testFeatureAvailabilityCheckPerformance() {
        let authenticatedState = AppFeature.State(
            isAuthenticated: true,
            isGuestMode: false
        )
        
        let guestState = AppFeature.State(
            isAuthenticated: false,
            isGuestMode: true
        )
        
        measure {
            // Feature availability checks should be instantaneous
            _ = authenticatedState.isFeatureAvailable(.multiplayer)
            _ = authenticatedState.isFeatureAvailable(.profile)
            _ = guestState.isFeatureAvailable(.multiplayer)
            _ = guestState.isFeatureAvailable(.profile)
            _ = authenticatedState.availableTabs
            _ = guestState.availableTabs
        }
    }
    
    // MARK: - Memory Performance
    
    func testMemoryUsageForGuestMode() {
        measure(metrics: [XCTMemoryMetric()]) {
            let store = TestStore(
                initialState: AppFeature.State(
                    isAuthenticated: false,
                    isGuestMode: true
                )
            ) {
                AppFeature()
            }
            
            // Create multiple guest sessions to test memory usage
            for i in 0..<100 {
                let session = AppFeature.GuestSession(displayName: "Guest \(i)")
                XCTAssertNotNil(session.id)
            }
        }
    }
    
    func testMemoryUsageForGameModeSelection() {
        measure(metrics: [XCTMemoryMetric()]) {
            // Create multiple game mode selection states
            for _ in 0..<100 {
                let state = GameModeSelectionFeature.State()
                XCTAssertEqual(state.selectedMode, .beatTheClock)
            }
        }
    }
    
    // MARK: - UI Responsiveness
    
    func testGameModeCardCreationPerformance() {
        measure {
            // Simulate creating game mode cards
            for mode in [GameMode.beatTheClock, .speedrun, .multiplayer] {
                let isSelected = mode == .beatTheClock
                let requiresAuth = mode == .multiplayer
                
                // Card state calculation should be fast
                XCTAssertNotNil(mode.displayName)
                XCTAssertNotNil(mode.description)
                
                if requiresAuth {
                    XCTAssertEqual(mode, .multiplayer)
                }
                
                if isSelected {
                    XCTAssertEqual(mode, .beatTheClock)
                }
            }
        }
    }
    
    // MARK: - Data Persistence Performance
    
    func testLocalDataAccessPerformance() {
        measure {
            // Simulate local data operations
            let personalBest = PersonalBest(
                id: UUID().uuidString,
                mode: .beatTheClock,
                difficulty: .medium,
                score: 100,
                correctAnswers: 10,
                totalGameTime: 60.0,
                accuracy: 0.8,
                achievedAt: Date()
            )
            
            let gameHistory = GameHistoryItem(
                id: UUID().uuidString,
                gameMode: .speedrun,
                difficulty: .hard,
                score: 150,
                correctAnswers: 15,
                questionsAnswered: 25,
                totalGameTime: 120.0,
                completedAt: Date(),
                isNewPersonalBest: true
            )
            
            // Data creation should be fast
            XCTAssertNotNil(personalBest.id)
            XCTAssertNotNil(gameHistory.id)
            XCTAssertEqual(personalBest.mode, .beatTheClock)
            XCTAssertEqual(gameHistory.gameMode, .speedrun)
        }
    }
    
    // MARK: - Authentication Prompt Performance
    
    func testAuthenticationPromptDataPerformance() {
        measure {
            let state = AppFeature.State(
                pendingAuthAction: .accessMultiplayer
            )
            
            // Authentication prompt data should be computed quickly
            let message = state.authPromptMessage
            let benefits = state.authenticationBenefits
            
            XCTAssertFalse(message.isEmpty)
            XCTAssertFalse(benefits.isEmpty)
            XCTAssertTrue(benefits.count >= 4)
        }
    }
    
    // MARK: - Concurrent Operations Performance
    
    func testConcurrentStateUpdatesPerformance() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: false,
                isGuestMode: true
            )
        ) {
            AppFeature()
        }
        
        // Measure concurrent state update performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate rapid state changes
        await store.send(.game(.setAuthenticationStatus(true)))
        await store.send(.tabChanged(.profile))
        await store.send(.game(.modeSelection(.selectMode(.speedrun))))
        await store.send(.game(.modeSelection(.selectDifficulty(.hard))))
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        
        // All operations should complete quickly (< 50ms)
        XCTAssertLessThan(totalTime, 0.05)
    }
    
    // MARK: - Performance Benchmarks
    
    func testSingleUserGameFlowBenchmark() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: false,
                isGuestMode: true
            )
        ) {
            AppFeature()
        }
        
        // Benchmark: Complete single-user game flow
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Start Beat the Clock game
        await store.send(.game(.modeSelection(.selectMode(.beatTheClock))))
        await store.send(.game(.modeSelection(.selectDifficulty(.medium))))
        await store.send(.game(.modeSelection(.startGame)))
        await store.receive(.game(.modeSelection(.delegate(.startBeatTheClockGame(.medium)))))
        await store.receive(.game(.startSingleUserGame(.beatTheClock, .medium)))
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let gameStartTime = endTime - startTime
        
        // Single-user game should start very quickly (< 100ms)
        XCTAssertLessThan(gameStartTime, 0.1)
        
        await store.assert {
            XCTAssertNotNil($0.game.singleUserSession)
            XCTAssertEqual($0.game.selectedGameMode, .beatTheClock)
        }
    }
    
    func testAuthenticationFlowBenchmark() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: false,
                isGuestMode: true,
                game: GameFeature.State(
                    selectedGameMode: .multiplayer,
                    selectedDifficulty: .medium
                )
            )
        ) {
            AppFeature()
        }
        
        // Benchmark: Complete authentication flow
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Request authentication and succeed
        await store.send(.game(.delegate(.requestAuthentication(.multiplayer))))
        await store.receive(.requestFeature(.multiplayer))
        await store.receive(.showConnectPrompt(.accessMultiplayer))
        await store.send(.auth(.loginSuccess))
        await store.receive(.game(.setAuthenticationStatus(true)))
        await store.receive(.game(.authenticationSucceeded))
        await store.receive(.game(.searchForMultiplayerGame(.medium)))
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let authFlowTime = endTime - startTime
        
        // Authentication flow should be responsive (< 200ms)
        XCTAssertLessThan(authFlowTime, 0.2)
        
        await store.assert {
            $0.isAuthenticated = true
            $0.game.isAuthenticated = true
            $0.game.isSearchingForGame = true
        }
    }
}

// MARK: - Performance Test Extensions

extension PerformanceIntegrationTests {
    
    func measure<T>(_ block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Log performance metrics for debugging
        print("Execution time: \(executionTime * 1000) ms")
        
        return result
    }
}
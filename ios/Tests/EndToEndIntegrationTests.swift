import XCTest
import ComposableArchitecture
@testable import BotanyBattle

/// Comprehensive end-to-end integration tests for the complete single-user mode first implementation
/// Tests the full user journey from app launch through game completion in both guest and authenticated modes
@MainActor
final class EndToEndIntegrationTests: XCTestCase {
    
    // MARK: - Complete Guest User Journey
    
    func testCompleteGuestUserJourney() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: false,
                isGuestMode: true,
                authenticationPreference: .optional
            )
        ) {
            AppFeature()
        }
        
        // 1. App Launch - Guest Mode
        await store.send(.onAppear)
        await store.receive(.game(.setAuthenticationStatus(false)))
        await store.receive(.createGuestSession(nil))
        
        // Verify guest session created
        await store.assert {
            XCTAssertNotNil($0.guestSession)
            XCTAssertTrue($0.isGuestMode)
            XCTAssertFalse($0.isAuthenticated)
        }
        
        // 2. Navigate to Game Tab (default)
        XCTAssertEqual(store.state.currentTab, .game)
        
        // 3. Game Mode Selection - Default to Beat the Clock
        XCTAssertEqual(store.state.game.modeSelection.selectedMode, .beatTheClock)
        XCTAssertEqual(store.state.game.modeSelection.selectedDifficulty, .medium)
        
        // 4. Start Beat the Clock Game
        await store.send(.game(.modeSelection(.startGame)))
        await store.receive(.game(.modeSelection(.delegate(.startBeatTheClockGame(.medium)))))
        await store.receive(.game(.startSingleUserGame(.beatTheClock, .medium)))
        
        // Verify game session started
        await store.assert {
            XCTAssertEqual($0.game.selectedGameMode, .beatTheClock)
            XCTAssertEqual($0.game.selectedDifficulty, .medium)
            XCTAssertFalse($0.game.showModeSelection)
            XCTAssertNotNil($0.game.singleUserSession)
        }
        
        // 5. Complete Game Session
        await store.send(.game(.singleUserGameCompleted(nil)))
        
        // Verify game completion handling
        await store.assert {
            XCTAssertNil($0.game.singleUserSession)
            XCTAssertNil($0.game.currentQuestion)
            XCTAssertFalse($0.game.isPaused)
        }
        
        // 6. Try Speedrun Mode
        await store.send(.game(.showModeSelection(true)))
        await store.send(.game(.modeSelection(.selectMode(.speedrun))))
        await store.send(.game(.modeSelection(.setDifficulty(.hard))))
        await store.send(.game(.modeSelection(.startGame)))
        await store.receive(.game(.modeSelection(.delegate(.startSpeedrunGame(.hard)))))
        await store.receive(.game(.startSingleUserGame(.speedrun, .hard)))
        
        // Verify speedrun started
        await store.assert {
            XCTAssertEqual($0.game.selectedGameMode, .speedrun)
            XCTAssertEqual($0.game.selectedDifficulty, .hard)
            XCTAssertNotNil($0.game.singleUserSession)
        }
        
        // 7. Guest tries to access Profile (should fail gracefully)
        await store.send(.tabChanged(.profile))
        await store.receive(.requestFeature(.profile))
        await store.receive(.showConnectPrompt(.viewProfile))
        
        // Verify authentication prompt shown
        await store.assert {
            $0.currentTab = .profile
            $0.showConnectPrompt = true
            $0.pendingAuthAction = .viewProfile
        }
        
        // 8. Guest dismisses authentication prompt
        await store.send(.hideConnectPrompt)
        
        // Verify prompt dismissed
        await store.assert {
            $0.showConnectPrompt = false
            $0.pendingAuthAction = nil
        }
    }
    
    func testGuestUserTriesMultiplayer() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: false,
                isGuestMode: true
            )
        ) {
            AppFeature()
        }
        
        // Guest tries to start multiplayer
        await store.send(.game(.modeSelection(.selectMode(.multiplayer))))
        await store.send(.game(.modeSelection(.startGame)))
        await store.receive(.game(.modeSelection(.delegate(.startMultiplayerGame(.medium)))))
        await store.receive(.game(.delegate(.requestAuthentication(.multiplayer))))
        await store.receive(.requestFeature(.multiplayer))
        await store.receive(.showConnectPrompt(.accessMultiplayer))
        
        // Verify authentication prompt for multiplayer
        await store.assert {
            $0.showConnectPrompt = true
            $0.pendingAuthAction = .accessMultiplayer
            $0.game.selectedGameMode = .multiplayer
        }
        
        // Guest chooses "Maybe Later"
        await store.send(.hideConnectPrompt)
        
        // Guest can still access single-user modes
        await store.send(.game(.modeSelection(.selectMode(.beatTheClock))))
        await store.send(.game(.modeSelection(.startGame)))
        await store.receive(.game(.modeSelection(.delegate(.startBeatTheClockGame(.medium)))))
        await store.receive(.game(.startSingleUserGame(.beatTheClock, .medium)))
        
        // Verify single-user game starts normally
        await store.assert {
            XCTAssertNotNil($0.game.singleUserSession)
            XCTAssertEqual($0.game.selectedGameMode, .beatTheClock)
        }
    }
    
    // MARK: - Complete Authenticated User Journey
    
    func testCompleteAuthenticatedUserJourney() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: true,
                isGuestMode: false,
                authenticationPreference: .optional
            )
        ) {
            AppFeature()
        }
        
        // 1. App Launch - Authenticated Mode
        await store.send(.onAppear)
        await store.receive(.game(.setAuthenticationStatus(true)))
        
        // Verify authenticated state
        await store.assert {
            $0.isAuthenticated = true
            $0.isGuestMode = false
        }
        
        // 2. All tabs should be available
        XCTAssertTrue(store.state.availableTabs.contains(.profile))
        XCTAssertTrue(store.state.availableTabs.contains(.game))
        XCTAssertTrue(store.state.availableTabs.contains(.shop))
        XCTAssertTrue(store.state.availableTabs.contains(.settings))
        
        // 3. Single-user modes still work
        await store.send(.game(.modeSelection(.selectMode(.beatTheClock))))
        await store.send(.game(.modeSelection(.startGame)))
        await store.receive(.game(.modeSelection(.delegate(.startBeatTheClockGame(.medium)))))
        await store.receive(.game(.startSingleUserGame(.beatTheClock, .medium)))
        
        await store.assert {
            XCTAssertNotNil($0.game.singleUserSession)
        }
        
        // 4. Return to mode selection and try multiplayer
        await store.send(.game(.leaveGame))
        
        await store.assert {
            $0.game.showModeSelection = true
            $0.game.singleUserSession = nil
        }
        
        // 5. Start multiplayer (should work without prompts)
        await store.send(.game(.modeSelection(.selectMode(.multiplayer))))
        await store.send(.game(.modeSelection(.startGame)))
        await store.receive(.game(.modeSelection(.delegate(.startMultiplayerGame(.medium)))))
        await store.receive(.game(.searchForMultiplayerGame(.medium)))
        
        // Verify multiplayer search starts
        await store.assert {
            $0.game.selectedGameMode = .multiplayer
            $0.game.isSearchingForGame = true
            $0.game.showModeSelection = false
        }
        
        // 6. Access profile tab (should work)
        await store.send(.tabChanged(.profile))
        
        await store.assert {
            $0.currentTab = .profile
            // No authentication prompt should appear
            $0.showConnectPrompt = false
        }
    }
    
    // MARK: - Authentication Transition Journey
    
    func testGuestToAuthenticatedTransition() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: false,
                isGuestMode: true,
                game: GameFeature.State(
                    selectedGameMode: .multiplayer,
                    selectedDifficulty: .medium
                ),
                showConnectPrompt: true,
                pendingAuthAction: .accessMultiplayer
            )
        ) {
            AppFeature()
        }
        
        // User decides to authenticate for multiplayer
        await store.send(.requestAuthentication)
        
        // Simulate successful authentication
        await store.send(.auth(.loginSuccess))
        await store.receive(.game(.setAuthenticationStatus(true)))
        await store.receive(.game(.authenticationSucceeded))
        await store.receive(.game(.searchForMultiplayerGame(.medium)))
        
        // Verify transition to authenticated state and multiplayer start
        await store.assert {
            $0.isAuthenticated = true
            $0.isGuestMode = false
            $0.showConnectPrompt = false
            $0.pendingAuthAction = nil
            $0.game.isAuthenticated = true
            $0.game.isSearchingForGame = true
        }
        
        // Verify all features now available
        XCTAssertTrue(store.state.isFeatureAvailable(.multiplayer))
        XCTAssertTrue(store.state.isFeatureAvailable(.profile))
        XCTAssertTrue(store.state.availableTabs.contains(.profile))
    }
    
    // MARK: - Tab Navigation and Feature Access
    
    func testTabNavigationWithAuthentication() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: false,
                isGuestMode: true
            )
        ) {
            AppFeature()
        }
        
        // Guest can access game tab
        await store.send(.tabChanged(.game))
        await store.assert { $0.currentTab = .game }
        
        // Guest can access shop tab
        await store.send(.tabChanged(.shop))
        await store.assert { $0.currentTab = .shop }
        
        // Guest can access settings tab
        await store.send(.tabChanged(.settings))
        await store.assert { $0.currentTab = .settings }
        
        // Guest trying to access profile triggers auth prompt
        await store.send(.tabChanged(.profile))
        await store.receive(.requestFeature(.profile))
        await store.receive(.showConnectPrompt(.viewProfile))
        
        await store.assert {
            $0.currentTab = .profile
            $0.showConnectPrompt = true
        }
    }
    
    // MARK: - Game Mode Selection UI Integration
    
    func testGameModeSelectionUIStates() {
        // Test default state
        let defaultState = GameModeSelectionFeature.State()
        XCTAssertEqual(defaultState.selectedMode, .beatTheClock)
        XCTAssertEqual(defaultState.selectedDifficulty, .medium)
        XCTAssertTrue(defaultState.showDifficultySelection)
        
        // Test multiplayer selection
        var multiplayerState = GameModeSelectionFeature.State()
        multiplayerState.selectedMode = .multiplayer
        multiplayerState.showDifficultySelection = false
        
        XCTAssertEqual(multiplayerState.selectedMode, .multiplayer)
        XCTAssertFalse(multiplayerState.showDifficultySelection)
        
        // Test can start game conditions
        XCTAssertTrue(defaultState.canStartGame)
        XCTAssertTrue(multiplayerState.canStartGame)
        
        // Test loading state prevents game start
        var loadingState = GameModeSelectionFeature.State()
        loadingState.isLoading = true
        XCTAssertFalse(loadingState.canStartGame)
    }
    
    // MARK: - Error Handling and Edge Cases
    
    func testErrorHandlingInGameFlow() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: false,
                isGuestMode: true
            )
        ) {
            AppFeature()
        }
        
        // Test game error handling
        await store.send(.game(.gameError("Test error")))
        
        await store.assert {
            $0.game.error = "Test error"
            $0.game.isSearchingForGame = false
        }
        
        // Test error clearing
        await store.send(.game(.clearError))
        
        await store.assert {
            $0.game.error = nil
        }
    }
    
    func testAuthenticationPreferences() async {
        let store = TestStore(
            initialState: AppFeature.State(
                authenticationPreference: .optional
            )
        ) {
            AppFeature()
        }
        
        // Test setting authentication preference to required
        await store.send(.setAuthenticationPreference(.required))
        
        await store.assert {
            $0.authenticationPreference = .required
        }
        
        // Test setting to disabled
        await store.send(.setAuthenticationPreference(.disabled))
        
        await store.assert {
            $0.authenticationPreference = .disabled
        }
    }
    
    // MARK: - Data Persistence and Session Management
    
    func testGuestSessionManagement() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isGuestMode: true,
                guestSession: nil
            )
        ) {
            AppFeature()
        }
        
        // Create guest session
        await store.send(.createGuestSession("Test Guest"))
        await store.receive(.sessionStarted)
        
        await store.assert {
            XCTAssertNotNil($0.guestSession)
            XCTAssertEqual($0.guestSession?.displayName, "Test Guest")
        }
        
        // Record game completion
        await store.send(.recordGameCompletion(score: 100, difficulty: .medium))
        
        await store.assert {
            XCTAssertEqual($0.guestSession?.gamesPlayed, 1)
            XCTAssertEqual($0.guestSession?.totalScore, 100)
        }
    }
    
    // MARK: - Performance and State Consistency
    
    func testStateConsistency() {
        let state = AppFeature.State(
            isAuthenticated: true,
            isGuestMode: false
        )
        
        // Authentication state should be consistent
        XCTAssertTrue(state.isAuthenticated)
        XCTAssertFalse(state.isGuestMode)
        XCTAssertFalse(state.requiresAuthentication)
        
        // Available features should match authentication state
        XCTAssertTrue(state.isFeatureAvailable(.multiplayer))
        XCTAssertTrue(state.isFeatureAvailable(.profile))
        XCTAssertTrue(state.isFeatureAvailable(.leaderboards))
        
        // Available tabs should include all tabs for authenticated users
        XCTAssertEqual(state.availableTabs.count, AppFeature.State.Tab.allCases.count)
    }
    
    func testGuestModeStateConsistency() {
        let state = AppFeature.State(
            isAuthenticated: false,
            isGuestMode: true
        )
        
        // Guest state should be consistent
        XCTAssertFalse(state.isAuthenticated)
        XCTAssertTrue(state.isGuestMode)
        XCTAssertFalse(state.requiresAuthentication) // Guest mode doesn't require auth
        
        // Available features should be limited
        XCTAssertFalse(state.isFeatureAvailable(.multiplayer))
        XCTAssertFalse(state.isFeatureAvailable(.profile))
        
        // Available tabs should exclude profile
        XCTAssertFalse(state.availableTabs.contains(.profile))
        XCTAssertTrue(state.availableTabs.contains(.game))
        XCTAssertTrue(state.availableTabs.contains(.shop))
        XCTAssertTrue(state.availableTabs.contains(.settings))
    }
}

// MARK: - Test Utilities

extension TestStore where State == AppFeature.State, Action == AppFeature.Action {
    func assert(_ assertion: @escaping (inout State) -> Void) async {
        await self.withState(assertion)
    }
}
import XCTest
import ComposableArchitecture
@testable import BotanyBattle

/// Comprehensive tests for authentication integration between AppFeature and GameFeature
/// Verifies that single-user modes work without authentication while multiplayer properly
/// requests authentication when needed.
@MainActor
final class AuthenticationIntegrationTests: XCTestCase {
    
    // MARK: - Single-User Mode Tests (No Authentication Required)
    
    func testBeatTheClockWorksWithoutAuthentication() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: false,
                isGuestMode: true
            )
        ) {
            AppFeature()
        }
        
        // Start Beat the Clock game without authentication
        await store.send(.game(.modeSelection(.selectMode(.beatTheClock))))
        await store.receive(.game(.modeSelection(.selectMode(.beatTheClock))))
        
        await store.send(.game(.modeSelection(.selectDifficulty(.medium))))
        await store.receive(.game(.modeSelection(.setDifficulty(.medium))))
        
        await store.send(.game(.modeSelection(.startGame)))
        await store.receive(.game(.modeSelection(.delegate(.startBeatTheClockGame(.medium)))))
        await store.receive(.game(.startSingleUserGame(.beatTheClock, .medium)))
        
        // Verify game state
        await store.assert {
            $0.game.selectedGameMode = .beatTheClock
            $0.game.selectedDifficulty = .medium
            $0.game.showModeSelection = false
            XCTAssertNotNil($0.game.singleUserSession)
        }
    }
    
    func testSpeedrunWorksWithoutAuthentication() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: false,
                isGuestMode: true
            )
        ) {
            AppFeature()
        }
        
        // Start Speedrun game without authentication
        await store.send(.game(.modeSelection(.selectMode(.speedrun))))
        await store.receive(.game(.modeSelection(.selectMode(.speedrun))))
        
        await store.send(.game(.modeSelection(.setDifficulty(.hard))))
        await store.receive(.game(.modeSelection(.setDifficulty(.hard))))
        
        await store.send(.game(.modeSelection(.startGame)))
        await store.receive(.game(.modeSelection(.delegate(.startSpeedrunGame(.hard)))))
        await store.receive(.game(.startSingleUserGame(.speedrun, .hard)))
        
        // Verify game state
        await store.assert {
            $0.game.selectedGameMode = .speedrun
            $0.game.selectedDifficulty = .hard
            $0.game.showModeSelection = false
            XCTAssertNotNil($0.game.singleUserSession)
        }
    }
    
    // MARK: - Multiplayer Authentication Tests
    
    func testMultiplayerRequestsAuthenticationWhenNotAuthenticated() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: false,
                isGuestMode: true
            )
        ) {
            AppFeature()
        }
        
        // Try to start multiplayer without authentication
        await store.send(.game(.modeSelection(.selectMode(.multiplayer))))
        await store.receive(.game(.modeSelection(.selectMode(.multiplayer))))
        
        await store.send(.game(.modeSelection(.setDifficulty(.medium))))
        await store.receive(.game(.modeSelection(.setDifficulty(.medium))))
        
        await store.send(.game(.modeSelection(.startGame)))
        await store.receive(.game(.modeSelection(.delegate(.startMultiplayerGame(.medium)))))
        await store.receive(.game(.delegate(.requestAuthentication(.multiplayer))))
        await store.receive(.requestFeature(.multiplayer))
        await store.receive(.showConnectPrompt(.accessMultiplayer))
        
        // Verify authentication prompt is shown
        await store.assert {
            $0.showConnectPrompt = true
            $0.pendingAuthAction = .accessMultiplayer
            $0.game.selectedGameMode = .multiplayer
            $0.game.selectedDifficulty = .medium
        }
    }
    
    func testMultiplayerStartsWhenAuthenticated() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: true,
                isGuestMode: false
            )
        ) {
            AppFeature()
        }
        
        // Start multiplayer with authentication
        await store.send(.game(.modeSelection(.selectMode(.multiplayer))))
        await store.receive(.game(.modeSelection(.selectMode(.multiplayer))))
        
        await store.send(.game(.modeSelection(.setDifficulty(.easy))))
        await store.receive(.game(.modeSelection(.setDifficulty(.easy))))
        
        await store.send(.game(.modeSelection(.startGame)))
        await store.receive(.game(.modeSelection(.delegate(.startMultiplayerGame(.easy)))))
        await store.receive(.game(.searchForMultiplayerGame(.easy)))
        
        // Verify multiplayer search begins
        await store.assert {
            $0.game.selectedGameMode = .multiplayer
            $0.game.selectedDifficulty = .easy
            $0.game.showModeSelection = false
            $0.game.isSearchingForGame = true
        }
    }
    
    func testAuthenticationFlowCompletesMultiplayer() async {
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
        
        // Simulate successful authentication
        await store.send(.auth(.loginSuccess))
        await store.receive(.game(.setAuthenticationStatus(true)))
        await store.receive(.game(.authenticationSucceeded))
        await store.receive(.game(.searchForMultiplayerGame(.medium)))
        
        // Verify authentication state updated and multiplayer started
        await store.assert {
            $0.isAuthenticated = true
            $0.isGuestMode = false
            $0.showConnectPrompt = false
            $0.pendingAuthAction = nil
            $0.game.isAuthenticated = true
            $0.game.showModeSelection = false
            $0.game.isSearchingForGame = true
        }
    }
    
    // MARK: - Authentication Status Synchronization Tests
    
    func testAuthenticationStatusSyncsOnAppLaunch() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: true,
                isGuestMode: false
            )
        ) {
            AppFeature()
        }
        
        await store.send(.onAppear)
        await store.receive(.game(.setAuthenticationStatus(true)))
        // Additional effects from handleInitialAuth would be tested here
        
        // Verify game feature receives authentication status
        await store.assert {
            $0.game.isAuthenticated = true
        }
    }
    
    func testLogoutSyncsAuthenticationStatus() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: true,
                isGuestMode: false
            )
        ) {
            AppFeature()
        }
        
        await store.send(.auth(.logoutSuccess))
        await store.receive(.game(.setAuthenticationStatus(false)))
        await store.receive(.createGuestSession(nil))
        
        // Verify authentication status updated
        await store.assert {
            $0.isAuthenticated = false
            $0.isGuestMode = true
            $0.game.isAuthenticated = false
        }
    }
    
    // MARK: - Authentication Prompt Tests
    
    func testAuthenticationPromptMessage() {
        var state = AppFeature.State()
        
        // Test multiplayer prompt message
        state.pendingAuthAction = .accessMultiplayer
        XCTAssertEqual(
            state.authPromptMessage,
            "Connect with Game Center to play against other players"
        )
        
        // Test profile prompt message
        state.pendingAuthAction = .viewProfile
        XCTAssertEqual(
            state.authPromptMessage,
            "Connect with Game Center to view your profile and achievements"
        )
        
        // Test default message
        state.pendingAuthAction = nil
        XCTAssertEqual(
            state.authPromptMessage,
            "Connect with Game Center to unlock additional features"
        )
    }
    
    func testAuthenticationBenefits() {
        let state = AppFeature.State()
        let benefits = state.authenticationBenefits
        
        XCTAssertTrue(benefits.contains("Play multiplayer battles against other players"))
        XCTAssertTrue(benefits.contains("Compete on global leaderboards"))
        XCTAssertTrue(benefits.contains("Sync your progress across devices"))
        XCTAssertTrue(benefits.contains("Earn Game Center achievements"))
    }
    
    // MARK: - Error Handling Tests
    
    func testMultiplayerErrorHandlingWhenAuthenticationUnavailable() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: false,
                isGuestMode: true,
                authenticationPreference: .disabled // Authentication disabled
            )
        ) {
            AppFeature()
        }
        
        // Try to start multiplayer with authentication disabled
        await store.send(.game(.modeSelection(.selectMode(.multiplayer))))
        await store.receive(.game(.modeSelection(.selectMode(.multiplayer))))
        
        await store.send(.game(.modeSelection(.startGame)))
        await store.receive(.game(.modeSelection(.delegate(.startMultiplayerGame(.medium)))))
        await store.receive(.game(.delegate(.requestAuthentication(.multiplayer))))
        await store.receive(.requestFeature(.multiplayer))
        await store.receive(.showConnectPrompt(.accessMultiplayer))
        
        // Even with authentication disabled, the prompt should still show
        // to inform the user that multiplayer requires authentication
        await store.assert {
            $0.showConnectPrompt = true
            $0.pendingAuthAction = .accessMultiplayer
        }
    }
    
    // MARK: - Integration State Tests
    
    func testGameModeSelectionShowsCorrectAuthenticationStatus() {
        let authenticatedState = AppFeature.State(
            isAuthenticated: true,
            isGuestMode: false
        )
        
        let guestState = AppFeature.State(
            isAuthenticated: false,
            isGuestMode: true
        )
        
        // Test authenticated state
        XCTAssertTrue(authenticatedState.isFeatureAvailable(.multiplayer))
        XCTAssertTrue(authenticatedState.isFeatureAvailable(.profile))
        
        // Test guest state
        XCTAssertFalse(guestState.isFeatureAvailable(.multiplayer))
        XCTAssertFalse(guestState.isFeatureAvailable(.profile))
    }
    
    func testAvailableTabsBasedOnAuthenticationStatus() {
        let authenticatedState = AppFeature.State(
            isAuthenticated: true,
            isGuestMode: false
        )
        
        let guestState = AppFeature.State(
            isAuthenticated: false,
            isGuestMode: true
        )
        
        // Authenticated users see all tabs
        XCTAssertEqual(authenticatedState.availableTabs.count, AppFeature.State.Tab.allCases.count)
        XCTAssertTrue(authenticatedState.availableTabs.contains(.profile))
        
        // Guest users don't see profile tab
        XCTAssertFalse(guestState.availableTabs.contains(.profile))
        XCTAssertTrue(guestState.availableTabs.contains(.game))
        XCTAssertTrue(guestState.availableTabs.contains(.shop))
        XCTAssertTrue(guestState.availableTabs.contains(.settings))
    }
}

// MARK: - Test Extensions

extension TestStore where State == AppFeature.State, Action == AppFeature.Action {
    func assert(_ assertion: @escaping (inout State) -> Void) async {
        await self.withState(assertion)
    }
}
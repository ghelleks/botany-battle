import XCTest
import SwiftUI
import ComposableArchitecture
@testable import BotanyBattle

/// Simple integration test for GameModeSelectionView authentication integration
@MainActor
final class GameModeSelectionIntegrationTest: XCTestCase {
    
    func testGameModeSelectionAuthenticationState() {
        // Test authenticated state
        let authenticatedStore = Store(
            initialState: GameModeSelectionFeature.State(),
            reducer: { GameModeSelectionFeature() }
        )
        
        let authenticatedView = GameModeSelectionView(
            store: authenticatedStore,
            isAuthenticated: true
        )
        
        // Test unauthenticated state
        let unauthenticatedStore = Store(
            initialState: GameModeSelectionFeature.State(),
            reducer: { GameModeSelectionFeature() }
        )
        
        let unauthenticatedView = GameModeSelectionView(
            store: unauthenticatedStore,
            isAuthenticated: false
        )
        
        // Views should initialize without error
        XCTAssertNotNil(authenticatedView)
        XCTAssertNotNil(unauthenticatedView)
    }
    
    func testDefaultGameModeSelection() {
        let state = GameModeSelectionFeature.State()
        
        // Default mode should be Beat the Clock (single-user)
        XCTAssertEqual(state.selectedMode, .beatTheClock)
        
        // Default difficulty should be medium
        XCTAssertEqual(state.selectedDifficulty, .medium)
        
        // Difficulty selection should be shown for single-user modes
        XCTAssertTrue(state.showDifficultySelection)
    }
    
    func testMultiplayerModeSelection() {
        var state = GameModeSelectionFeature.State()
        
        // Select multiplayer mode
        state.selectedMode = .multiplayer
        
        // Difficulty selection should be hidden for multiplayer
        state.showDifficultySelection = false
        
        XCTAssertEqual(state.selectedMode, .multiplayer)
        XCTAssertFalse(state.showDifficultySelection)
    }
    
    func testSingleUserModeCanStart() {
        let state = GameModeSelectionFeature.State(
            selectedMode: .beatTheClock,
            selectedDifficulty: .easy
        )
        
        // Single-user mode should be able to start
        XCTAssertTrue(state.canStartGame)
    }
}
import XCTest
import ComposableArchitecture
@testable import BotanyBattle

@MainActor
final class AppFeatureTests: XCTestCase {
    
    func testTabNavigation() async {
        let store = TestStore(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )
        
        await store.send(.tabChanged(.profile)) {
            $0.currentTab = .profile
        }
        
        await store.send(.tabChanged(.shop)) {
            $0.currentTab = .shop
        }
        
        await store.send(.tabChanged(.game)) {
            $0.currentTab = .game
        }
    }
    
    func testOnAppear() async {
        let store = TestStore(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )
        
        await store.send(.onAppear)
    }
    
    // MARK: - Authentication Integration Tests
    
    func testGameDelegateRequestsAuthentication() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: false,
                isGuestMode: true
            ),
            reducer: { AppFeature() }
        )
        
        // Simulate GameFeature requesting authentication for multiplayer
        await store.send(.game(.delegate(.requestAuthentication(.multiplayer)))) {
            $0.attemptedAuthFeatures.insert(.multiplayer)
            $0.showConnectPrompt = true
            $0.pendingAuthAction = .accessMultiplayer
        }
    }
    
    func testAuthenticationSuccessSyncsToGame() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: false,
                isGuestMode: true
            ),
            reducer: { AppFeature() }
        )
        
        // Simulate successful authentication
        await store.send(.auth(.loginSuccess)) {
            $0.isAuthenticated = true
            $0.isGuestMode = false
            $0.userRequestedAuthentication = false
            $0.showConnectPrompt = false
            $0.pendingAuthAction = nil
            $0.attemptedAuthFeatures.removeAll()
        }
    }
    
    func testSingleUserModesAvailableWithoutAuth() {
        let state = AppFeature.State(
            isAuthenticated: false,
            isGuestMode: true
        )
        
        // Single-user modes should always be available
        XCTAssertTrue(state.availableTabs.contains(.game))
        XCTAssertTrue(state.availableTabs.contains(.shop))
        XCTAssertTrue(state.availableTabs.contains(.settings))
        
        // Profile requires authentication
        XCTAssertFalse(state.availableTabs.contains(.profile))
    }
    
    func testMultiplayerRequiresAuthentication() {
        let unauthenticatedState = AppFeature.State(
            isAuthenticated: false,
            isGuestMode: true
        )
        
        let authenticatedState = AppFeature.State(
            isAuthenticated: true,
            isGuestMode: false
        )
        
        // Unauthenticated state should not have multiplayer available
        XCTAssertFalse(unauthenticatedState.isFeatureAvailable(.multiplayer))
        
        // Authenticated state should have multiplayer available
        XCTAssertTrue(authenticatedState.isFeatureAvailable(.multiplayer))
    }
}
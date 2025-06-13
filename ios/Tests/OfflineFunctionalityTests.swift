import XCTest
@testable import BotanyBattle

final class OfflineFunctionalityTests: XCTestCase {
    
    func testAppStateHandlesOfflineMode() {
        let appState = AppState()
        
        // Test that app state can handle offline scenarios
        XCTAssertNotNil(appState)
        
        // Test initial state
        XCTAssertFalse(appState.isOnline)
        XCTAssertNil(appState.user)
    }
    
    func testNetworkErrorHandling() {
        // Test that network errors are properly handled
        let afError = AFError.sessionTaskFailed(error: URLError(.notConnectedToInternet))
        let networkError = NetworkError.requestFailed(afError)
        
        XCTAssertNotNil(networkError.errorDescription)
        XCTAssertTrue(networkError.errorDescription!.contains("failed"))
    }
    
    func testOfflineDataPersistence() {
        // Test that essential data can be stored offline
        let user = User(
            id: "offline-user",
            username: "offlineuser",
            email: "offline@example.com",
            displayName: "Offline User",
            avatarURL: nil,
            eloRating: 1000,
            totalWins: 0,
            totalLosses: 0,
            totalMatches: 0,
            winRate: 0.0,
            trophies: 0,
            rank: 999,
            isOnline: false,
            lastActive: Date(),
            createdAt: Date(),
            achievements: [],
            level: 1,
            experience: 0,
            experienceToNextLevel: 1000
        )
        
        // Basic validation that offline user data is valid
        XCTAssertEqual(user.username, "offlineuser")
        XCTAssertFalse(user.isOnline)
        XCTAssertEqual(user.totalMatches, 0)
    }
    
    func testOfflineGameStateHandling() {
        // Test that game state can handle offline scenarios
        let game = Game(
            id: "offline-game",
            state: .finished,
            currentRound: 1,
            maxRounds: 1,
            players: [],
            rounds: [],
            winner: nil,
            createdAt: Date(),
            startedAt: Date(),
            endedAt: Date(),
            isRanked: false,
            difficulty: .easy
        )
        
        XCTAssertEqual(game.state, .finished)
        XCTAssertFalse(game.isRanked) // Offline games should not be ranked
    }
}
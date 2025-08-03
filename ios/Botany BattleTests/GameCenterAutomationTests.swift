import XCTest
import GameKit
@testable import BotanyBattle

final class GameCenterAutomationTests: XCTestCase {
    
    var gameCenterService: GameCenterService!
    var mockDelegate: MockGameCenterDelegate!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        gameCenterService = GameCenterService()
        mockDelegate = MockGameCenterDelegate()
        gameCenterService.delegate = mockDelegate
        
        // Setup test environment
        setupGameCenterTestEnvironment()
    }
    
    override func tearDownWithError() throws {
        gameCenterService = nil
        mockDelegate = nil
        try super.tearDownWithError()
    }
    
    private func setupGameCenterTestEnvironment() {
        // Configure Game Center for testing
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            if let error = error {
                print("Game Center authentication error: \(error)")
                return
            }
            
            if let viewController = viewController {
                // In automated tests, we simulate authentication success
                DispatchQueue.main.async {
                    self?.simulateAuthenticationSuccess()
                }
            } else {
                // Player is already authenticated
                print("Game Center player already authenticated")
            }
        }
    }
    
    private func simulateAuthenticationSuccess() {
        // Simulate successful authentication for testing
        mockDelegate.onAuthenticationSuccess?()
    }
    
    // MARK: - Authentication Tests
    
    func testGameCenterAuthentication() throws {
        let expectation = XCTestExpectation(description: "Game Center authentication")
        
        mockDelegate.onAuthenticationSuccess = {
            expectation.fulfill()
        }
        
        mockDelegate.onAuthenticationFailure = { error in
            XCTFail("Authentication should not fail in test environment: \(error)")
        }
        
        gameCenterService.authenticatePlayer()
        
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertTrue(gameCenterService.isAuthenticated)
        XCTAssertNotNil(GKLocalPlayer.local.displayName)
    }
    
    func testAuthenticationWithoutGameCenter() throws {
        // Test behavior when Game Center is not available
        let expectation = XCTestExpectation(description: "Authentication failure handled")
        
        mockDelegate.onAuthenticationFailure = { error in
            XCTAssertTrue(error is GameCenterError)
            expectation.fulfill()
        }
        
        // Simulate Game Center unavailable
        gameCenterService.simulateGameCenterUnavailable()
        gameCenterService.authenticatePlayer()
        
        wait(for: [expectation], timeout: 5.0)
        
        XCTAssertFalse(gameCenterService.isAuthenticated)
    }
    
    // MARK: - Leaderboard Tests
    
    func testLeaderboardSubmission() throws {
        let expectation = XCTestExpectation(description: "Leaderboard score submitted")
        
        mockDelegate.onLeaderboardSubmissionSuccess = { leaderboardID, score in
            XCTAssertEqual(leaderboardID, TestConstants.winsLeaderboardID)
            XCTAssertEqual(score, 42)
            expectation.fulfill()
        }
        
        // Ensure authenticated first
        gameCenterService.authenticatePlayer()
        
        // Submit score
        gameCenterService.submitScore(42, to: TestConstants.winsLeaderboardID)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testMultipleLeaderboardSubmissions() throws {
        let expectation = XCTestExpectation(description: "Multiple leaderboard submissions")
        expectation.expectedFulfillmentCount = 3
        
        let leaderboards = [
            (TestConstants.winsLeaderboardID, 5),
            (TestConstants.streakLeaderboardID, 3),
            (TestConstants.speedrunLeaderboardID, 120)
        ]
        
        mockDelegate.onLeaderboardSubmissionSuccess = { leaderboardID, score in
            expectation.fulfill()
        }
        
        gameCenterService.authenticatePlayer()
        
        for (leaderboardID, score) in leaderboards {
            gameCenterService.submitScore(score, to: leaderboardID)
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    func testLeaderboardRetrieval() throws {
        let expectation = XCTestExpectation(description: "Leaderboard data retrieved")
        
        mockDelegate.onLeaderboardDataReceived = { leaderboardID, scores in
            XCTAssertEqual(leaderboardID, TestConstants.winsLeaderboardID)
            XCTAssertGreaterThan(scores.count, 0)
            
            // Verify score structure
            let firstScore = scores[0]
            XCTAssertNotNil(firstScore.player)
            XCTAssertGreaterThan(firstScore.value, 0)
            XCTAssertGreaterThan(firstScore.rank, 0)
            
            expectation.fulfill()
        }
        
        gameCenterService.authenticatePlayer()
        gameCenterService.loadLeaderboard(TestConstants.winsLeaderboardID, timeScope: .allTime, range: NSRange(location: 1, length: 10))
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Achievement Tests
    
    func testAchievementProgress() throws {
        let expectation = XCTestExpectation(description: "Achievement progress updated")
        
        mockDelegate.onAchievementProgressUpdated = { achievementID, percentComplete in
            XCTAssertEqual(achievementID, TestConstants.firstWinAchievementID)
            XCTAssertEqual(percentComplete, 100.0)
            expectation.fulfill()
        }
        
        gameCenterService.authenticatePlayer()
        gameCenterService.updateAchievementProgress(TestConstants.firstWinAchievementID, percentComplete: 100.0)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testIncrementalAchievementProgress() throws {
        let expectation = XCTestExpectation(description: "Incremental achievement progress")
        expectation.expectedFulfillmentCount = 3
        
        var progressUpdates: [Double] = []
        
        mockDelegate.onAchievementProgressUpdated = { achievementID, percentComplete in
            progressUpdates.append(percentComplete)
            expectation.fulfill()
        }
        
        gameCenterService.authenticatePlayer()
        
        // Simulate incremental progress (25%, 50%, 100%)
        gameCenterService.updateAchievementProgress(TestConstants.win10GamesAchievementID, percentComplete: 25.0)
        gameCenterService.updateAchievementProgress(TestConstants.win10GamesAchievementID, percentComplete: 50.0)
        gameCenterService.updateAchievementProgress(TestConstants.win10GamesAchievementID, percentComplete: 100.0)
        
        wait(for: [expectation], timeout: 15.0)
        
        XCTAssertEqual(progressUpdates.count, 3)
        XCTAssertEqual(progressUpdates[0], 25.0)
        XCTAssertEqual(progressUpdates[1], 50.0)
        XCTAssertEqual(progressUpdates[2], 100.0)
    }
    
    func testAchievementCompletion() throws {
        let expectation = XCTestExpectation(description: "Achievement completed")
        
        mockDelegate.onAchievementCompleted = { achievementID in
            XCTAssertEqual(achievementID, TestConstants.firstWinAchievementID)
            expectation.fulfill()
        }
        
        gameCenterService.authenticatePlayer()
        gameCenterService.updateAchievementProgress(TestConstants.firstWinAchievementID, percentComplete: 100.0)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testLoadAllAchievements() throws {
        let expectation = XCTestExpectation(description: "All achievements loaded")
        
        mockDelegate.onAchievementsLoaded = { achievements in
            XCTAssertGreaterThan(achievements.count, 0)
            
            // Verify achievement structure
            let firstAchievement = achievements[0]
            XCTAssertNotNil(firstAchievement.identifier)
            XCTAssertGreaterThanOrEqual(firstAchievement.percentComplete, 0.0)
            XCTAssertLessThanOrEqual(firstAchievement.percentComplete, 100.0)
            
            expectation.fulfill()
        }
        
        gameCenterService.authenticatePlayer()
        gameCenterService.loadAchievements()
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Multiplayer Integration Tests
    
    func testMatchmakingRequest() throws {
        let expectation = XCTestExpectation(description: "Matchmaking request initiated")
        
        mockDelegate.onMatchmakingStarted = { request in
            XCTAssertEqual(request.minPlayers, 2)
            XCTAssertEqual(request.maxPlayers, 2)
            XCTAssertEqual(request.playerGroup, 0)
            expectation.fulfill()
        }
        
        gameCenterService.authenticatePlayer()
        
        let matchRequest = GKMatchRequest()
        matchRequest.minPlayers = 2
        matchRequest.maxPlayers = 2
        matchRequest.playerGroup = 0
        
        gameCenterService.startMatchmaking(with: matchRequest)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testMatchFound() throws {
        let expectation = XCTestExpectation(description: "Match found")
        
        mockDelegate.onMatchFound = { match in
            XCTAssertNotNil(match)
            XCTAssertEqual(match.players.count, 2)
            expectation.fulfill()
        }
        
        gameCenterService.authenticatePlayer()
        
        // Simulate match found
        let mockMatch = MockGKMatch()
        gameCenterService.simulateMatchFound(mockMatch)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testDirectPlayerInvite() throws {
        let expectation = XCTestExpectation(description: "Direct player invite sent")
        
        mockDelegate.onInviteSent = { playerIDs in
            XCTAssertEqual(playerIDs.count, 1)
            XCTAssertEqual(playerIDs[0], "test-player-id")
            expectation.fulfill()
        }
        
        gameCenterService.authenticatePlayer()
        gameCenterService.invitePlayer(withID: "test-player-id")
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Data Synchronization Tests
    
    func testGameDataSync() throws {
        let expectation = XCTestExpectation(description: "Game data synchronized")
        
        let testGameData = GameData(
            playerId: "test-player",
            totalGames: 50,
            wins: 35,
            currentStreak: 5,
            bestTime: 120.5,
            trophies: 1500
        )
        
        mockDelegate.onDataSynchronized = { syncedData in
            XCTAssertEqual(syncedData.playerId, testGameData.playerId)
            XCTAssertEqual(syncedData.totalGames, testGameData.totalGames)
            XCTAssertEqual(syncedData.wins, testGameData.wins)
            expectation.fulfill()
        }
        
        gameCenterService.authenticatePlayer()
        gameCenterService.syncGameData(testGameData)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testCrossDeviceSync() throws {
        let expectation = XCTestExpectation(description: "Cross-device data sync")
        
        mockDelegate.onCrossDeviceDataReceived = { deviceData in
            XCTAssertNotNil(deviceData)
            XCTAssertGreaterThan(deviceData.keys.count, 0)
            expectation.fulfill()
        }
        
        gameCenterService.authenticatePlayer()
        gameCenterService.requestCrossDeviceData()
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    // MARK: - Performance Tests
    
    func testConcurrentLeaderboardSubmissions() throws {
        let expectation = XCTestExpectation(description: "Concurrent leaderboard submissions")
        expectation.expectedFulfillmentCount = 10
        
        mockDelegate.onLeaderboardSubmissionSuccess = { _, _ in
            expectation.fulfill()
        }
        
        gameCenterService.authenticatePlayer()
        
        // Submit 10 scores concurrently
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            gameCenterService.submitScore(index * 10, to: TestConstants.winsLeaderboardID)
        }
        
        wait(for: [expectation], timeout: 20.0)
    }
    
    func testRapidAchievementUpdates() throws {
        let expectation = XCTestExpectation(description: "Rapid achievement updates")
        expectation.expectedFulfillmentCount = 20
        
        mockDelegate.onAchievementProgressUpdated = { _, _ in
            expectation.fulfill()
        }
        
        gameCenterService.authenticatePlayer()
        
        // Update achievements rapidly
        for i in 1...20 {
            let progress = Double(i) * 5.0 // 5%, 10%, 15%, etc.
            gameCenterService.updateAchievementProgress(TestConstants.win100GamesAchievementID, percentComplete: progress)
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testNetworkErrorHandling() throws {
        let expectation = XCTestExpectation(description: "Network error handled gracefully")
        
        mockDelegate.onNetworkError = { error in
            XCTAssertTrue(error is GameCenterNetworkError)
            expectation.fulfill()
        }
        
        gameCenterService.authenticatePlayer()
        
        // Simulate network error
        gameCenterService.simulateNetworkError()
        gameCenterService.submitScore(100, to: TestConstants.winsLeaderboardID)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testGameCenterUnavailableHandling() throws {
        let expectation = XCTestExpectation(description: "Game Center unavailable handled")
        
        mockDelegate.onGameCenterUnavailable = {
            expectation.fulfill()
        }
        
        gameCenterService.simulateGameCenterUnavailable()
        gameCenterService.authenticatePlayer()
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Integration Flow Tests
    
    func testCompleteGameFlowIntegration() throws {
        let expectation = XCTestExpectation(description: "Complete game flow with Game Center")
        expectation.expectedFulfillmentCount = 4 // Auth + Score + Achievement + Leaderboard
        
        var completedSteps: [String] = []
        
        mockDelegate.onAuthenticationSuccess = {
            completedSteps.append("authentication")
            expectation.fulfill()
        }
        
        mockDelegate.onLeaderboardSubmissionSuccess = { _, _ in
            completedSteps.append("leaderboard")
            expectation.fulfill()
        }
        
        mockDelegate.onAchievementProgressUpdated = { _, _ in
            completedSteps.append("achievement")
            expectation.fulfill()
        }
        
        mockDelegate.onLeaderboardDataReceived = { _, _ in
            completedSteps.append("leaderboard_data")
            expectation.fulfill()
        }
        
        // Simulate complete game flow
        gameCenterService.authenticatePlayer()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Submit game result
            self.gameCenterService.submitScore(1, to: TestConstants.winsLeaderboardID)
            
            // Update achievement
            self.gameCenterService.updateAchievementProgress(TestConstants.firstWinAchievementID, percentComplete: 100.0)
            
            // Load updated leaderboard
            self.gameCenterService.loadLeaderboard(TestConstants.winsLeaderboardID, timeScope: .allTime, range: NSRange(location: 1, length: 5))
        }
        
        wait(for: [expectation], timeout: 20.0)
        
        XCTAssertEqual(completedSteps.count, 4)
        XCTAssertTrue(completedSteps.contains("authentication"))
        XCTAssertTrue(completedSteps.contains("leaderboard"))
        XCTAssertTrue(completedSteps.contains("achievement"))
        XCTAssertTrue(completedSteps.contains("leaderboard_data"))
    }
}

// MARK: - Mock Delegate

class MockGameCenterDelegate: GameCenterServiceDelegate {
    var onAuthenticationSuccess: (() -> Void)?
    var onAuthenticationFailure: ((Error) -> Void)?
    var onLeaderboardSubmissionSuccess: ((String, Int) -> Void)?
    var onLeaderboardDataReceived: ((String, [GKScore]) -> Void)?
    var onAchievementProgressUpdated: ((String, Double) -> Void)?
    var onAchievementCompleted: ((String) -> Void)?
    var onAchievementsLoaded: (([GKAchievement]) -> Void)?
    var onMatchmakingStarted: ((GKMatchRequest) -> Void)?
    var onMatchFound: ((GKMatch) -> Void)?
    var onInviteSent: (([String]) -> Void)?
    var onDataSynchronized: ((GameData) -> Void)?
    var onCrossDeviceDataReceived: (([String: Any]) -> Void)?
    var onNetworkError: ((Error) -> Void)?
    var onGameCenterUnavailable: (() -> Void)?
    
    func gameCenterAuthenticationDidSucceed() {
        onAuthenticationSuccess?()
    }
    
    func gameCenterAuthenticationDidFail(with error: Error) {
        onAuthenticationFailure?(error)
    }
    
    func gameCenterDidSubmitScore(_ score: Int, to leaderboardID: String) {
        onLeaderboardSubmissionSuccess?(leaderboardID, score)
    }
    
    func gameCenterDidLoadLeaderboard(_ leaderboardID: String, scores: [GKScore]) {
        onLeaderboardDataReceived?(leaderboardID, scores)
    }
    
    func gameCenterDidUpdateAchievement(_ achievementID: String, percentComplete: Double) {
        onAchievementProgressUpdated?(achievementID, percentComplete)
        
        if percentComplete >= 100.0 {
            onAchievementCompleted?(achievementID)
        }
    }
    
    func gameCenterDidLoadAchievements(_ achievements: [GKAchievement]) {
        onAchievementsLoaded?(achievements)
    }
    
    func gameCenterDidStartMatchmaking(with request: GKMatchRequest) {
        onMatchmakingStarted?(request)
    }
    
    func gameCenterDidFindMatch(_ match: GKMatch) {
        onMatchFound?(match)
    }
    
    func gameCenterDidSendInvite(to playerIDs: [String]) {
        onInviteSent?(playerIDs)
    }
    
    func gameCenterDidSyncData(_ data: GameData) {
        onDataSynchronized?(data)
    }
    
    func gameCenterDidReceiveCrossDeviceData(_ data: [String: Any]) {
        onCrossDeviceDataReceived?(data)
    }
    
    func gameCenterDidEncounterNetworkError(_ error: Error) {
        onNetworkError?(error)
    }
    
    func gameCenterIsUnavailable() {
        onGameCenterUnavailable?()
    }
}

// MARK: - Mock Classes

class MockGKMatch: GKMatch {
    override var players: [GKPlayer] {
        return [MockGKPlayer(), MockGKPlayer()]
    }
}

class MockGKPlayer: GKPlayer {
    override var displayName: String {
        return "Test Player"
    }
    
    override var playerID: String {
        return "test-player-id"
    }
}

// MARK: - Test Constants

enum TestConstants {
    static let winsLeaderboardID = "com.botanybattle.wins"
    static let streakLeaderboardID = "com.botanybattle.streak"
    static let speedrunLeaderboardID = "com.botanybattle.speedrun"
    
    static let firstWinAchievementID = "com.botanybattle.firstwin"
    static let win10GamesAchievementID = "com.botanybattle.win10games"
    static let win100GamesAchievementID = "com.botanybattle.win100games"
}

// MARK: - Supporting Types

struct GameData {
    let playerId: String
    let totalGames: Int
    let wins: Int
    let currentStreak: Int
    let bestTime: Double
    let trophies: Int
}

enum GameCenterError: Error {
    case authenticationFailed
    case networkUnavailable
    case invalidRequest
}

enum GameCenterNetworkError: Error {
    case connectionLost
    case requestTimeout
    case serverError
}
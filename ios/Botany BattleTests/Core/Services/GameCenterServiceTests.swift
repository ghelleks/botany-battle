import XCTest
import GameKit
@testable import BotanyBattle

final class GameCenterServiceTests: XCTestCase {
    
    var sut: GameCenterService!
    var mockLocalPlayer: MockGKLocalPlayer!
    
    override func setUp() {
        super.setUp()
        mockLocalPlayer = MockGKLocalPlayer()
        sut = GameCenterService()
        sut.localPlayer = mockLocalPlayer
    }
    
    override func tearDown() {
        sut = nil
        mockLocalPlayer = nil
        super.tearDown()
    }
    
    // MARK: - Authentication Tests
    
    func testAuthenticate_WhenPlayerIsAlreadyAuthenticated_CompletesSuccessfully() async {
        // Given
        mockLocalPlayer.isAuthenticated = true
        
        // When
        let result = await sut.authenticate()
        
        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(sut.isAuthenticated)
    }
    
    func testAuthenticate_WhenPlayerIsNotAuthenticated_AttemptsAuthentication() async {
        // Given
        mockLocalPlayer.isAuthenticated = false
        mockLocalPlayer.shouldSucceedAuthentication = true
        
        // When
        let result = await sut.authenticate()
        
        // Then
        XCTAssertTrue(result)
        XCTAssertTrue(mockLocalPlayer.authenticateHandlerCalled)
    }
    
    func testAuthenticate_WhenAuthenticationFails_ReturnsFalse() async {
        // Given
        mockLocalPlayer.isAuthenticated = false
        mockLocalPlayer.shouldSucceedAuthentication = false
        mockLocalPlayer.authenticationError = NSError(domain: "GameKitErrorDomain", code: 1, userInfo: nil)
        
        // When
        let result = await sut.authenticate()
        
        // Then
        XCTAssertFalse(result)
        XCTAssertFalse(sut.isAuthenticated)
    }
    
    // MARK: - Leaderboard Tests
    
    func testSubmitScore_WhenAuthenticated_SubmitsSuccessfully() async {
        // Given
        mockLocalPlayer.isAuthenticated = true
        let score = 100
        
        // When
        let result = await sut.submitScore(score, category: .practice)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockLocalPlayer.submittedScores.count, 1)
        XCTAssertEqual(mockLocalPlayer.submittedScores.first?.value, 100)
    }
    
    func testSubmitScore_WhenNotAuthenticated_ReturnsFalse() async {
        // Given
        mockLocalPlayer.isAuthenticated = false
        let score = 100
        
        // When
        let result = await sut.submitScore(score, category: .practice)
        
        // Then
        XCTAssertFalse(result)
        XCTAssertTrue(mockLocalPlayer.submittedScores.isEmpty)
    }
    
    func testSubmitScore_WithNegativeScore_ReturnsFalse() async {
        // Given
        mockLocalPlayer.isAuthenticated = true
        let score = -10
        
        // When
        let result = await sut.submitScore(score, category: .practice)
        
        // Then
        XCTAssertFalse(result)
        XCTAssertTrue(mockLocalPlayer.submittedScores.isEmpty)
    }
    
    // MARK: - Achievement Tests
    
    func testReportAchievement_WhenAuthenticated_ReportsSuccessfully() async {
        // Given
        mockLocalPlayer.isAuthenticated = true
        let achievementID = GameConstants.GameCenter.Achievements.firstWin
        
        // When
        let result = await sut.reportAchievement(achievementID, percentComplete: 100.0)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockLocalPlayer.reportedAchievements.count, 1)
        XCTAssertEqual(mockLocalPlayer.reportedAchievements.first?.identifier, achievementID)
        XCTAssertEqual(mockLocalPlayer.reportedAchievements.first?.percentComplete, 100.0)
    }
    
    func testReportAchievement_WhenNotAuthenticated_ReturnsFalse() async {
        // Given
        mockLocalPlayer.isAuthenticated = false
        let achievementID = GameConstants.GameCenter.Achievements.firstWin
        
        // When
        let result = await sut.reportAchievement(achievementID, percentComplete: 100.0)
        
        // Then
        XCTAssertFalse(result)
        XCTAssertTrue(mockLocalPlayer.reportedAchievements.isEmpty)
    }
    
    func testReportAchievement_WithInvalidPercentage_ReturnsFalse() async {
        // Given
        mockLocalPlayer.isAuthenticated = true
        let achievementID = GameConstants.GameCenter.Achievements.firstWin
        
        // When
        let result = await sut.reportAchievement(achievementID, percentComplete: -10.0)
        
        // Then
        XCTAssertFalse(result)
        XCTAssertTrue(mockLocalPlayer.reportedAchievements.isEmpty)
    }
    
    // MARK: - Player Information Tests
    
    func testPlayerDisplayName_WhenAuthenticated_ReturnsDisplayName() {
        // Given
        mockLocalPlayer.isAuthenticated = true
        mockLocalPlayer.displayName = "TestPlayer"
        
        // When
        let displayName = sut.playerDisplayName
        
        // Then
        XCTAssertEqual(displayName, "TestPlayer")
    }
    
    func testPlayerDisplayName_WhenNotAuthenticated_ReturnsNil() {
        // Given
        mockLocalPlayer.isAuthenticated = false
        
        // When
        let displayName = sut.playerDisplayName
        
        // Then
        XCTAssertNil(displayName)
    }
    
    // MARK: - Challenge Tests
    
    func testSendChallenge_WhenAuthenticated_SendsSuccessfully() async {
        // Given
        mockLocalPlayer.isAuthenticated = true
        let friendPlayerID = "friend123"
        let message = "Challenge me!"
        
        // When
        let result = await sut.sendChallenge(to: friendPlayerID, message: message)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockLocalPlayer.sentChallenges.count, 1)
        XCTAssertEqual(mockLocalPlayer.sentChallenges.first?.playerID, friendPlayerID)
        XCTAssertEqual(mockLocalPlayer.sentChallenges.first?.message, message)
    }
    
    func testSendChallenge_WhenNotAuthenticated_ReturnsFalse() async {
        // Given
        mockLocalPlayer.isAuthenticated = false
        let friendPlayerID = "friend123"
        let message = "Challenge me!"
        
        // When
        let result = await sut.sendChallenge(to: friendPlayerID, message: message)
        
        // Then
        XCTAssertFalse(result)
        XCTAssertTrue(mockLocalPlayer.sentChallenges.isEmpty)
    }
    
    // MARK: - Error Handling Tests
    
    func testAuthenticate_WithConnectionError_HandlesGracefully() async {
        // Given
        mockLocalPlayer.isAuthenticated = false
        mockLocalPlayer.shouldSucceedAuthentication = false
        mockLocalPlayer.authenticationError = NSError(
            domain: GKErrorDomain,
            code: GKError.notConnectedToInternet.rawValue,
            userInfo: nil
        )
        
        // When
        let result = await sut.authenticate()
        
        // Then
        XCTAssertFalse(result)
        XCTAssertFalse(sut.isAuthenticated)
    }
    
    // MARK: - State Management Tests
    
    func testAuthenticationState_InitiallyFalse() {
        // Given & When & Then
        XCTAssertFalse(sut.isAuthenticated)
    }
    
    func testAuthenticationState_UpdatesAfterSuccessfulAuth() async {
        // Given
        mockLocalPlayer.isAuthenticated = false
        mockLocalPlayer.shouldSucceedAuthentication = true
        
        // When
        _ = await sut.authenticate()
        
        // Then
        XCTAssertTrue(sut.isAuthenticated)
    }
    
    // MARK: - Performance Tests
    
    func testAuthentication_Performance() {
        measure {
            let expectation = XCTestExpectation(description: "Authentication performance")
            
            Task {
                _ = await sut.authenticate()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentScoreSubmissions_HandleSafely() async {
        // Given
        mockLocalPlayer.isAuthenticated = true
        
        // When
        async let result1 = sut.submitScore(100, category: .practice)
        async let result2 = sut.submitScore(200, category: .speedrun)
        async let result3 = sut.submitScore(300, category: .timeAttack)
        
        let results = await [result1, result2, result3]
        
        // Then
        XCTAssertTrue(results.allSatisfy { $0 })
        XCTAssertEqual(mockLocalPlayer.submittedScores.count, 3)
    }
}

// MARK: - Mock Objects

class MockGKLocalPlayer: GKLocalPlayerProtocol {
    var isAuthenticated: Bool = false
    var displayName: String?
    var playerID: String = "mockPlayer123"
    
    var authenticateHandlerCalled = false
    var shouldSucceedAuthentication = true
    var authenticationError: Error?
    
    var submittedScores: [MockGKScore] = []
    var reportedAchievements: [MockGKAchievement] = []
    var sentChallenges: [MockChallenge] = []
    
    var authenticateHandler: ((UIViewController?, Error?) -> Void)?
    
    func authenticate(completion: @escaping (Error?) -> Void) {
        authenticateHandlerCalled = true
        
        if shouldSucceedAuthentication {
            isAuthenticated = true
            completion(nil)
        } else {
            completion(authenticationError)
        }
    }
    
    func submitScore(_ score: MockGKScore, completion: @escaping (Error?) -> Void) {
        if isAuthenticated {
            submittedScores.append(score)
            completion(nil)
        } else {
            completion(NSError(domain: "NotAuthenticated", code: 1, userInfo: nil))
        }
    }
    
    func reportAchievement(_ achievement: MockGKAchievement, completion: @escaping (Error?) -> Void) {
        if isAuthenticated {
            reportedAchievements.append(achievement)
            completion(nil)
        } else {
            completion(NSError(domain: "NotAuthenticated", code: 1, userInfo: nil))
        }
    }
    
    func sendChallenge(playerID: String, message: String, completion: @escaping (Error?) -> Void) {
        if isAuthenticated {
            sentChallenges.append(MockChallenge(playerID: playerID, message: message))
            completion(nil)
        } else {
            completion(NSError(domain: "NotAuthenticated", code: 1, userInfo: nil))
        }
    }
}

protocol GKLocalPlayerProtocol {
    var isAuthenticated: Bool { get }
    var displayName: String? { get }
    var playerID: String { get }
    
    func authenticate(completion: @escaping (Error?) -> Void)
    func submitScore(_ score: MockGKScore, completion: @escaping (Error?) -> Void)
    func reportAchievement(_ achievement: MockGKAchievement, completion: @escaping (Error?) -> Void)
    func sendChallenge(playerID: String, message: String, completion: @escaping (Error?) -> Void)
}

struct MockGKScore {
    let value: Int64
    let leaderboardID: String
}

struct MockGKAchievement {
    let identifier: String
    let percentComplete: Double
}

struct MockChallenge {
    let playerID: String
    let message: String
}
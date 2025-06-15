import XCTest
import GameKit
@testable import BotanyBattle

final class GameCenterServiceTests: XCTestCase {
    var sut: GameCenterService!
    var mockGameCenterService: MockGameCenterService!
    
    override func setUp() {
        super.setUp()
        sut = GameCenterService()
        mockGameCenterService = MockGameCenterService()
    }
    
    override func tearDown() {
        sut = nil
        mockGameCenterService = nil
        super.tearDown()
    }
    
    // MARK: - Authentication Tests
    
    func testAuthenticatePlayer_WhenGameCenterAvailable_ShouldReturnUser() async throws {
        // Given
        mockGameCenterService.isMultiplayerSupported = true
        mockGameCenterService.shouldAuthenticateSuccessfully = true
        mockGameCenterService.mockPlayer = createMockPlayer()
        
        // When
        let user = try await mockGameCenterService.authenticatePlayer()
        
        // Then
        XCTAssertEqual(user.id, "G:123456789")
        XCTAssertEqual(user.username, "TestPlayer")
        XCTAssertEqual(user.displayName, "Test Player Display")
        XCTAssertNil(user.email) // Game Center doesn't provide email
        XCTAssertEqual(user.stats.eloRating, 1000) // Default rating
    }
    
    func testAuthenticatePlayer_WhenGameCenterNotSupported_ShouldThrowError() async {
        // Given
        mockGameCenterService.isMultiplayerSupported = false
        
        // When/Then
        await XCTAssertThrowsError(try await mockGameCenterService.authenticatePlayer()) { error in
            XCTAssertEqual(error as? GameCenterError, .notSupported)
        }
    }
    
    func testAuthenticatePlayer_WhenAuthenticationFails_ShouldThrowError() async {
        // Given
        mockGameCenterService.isMultiplayerSupported = true
        mockGameCenterService.shouldAuthenticateSuccessfully = false
        mockGameCenterService.authenticationError = NSError(domain: "GameKit", code: -1, userInfo: nil)
        
        // When/Then
        await XCTAssertThrowsError(try await mockGameCenterService.authenticatePlayer()) { error in
            if case .authenticationFailed(let underlyingError) = error as? GameCenterError {
                XCTAssertNotNil(underlyingError)
            } else {
                XCTFail("Expected authenticationFailed error")
            }
        }
    }
    
    func testIsAuthenticated_WhenPlayerAuthenticated_ShouldReturnTrue() {
        // Given
        mockGameCenterService.isPlayerAuthenticated = true
        
        // When
        let isAuthenticated = mockGameCenterService.isAuthenticated()
        
        // Then
        XCTAssertTrue(isAuthenticated)
    }
    
    func testIsAuthenticated_WhenPlayerNotAuthenticated_ShouldReturnFalse() {
        // Given
        mockGameCenterService.isPlayerAuthenticated = false
        
        // When
        let isAuthenticated = mockGameCenterService.isAuthenticated()
        
        // Then
        XCTAssertFalse(isAuthenticated)
    }
    
    // MARK: - Token Generation Tests
    
    func testGetAuthenticationToken_WhenAuthenticated_ShouldReturnValidToken() async throws {
        // Given
        mockGameCenterService.isPlayerAuthenticated = true
        mockGameCenterService.mockPlayer = createMockPlayer()
        mockGameCenterService.mockSignature = Data("test_signature".utf8)
        mockGameCenterService.mockSalt = Data("test_salt".utf8)
        mockGameCenterService.mockTimestamp = UInt64(Date().timeIntervalSince1970)
        
        // When
        let token = try await mockGameCenterService.getAuthenticationToken()
        
        // Then
        XCTAssertFalse(token.isEmpty)
        
        // Decode and verify token structure
        let tokenData = Data(base64Encoded: token)
        XCTAssertNotNil(tokenData)
        
        let decodedToken = try JSONSerialization.jsonObject(with: tokenData!) as? [String: Any]
        XCTAssertNotNil(decodedToken)
        XCTAssertEqual(decodedToken?["playerId"] as? String, "G:123456789")
        XCTAssertEqual(decodedToken?["bundleId"] as? String, Bundle.main.bundleIdentifier)
        XCTAssertNotNil(decodedToken?["signature"])
        XCTAssertNotNil(decodedToken?["salt"])
        XCTAssertNotNil(decodedToken?["timestamp"])
    }
    
    func testGetAuthenticationToken_WhenNotAuthenticated_ShouldThrowError() async {
        // Given
        mockGameCenterService.isPlayerAuthenticated = false
        
        // When/Then
        await XCTAssertThrowsError(try await mockGameCenterService.getAuthenticationToken()) { error in
            XCTAssertEqual(error as? GameCenterError, .notAuthenticated)
        }
    }
    
    func testGetAuthenticationToken_WhenSignatureGenerationFails_ShouldThrowError() async {
        // Given
        mockGameCenterService.isPlayerAuthenticated = true
        mockGameCenterService.signatureGenerationError = NSError(domain: "GameKit", code: -2, userInfo: nil)
        
        // When/Then
        await XCTAssertThrowsError(try await mockGameCenterService.getAuthenticationToken()) { error in
            if case .tokenGenerationFailed(let underlyingError) = error as? GameCenterError {
                XCTAssertNotNil(underlyingError)
            } else {
                XCTFail("Expected tokenGenerationFailed error")
            }
        }
    }
    
    // MARK: - User Management Tests
    
    func testGetCurrentUser_WhenAuthenticated_ShouldReturnUser() async throws {
        // Given
        mockGameCenterService.isPlayerAuthenticated = true
        mockGameCenterService.mockPlayer = createMockPlayer()
        
        // When
        let user = try await mockGameCenterService.getCurrentUser()
        
        // Then
        XCTAssertEqual(user.id, "G:123456789")
        XCTAssertEqual(user.username, "TestPlayer")
        XCTAssertEqual(user.displayName, "Test Player Display")
        XCTAssertEqual(user.stats.totalGamesPlayed, 0)
        XCTAssertEqual(user.stats.eloRating, 1000)
        XCTAssertEqual(user.currency.coins, 100)
    }
    
    func testGetCurrentUser_WhenNotAuthenticated_ShouldThrowError() async {
        // Given
        mockGameCenterService.isPlayerAuthenticated = false
        
        // When/Then
        await XCTAssertThrowsError(try await mockGameCenterService.getCurrentUser()) { error in
            XCTAssertEqual(error as? GameCenterError, .notAuthenticated)
        }
    }
    
    func testSignOut_ShouldClearCurrentUser() async throws {
        // Given
        mockGameCenterService.isPlayerAuthenticated = true
        
        // When
        try await mockGameCenterService.signOut()
        
        // Then
        XCTAssertTrue(mockGameCenterService.signOutCalled)
    }
    
    // MARK: - Helper Methods
    
    private func createMockPlayer() -> MockGKLocalPlayer {
        let player = MockGKLocalPlayer()
        player.gamePlayerID = "G:123456789"
        player.alias = "TestPlayer"
        player.displayName = "Test Player Display"
        player.isAuthenticated = true
        return player
    }
}

// MARK: - Mock Classes

class MockGameCenterService: GameCenterServiceProtocol {
    var isMultiplayerSupported = true
    var shouldAuthenticateSuccessfully = true
    var isPlayerAuthenticated = false
    var authenticationError: Error?
    var signatureGenerationError: Error?
    var mockPlayer: MockGKLocalPlayer?
    var mockSignature: Data?
    var mockSalt: Data?
    var mockTimestamp: UInt64 = 0
    var signOutCalled = false
    
    func authenticatePlayer() async throws -> User {
        if !isMultiplayerSupported {
            throw GameCenterError.notSupported
        }
        
        if let error = authenticationError {
            throw GameCenterError.authenticationFailed(error)
        }
        
        if !shouldAuthenticateSuccessfully {
            throw GameCenterError.authenticationFailed(NSError(domain: "Test", code: -1))
        }
        
        guard let player = mockPlayer else {
            throw GameCenterError.notAuthenticated
        }
        
        isPlayerAuthenticated = true
        return createUserFromPlayer(player)
    }
    
    func signOut() async throws {
        signOutCalled = true
        isPlayerAuthenticated = false
    }
    
    func getCurrentUser() async throws -> User {
        guard isPlayerAuthenticated, let player = mockPlayer else {
            throw GameCenterError.notAuthenticated
        }
        
        return createUserFromPlayer(player)
    }
    
    func isAuthenticated() -> Bool {
        return isPlayerAuthenticated
    }
    
    func getAuthenticationToken() async throws -> String {
        guard isPlayerAuthenticated else {
            throw GameCenterError.notAuthenticated
        }
        
        if let error = signatureGenerationError {
            throw GameCenterError.tokenGenerationFailed(error)
        }
        
        guard let player = mockPlayer,
              let signature = mockSignature,
              let salt = mockSalt else {
            throw GameCenterError.tokenGenerationFailed(NSError(domain: "Test", code: -1))
        }
        
        let tokenData = [
            "playerId": player.gamePlayerID,
            "signature": signature.base64EncodedString(),
            "salt": salt.base64EncodedString(),
            "timestamp": String(mockTimestamp),
            "bundleId": Bundle.main.bundleIdentifier ?? ""
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: tokenData)
        return jsonData.base64EncodedString()
    }
    
    private func createUserFromPlayer(_ player: MockGKLocalPlayer) -> User {
        return User(
            id: player.gamePlayerID,
            username: player.alias,
            email: nil,
            displayName: player.displayName,
            avatarURL: nil,
            createdAt: Date(),
            stats: User.UserStats(
                totalGamesPlayed: 0,
                totalWins: 0,
                currentStreak: 0,
                longestStreak: 0,
                eloRating: 1000,
                rank: "Seedling",
                plantsIdentified: 0,
                accuracyRate: 0.0
            ),
            currency: User.Currency(coins: 100, gems: 0, tokens: 0)
        )
    }
}

class MockGKLocalPlayer {
    var gamePlayerID: String = ""
    var alias: String = ""
    var displayName: String = ""
    var isAuthenticated: Bool = false
}

// MARK: - Performance Tests

extension GameCenterServiceTests {
    func testAuthenticationPerformance() throws {
        mockGameCenterService.isMultiplayerSupported = true
        mockGameCenterService.shouldAuthenticateSuccessfully = true
        mockGameCenterService.mockPlayer = createMockPlayer()
        
        measure {
            let expectation = XCTestExpectation(description: "Authentication performance")
            
            Task {
                do {
                    _ = try await mockGameCenterService.authenticatePlayer()
                    expectation.fulfill()
                } catch {
                    XCTFail("Authentication failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    func testTokenGenerationPerformance() throws {
        mockGameCenterService.isPlayerAuthenticated = true
        mockGameCenterService.mockPlayer = createMockPlayer()
        mockGameCenterService.mockSignature = Data("test_signature".utf8)
        mockGameCenterService.mockSalt = Data("test_salt".utf8)
        mockGameCenterService.mockTimestamp = UInt64(Date().timeIntervalSince1970)
        
        measure {
            let expectation = XCTestExpectation(description: "Token generation performance")
            
            Task {
                do {
                    _ = try await mockGameCenterService.getAuthenticationToken()
                    expectation.fulfill()
                } catch {
                    XCTFail("Token generation failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
}
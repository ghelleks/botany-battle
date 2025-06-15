import XCTest
import GameKit
@testable import BotanyBattle

final class GameCenterIntegrationTests: XCTestCase {
    var authFeature: AuthFeature!
    var gameFeature: GameFeature!
    var mockGameCenterService: MockGameCenterService!
    var mockNetworkService: MockNetworkService!
    var mockMatchmakingService: MockGameCenterMatchmakingService!
    
    override func setUp() {
        super.setUp()
        
        mockGameCenterService = MockGameCenterService()
        mockNetworkService = MockNetworkService()
        mockMatchmakingService = MockGameCenterMatchmakingService()
        
        // Set up dependency overrides for testing
        let testStore = TestStore(
            initialState: AuthFeature.State(),
            reducer: { AuthFeature() }
        )
        
        authFeature = AuthFeature()
    }
    
    override func tearDown() {
        authFeature = nil
        gameFeature = nil
        mockGameCenterService = nil
        mockNetworkService = nil
        mockMatchmakingService = nil
        super.tearDown()
    }
    
    // MARK: - End-to-End Authentication Flow Tests
    
    func testCompleteAuthenticationFlow_Success() async throws {
        // Given
        mockGameCenterService.isMultiplayerSupported = true
        mockGameCenterService.shouldAuthenticateSuccessfully = true
        mockGameCenterService.mockPlayer = createMockPlayer()
        mockNetworkService.shouldSucceed = true
        
        let store = TestStore(
            initialState: AuthFeature.State(),
            reducer: { AuthFeature() }
        ) {
            $0.gameCenterService = mockGameCenterService
        }
        
        // When
        await store.send(.authenticateWithGameCenter) {
            $0.isLoading = true
            $0.error = nil
        }
        
        // Then
        await store.receive(.loginSuccess) {
            $0.isLoading = false
            $0.isAuthenticated = true
            $0.currentUser = self.createExpectedUser()
            $0.error = nil
            $0.showingGameCenterLogin = false
        }
    }
    
    func testCompleteAuthenticationFlow_GameCenterNotSupported() async throws {
        // Given
        mockGameCenterService.isMultiplayerSupported = false
        
        let store = TestStore(
            initialState: AuthFeature.State(),
            reducer: { AuthFeature() }
        ) {
            $0.gameCenterService = mockGameCenterService
        }
        
        // When
        await store.send(.authenticateWithGameCenter) {
            $0.isLoading = true
            $0.error = nil
        }
        
        // Then
        await store.receive(.authError) {
            $0.isLoading = false
            $0.error = "Game Center is not supported on this device."
        }
    }
    
    func testCompleteAuthenticationFlow_AuthenticationFailed() async throws {
        // Given
        mockGameCenterService.isMultiplayerSupported = true
        mockGameCenterService.shouldAuthenticateSuccessfully = false
        mockGameCenterService.authenticationError = NSError(domain: "GameKit", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Authentication failed"
        ])
        
        let store = TestStore(
            initialState: AuthFeature.State(),
            reducer: { AuthFeature() }
        ) {
            $0.gameCenterService = mockGameCenterService
        }
        
        // When
        await store.send(.authenticateWithGameCenter) {
            $0.isLoading = true
            $0.error = nil
        }
        
        // Then
        await store.receive(.authError) {
            $0.isLoading = false
            $0.error = "Game Center authentication failed: Authentication failed"
        }
    }
    
    // MARK: - Matchmaking Integration Tests
    
    func testCompleteMatchmakingFlow_Success() async throws {
        // Given
        mockGameCenterService.isPlayerAuthenticated = true
        mockGameCenterService.mockPlayer = createMockPlayer()
        mockMatchmakingService.shouldFindMatchSuccessfully = true
        mockMatchmakingService.mockGame = createMockGame()
        
        // When
        let game = try await mockMatchmakingService.findMatch(for: .medium)
        
        // Then
        XCTAssertEqual(game.id, "test-game-123")
        XCTAssertEqual(game.difficulty, .medium)
        XCTAssertEqual(game.players.count, 2)
        XCTAssertTrue(mockMatchmakingService.findMatchCalled)
    }
    
    func testCompleteMatchmakingFlow_NotAuthenticated() async throws {
        // Given
        mockGameCenterService.isPlayerAuthenticated = false
        
        // When/Then
        await XCTAssertThrowsError(
            try await mockMatchmakingService.findMatch(for: .medium)
        ) { error in
            XCTAssertEqual(error as? GameCenterMatchmakingError, .notAuthenticated)
        }
    }
    
    func testCompleteMatchmakingFlow_Timeout() async throws {
        // Given
        mockGameCenterService.isPlayerAuthenticated = true
        mockGameCenterService.mockPlayer = createMockPlayer()
        mockMatchmakingService.shouldTimeout = true
        
        // When/Then
        await XCTAssertThrowsError(
            try await mockMatchmakingService.findMatch(for: .medium)
        ) { error in
            XCTAssertEqual(error as? GameCenterMatchmakingError, .matchmakingTimeout)
        }
    }
    
    // MARK: - Friend Invitation Tests
    
    func testInviteFriend_Success() async throws {
        // Given
        mockGameCenterService.isPlayerAuthenticated = true
        mockGameCenterService.mockPlayer = createMockPlayer()
        mockMatchmakingService.shouldInviteSuccessfully = true
        mockMatchmakingService.mockGame = createMockGame()
        
        let friendPlayerId = "G:987654321"
        
        // When
        let game = try await mockMatchmakingService.inviteFriend(friendPlayerId, difficulty: .hard)
        
        // Then
        XCTAssertEqual(game.id, "test-game-123")
        XCTAssertEqual(game.difficulty, .hard)
        XCTAssertTrue(mockMatchmakingService.inviteFriendCalled)
        XCTAssertEqual(mockMatchmakingService.lastInvitedPlayerId, friendPlayerId)
    }
    
    func testAcceptInvitation_Success() async throws {
        // Given
        mockGameCenterService.isPlayerAuthenticated = true
        mockGameCenterService.mockPlayer = createMockPlayer()
        mockMatchmakingService.shouldAcceptInvitationSuccessfully = true
        mockMatchmakingService.mockGame = createMockGame()
        
        let invitation = GameCenterInvitation(
            gameId: "test-game-123",
            fromPlayer: "G:987654321",
            difficulty: .easy,
            expiresAt: Date().addingTimeInterval(300)
        )
        
        // When
        let game = try await mockMatchmakingService.acceptInvitation(invitation)
        
        // Then
        XCTAssertEqual(game.id, "test-game-123")
        XCTAssertTrue(mockMatchmakingService.acceptInvitationCalled)
    }
    
    // MARK: - Network Integration Tests
    
    func testNetworkAuthentication_WithGameCenterToken() async throws {
        // Given
        mockGameCenterService.isPlayerAuthenticated = true
        mockGameCenterService.mockPlayer = createMockPlayer()
        mockGameCenterService.mockSignature = Data("test_signature".utf8)
        mockGameCenterService.mockSalt = Data("test_salt".utf8)
        mockGameCenterService.mockTimestamp = UInt64(Date().timeIntervalSince1970)
        
        mockNetworkService.expectedAuthHeader = "GameCenter"
        mockNetworkService.expectedEndpoint = "/auth/gamecenter"
        mockNetworkService.shouldSucceed = true
        
        // When
        let token = try await mockGameCenterService.getAuthenticationToken()
        
        let response: AuthResponse = try await mockNetworkService.request(
            .auth(.gamecenter),
            method: .post,
            parameters: ["token": token],
            headers: ["Authorization": "GameCenter \(token)"]
        )
        
        // Then
        XCTAssertTrue(response.authenticated)
        XCTAssertNotNil(response.user)
        XCTAssertTrue(mockNetworkService.requestCalled)
    }
    
    // MARK: - Error Recovery Tests
    
    func testAuthenticationRecovery_AfterNetworkError() async throws {
        // Given
        mockGameCenterService.isPlayerAuthenticated = true
        mockGameCenterService.mockPlayer = createMockPlayer()
        mockNetworkService.shouldSucceed = false
        mockNetworkService.error = NetworkError.requestFailed(AFError.sessionTaskFailed(error: URLError(.networkConnectionLost)))
        
        let store = TestStore(
            initialState: AuthFeature.State(),
            reducer: { AuthFeature() }
        ) {
            $0.gameCenterService = mockGameCenterService
        }
        
        // When - First attempt fails
        await store.send(.authenticateWithGameCenter) {
            $0.isLoading = true
            $0.error = nil
        }
        
        await store.receive(.authError) {
            $0.isLoading = false
            $0.error = "Request failed: sessionTaskFailed(error: Error Domain=NSURLErrorDomain Code=-1009 \"The Internet connection appears to be offline.\" UserInfo={_kCFStreamErrorCodeKey=-2096, NSUnderlyingError=0x600000c4a150 {Error Domain=kCFErrorDomainCFNetwork Code=-2096 \"(null)\"}, _kCFStreamErrorDomainKey=4, NSErrorFailingURLStringKey=https://api.botanybattle.com/v1/auth/gamecenter, NSErrorFailingURLKey=https://api.botanybattle.com/v1/auth/gamecenter, NSLocalizedDescription=The Internet connection appears to be offline.})"
        }
        
        // When - Network recovers and retry succeeds
        mockNetworkService.shouldSucceed = true
        mockNetworkService.error = nil
        
        await store.send(.clearError) {
            $0.error = nil
        }
        
        await store.send(.authenticateWithGameCenter) {
            $0.isLoading = true
            $0.error = nil
        }
        
        // Then
        await store.receive(.loginSuccess) {
            $0.isLoading = false
            $0.isAuthenticated = true
            $0.currentUser = self.createExpectedUser()
            $0.error = nil
            $0.showingGameCenterLogin = false
        }
    }
    
    // MARK: - Performance Integration Tests
    
    func testFullAuthenticationAndMatchmakingPerformance() throws {
        // Given
        mockGameCenterService.isMultiplayerSupported = true
        mockGameCenterService.shouldAuthenticateSuccessfully = true
        mockGameCenterService.mockPlayer = createMockPlayer()
        mockMatchmakingService.shouldFindMatchSuccessfully = true
        mockMatchmakingService.mockGame = createMockGame()
        
        // When/Then
        measure {
            let expectation = XCTestExpectation(description: "Full flow performance")
            
            Task {
                do {
                    // Authenticate
                    _ = try await mockGameCenterService.authenticatePlayer()
                    
                    // Find match
                    _ = try await mockMatchmakingService.findMatch(for: .medium)
                    
                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
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
    
    private func createExpectedUser() -> User {
        return User(
            id: "G:123456789",
            username: "TestPlayer",
            email: nil,
            displayName: "Test Player Display",
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
    
    private func createMockGame() -> Game {
        return Game(
            id: "test-game-123",
            players: [
                Game.Player(id: "G:123456789", username: "TestPlayer"),
                Game.Player(id: "G:987654321", username: "OpponentPlayer")
            ],
            difficulty: .medium,
            status: .waiting,
            currentRound: 0,
            totalRounds: 5,
            scores: [:],
            createdAt: Date(),
            rounds: []
        )
    }
}

// MARK: - Mock Network Service

class MockNetworkService: NetworkServiceProtocol {
    var shouldSucceed = true
    var error: Error?
    var requestCalled = false
    var expectedEndpoint: String?
    var expectedAuthHeader: String?
    
    func request<T: Codable>(
        _ endpoint: APIEndpoint,
        method: HTTPMethod,
        parameters: [String: Any]?,
        headers: HTTPHeaders?
    ) async throws -> T {
        requestCalled = true
        
        if let expectedEndpoint = expectedEndpoint {
            XCTAssertEqual(endpoint.path, expectedEndpoint)
        }
        
        if let expectedAuthHeader = expectedAuthHeader {
            XCTAssertTrue(headers?.contains { $0.name == "Authorization" && $0.value.contains(expectedAuthHeader) } ?? false)
        }
        
        if !shouldSucceed, let error = error {
            throw error
        }
        
        // Return mock responses based on endpoint
        switch endpoint {
        case .auth(.gamecenter):
            let response = AuthResponse(
                authenticated: true,
                user: createMockUser()
            )
            return response as! T
            
        default:
            throw NetworkError.invalidResponse
        }
    }
    
    func request(
        _ endpoint: APIEndpoint,
        method: HTTPMethod,
        parameters: [String: Any]?,
        headers: HTTPHeaders?
    ) async throws {
        requestCalled = true
        
        if !shouldSucceed, let error = error {
            throw error
        }
    }
    
    func upload<T: Codable>(
        _ endpoint: APIEndpoint,
        data: Data,
        filename: String,
        mimeType: String
    ) async throws -> T {
        if !shouldSucceed, let error = error {
            throw error
        }
        
        throw NetworkError.invalidResponse
    }
    
    private func createMockUser() -> User {
        return User(
            id: "G:123456789",
            username: "TestPlayer",
            email: nil,
            displayName: "Test Player Display",
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

// MARK: - Mock Matchmaking Service

class MockGameCenterMatchmakingService: GameCenterMatchmakingServiceProtocol {
    var shouldFindMatchSuccessfully = true
    var shouldInviteSuccessfully = true
    var shouldAcceptInvitationSuccessfully = true
    var shouldTimeout = false
    var mockGame: Game?
    
    var findMatchCalled = false
    var inviteFriendCalled = false
    var acceptInvitationCalled = false
    var lastInvitedPlayerId: String?
    
    func findMatch(for difficulty: Game.Difficulty) async throws -> Game {
        findMatchCalled = true
        
        if shouldTimeout {
            throw GameCenterMatchmakingError.matchmakingTimeout
        }
        
        if !shouldFindMatchSuccessfully {
            throw GameCenterMatchmakingError.networkError(NSError(domain: "Test", code: -1))
        }
        
        guard let game = mockGame else {
            throw GameCenterMatchmakingError.networkError(NSError(domain: "Test", code: -2))
        }
        
        return game
    }
    
    func inviteFriend(_ playerId: String, difficulty: Game.Difficulty) async throws -> Game {
        inviteFriendCalled = true
        lastInvitedPlayerId = playerId
        
        if !shouldInviteSuccessfully {
            throw GameCenterMatchmakingError.playerNotFound
        }
        
        guard let game = mockGame else {
            throw GameCenterMatchmakingError.networkError(NSError(domain: "Test", code: -3))
        }
        
        return game
    }
    
    func acceptInvitation(_ invitation: GameCenterInvitation) async throws -> Game {
        acceptInvitationCalled = true
        
        if !shouldAcceptInvitationSuccessfully {
            throw GameCenterMatchmakingError.invalidInvitation
        }
        
        guard let game = mockGame else {
            throw GameCenterMatchmakingError.networkError(NSError(domain: "Test", code: -4))
        }
        
        return game
    }
    
    func cancelMatchmaking() async throws {
        // Mock implementation
    }
}

// MARK: - Supporting Types

struct AuthResponse: Codable {
    let authenticated: Bool
    let user: User
}
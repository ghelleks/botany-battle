import XCTest
import GameKit
@testable import BotanyBattle

final class MultiplayerIntegrationTests: XCTestCase {
    
    var gameService: GameService!
    var player1: MockPlayer!
    var player2: MockPlayer!
    var mockBackend: MockBackendService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        mockBackend = MockBackendService()
        gameService = GameService(backend: mockBackend)
        
        player1 = MockPlayer(id: "player1", username: "TestPlayer1", rating: 1200)
        player2 = MockPlayer(id: "player2", username: "TestPlayer2", rating: 1250)
        
        // Setup test environment
        setupTestEnvironment()
    }
    
    override func tearDownWithError() throws {
        gameService = nil
        player1 = nil
        player2 = nil
        mockBackend = nil
        try super.tearDownWithError()
    }
    
    private func setupTestEnvironment() {
        // Configure mock backend with test data
        mockBackend.setupTestPlants()
        mockBackend.setupTestMatchmaking()
    }
    
    // MARK: - End-to-End Game Flow Tests
    
    func testCompleteGameFlow() throws {
        let gameCompletedExpectation = XCTestExpectation(description: "Complete game flow")
        
        var gameResults: GameResult?
        
        // Start matchmaking for both players
        let matchmakingExpectation = XCTestExpectation(description: "Players matched")
        matchmakingExpectation.expectedFulfillmentCount = 2
        
        player1.onMatchFound = { match in
            matchmakingExpectation.fulfill()
        }
        
        player2.onMatchFound = { match in
            matchmakingExpectation.fulfill()
        }
        
        // Enter matchmaking queue
        gameService.startMatchmaking(for: player1)
        gameService.startMatchmaking(for: player2)
        
        wait(for: [matchmakingExpectation], timeout: 10.0)
        
        // Verify match was created
        XCTAssertNotNil(player1.currentMatch)
        XCTAssertNotNil(player2.currentMatch)
        XCTAssertEqual(player1.currentMatch?.gameId, player2.currentMatch?.gameId)
        
        // Play complete game (5 rounds)
        let gameId = player1.currentMatch!.gameId
        var currentRound = 1
        
        func playRound() {
            let roundExpectation = XCTestExpectation(description: "Round \(currentRound) completed")
            roundExpectation.expectedFulfillmentCount = 2
            
            player1.onRoundResult = { result in
                XCTAssertEqual(result.round, currentRound)
                roundExpectation.fulfill()
            }
            
            player2.onRoundResult = { result in
                XCTAssertEqual(result.round, currentRound)
                roundExpectation.fulfill()
            }
            
            // Both players submit answers
            let plant = mockBackend.getCurrentPlant(for: gameId, round: currentRound)
            let correctAnswer = plant.correctAnswer
            
            // Player 1 answers correctly, Player 2 answers incorrectly
            player1.submitAnswer(correctAnswer, for: gameId, round: currentRound)
            player2.submitAnswer("Wrong Answer", for: gameId, round: currentRound)
            
            wait(for: [roundExpectation], timeout: 5.0)
            
            currentRound += 1
            
            if currentRound <= 5 {
                playRound()
            } else {
                // Game should be complete
                DispatchQueue.main.async {
                    gameResults = self.mockBackend.getGameResult(for: gameId)
                    gameCompletedExpectation.fulfill()
                }
            }
        }
        
        playRound()
        
        wait(for: [gameCompletedExpectation], timeout: 30.0)
        
        // Verify game results
        XCTAssertNotNil(gameResults)
        XCTAssertEqual(gameResults?.winner, player1.id)
        XCTAssertEqual(gameResults?.finalScores[player1.id], 5) // Player 1 won all rounds
        XCTAssertEqual(gameResults?.finalScores[player2.id], 0) // Player 2 lost all rounds
    }
    
    func testTieBreaker() throws {
        let tieBreakerExpectation = XCTestExpectation(description: "Tie breaker completed")
        
        // Setup tied game (2-2 after 4 rounds, then both get round 5 wrong)
        let gameId = "tie-test-game"
        mockBackend.setupTiedGame(gameId: gameId, player1: player1, player2: player2)
        
        var tieBreakerResult: RoundResult?
        
        player1.onRoundResult = { result in
            if result.round > 5 { // Tie breaker round
                tieBreakerResult = result
                tieBreakerExpectation.fulfill()
            }
        }
        
        // Simulate tie breaker round
        let tieBreakerPlant = mockBackend.getTieBreakerPlant(for: gameId)
        
        // Player 1 answers correctly, Player 2 doesn't
        player1.submitAnswer(tieBreakerPlant.correctAnswer, for: gameId, round: 6)
        player2.submitAnswer("Wrong Answer", for: gameId, round: 6)
        
        wait(for: [tieBreakerExpectation], timeout: 10.0)
        
        XCTAssertNotNil(tieBreakerResult)
        XCTAssertEqual(tieBreakerResult?.winner, player1.id)
        XCTAssertTrue(tieBreakerResult!.round > 5)
    }
    
    func testSimultaneousCorrectAnswers() throws {
        let roundExpectation = XCTestExpectation(description: "Round with simultaneous correct answers")
        roundExpectation.expectedFulfillmentCount = 2
        
        let gameId = "timing-test-game"
        mockBackend.setupGame(gameId: gameId, player1: player1, player2: player2)
        
        var player1Result: RoundResult?
        var player2Result: RoundResult?
        
        player1.onRoundResult = { result in
            player1Result = result
            roundExpectation.fulfill()
        }
        
        player2.onRoundResult = { result in
            player2Result = result
            roundExpectation.fulfill()
        }
        
        let plant = mockBackend.getCurrentPlant(for: gameId, round: 1)
        let correctAnswer = plant.correctAnswer
        
        // Submit answers with specific timing
        let player1SubmissionTime = Date()
        let player2SubmissionTime = Date(timeInterval: 0.1, since: player1SubmissionTime)
        
        player1.submitAnswer(correctAnswer, for: gameId, round: 1, at: player1SubmissionTime)
        player2.submitAnswer(correctAnswer, for: gameId, round: 1, at: player2SubmissionTime)
        
        wait(for: [roundExpectation], timeout: 5.0)
        
        // Player 1 should win due to faster submission
        XCTAssertNotNil(player1Result)
        XCTAssertNotNil(player2Result)
        XCTAssertEqual(player1Result?.winner, player1.id)
        XCTAssertEqual(player2Result?.winner, player1.id)
    }
    
    // MARK: - Matchmaking Integration Tests
    
    func testSkillBasedMatchmaking() throws {
        let matchExpectation = XCTestExpectation(description: "Skill-based match found")
        
        // Create players with similar ratings
        let lowRatingPlayer = MockPlayer(id: "low", username: "LowPlayer", rating: 800)
        let midRatingPlayer = MockPlayer(id: "mid", username: "MidPlayer", rating: 1200)
        let highRatingPlayer = MockPlayer(id: "high", username: "HighPlayer", rating: 1600)
        
        var matchedPlayers: [String] = []
        
        midRatingPlayer.onMatchFound = { match in
            matchedPlayers.append(match.opponent.id)
            matchExpectation.fulfill()
        }
        
        // Add players to matchmaking pool
        gameService.startMatchmaking(for: lowRatingPlayer)
        gameService.startMatchmaking(for: midRatingPlayer)
        gameService.startMatchmaking(for: highRatingPlayer)
        
        wait(for: [matchExpectation], timeout: 15.0)
        
        // Mid-rating player should be matched with closer rating player
        XCTAssertTrue(matchedPlayers.contains("low") || matchedPlayers.contains("high"))
        
        // Verify rating difference is reasonable (within 400 points)
        let opponentId = matchedPlayers.first!
        let opponentRating = [lowRatingPlayer, highRatingPlayer]
            .first { $0.id == opponentId }?.rating ?? 0
        
        let ratingDifference = abs(midRatingPlayer.rating - opponentRating)
        XCTAssertLessThanOrEqual(ratingDifference, 400)
    }
    
    func testMatchmakingTimeout() throws {
        let timeoutExpectation = XCTestExpectation(description: "Matchmaking timeout")
        
        player1.onMatchmakingTimeout = {
            timeoutExpectation.fulfill()
        }
        
        // Start matchmaking with no other players
        gameService.startMatchmaking(for: player1)
        
        wait(for: [timeoutExpectation], timeout: 35.0) // Should timeout after 30 seconds
    }
    
    func testDirectChallenge() throws {
        let challengeExpectation = XCTestExpectation(description: "Direct challenge accepted")
        
        player2.onChallengeReceived = { challenge in
            // Auto-accept challenge
            self.gameService.acceptChallenge(challenge.id, for: self.player2)
        }
        
        player1.onMatchFound = { match in
            XCTAssertEqual(match.opponent.id, self.player2.id)
            challengeExpectation.fulfill()
        }
        
        gameService.sendDirectChallenge(from: player1, to: player2)
        
        wait(for: [challengeExpectation], timeout: 10.0)
    }
    
    // MARK: - Network Resilience Tests
    
    func testConnectionRecovery() throws {
        let reconnectionExpectation = XCTestExpectation(description: "Connection recovered")
        
        // Start a game
        let gameId = "recovery-test-game"
        mockBackend.setupGame(gameId: gameId, player1: player1, player2: player2)
        
        player1.onReconnected = {
            reconnectionExpectation.fulfill()
        }
        
        // Simulate connection loss during game
        mockBackend.simulateConnectionLoss(for: player1)
        
        // Connection should automatically recover
        wait(for: [reconnectionExpectation], timeout: 15.0)
        
        // Verify game state is synchronized after reconnection
        let gameState = mockBackend.getGameState(for: gameId)
        XCTAssertNotNil(gameState)
        XCTAssertEqual(gameState?.gameId, gameId)
    }
    
    func testPartialConnectivityHandling() throws {
        let gracefulHandlingExpectation = XCTestExpectation(description: "Partial connectivity handled")
        
        let gameId = "connectivity-test-game"
        mockBackend.setupGame(gameId: gameId, player1: player1, player2: player2)
        
        player1.onConnectivityIssue = { issue in
            XCTAssertEqual(issue, .slowConnection)
            gracefulHandlingExpectation.fulfill()
        }
        
        // Simulate slow connection
        mockBackend.simulateSlowConnection(for: player1)
        
        wait(for: [gracefulHandlingExpectation], timeout: 10.0)
    }
    
    // MARK: - Performance Integration Tests
    
    func testConcurrentGames() throws {
        let concurrentGamesExpectation = XCTestExpectation(description: "Multiple concurrent games")
        concurrentGamesExpectation.expectedFulfillmentCount = 5
        
        // Create 10 players (5 games)
        var players: [MockPlayer] = []
        for i in 0..<10 {
            let player = MockPlayer(id: "player\(i)", username: "Player\(i)", rating: 1200 + i * 10)
            players.append(player)
        }
        
        // Setup match found handlers
        for player in players {
            player.onMatchFound = { _ in
                concurrentGamesExpectation.fulfill()
            }
        }
        
        // Start matchmaking for all players
        for player in players {
            gameService.startMatchmaking(for: player)
        }
        
        wait(for: [concurrentGamesExpectation], timeout: 20.0)
        
        // Verify all players are matched
        let matchedPlayers = players.filter { $0.currentMatch != nil }
        XCTAssertEqual(matchedPlayers.count, 10)
    }
    
    func testSystemLoadHandling() throws {
        let loadTestExpectation = XCTestExpectation(description: "System handles high load")
        
        // Simulate 100 concurrent players
        var players: [MockPlayer] = []
        for i in 0..<100 {
            let player = MockPlayer(id: "load_player\(i)", username: "LoadPlayer\(i)", rating: 1000 + i)
            players.append(player)
        }
        
        var successfulMatches = 0
        var errors = 0
        
        for player in players {
            player.onMatchFound = { _ in
                successfulMatches += 1
                if successfulMatches >= 50 { // 50 matches from 100 players
                    loadTestExpectation.fulfill()
                }
            }
            
            player.onError = { _ in
                errors += 1
            }
        }
        
        // Start matchmaking rapidly
        for player in players {
            gameService.startMatchmaking(for: player)
        }
        
        wait(for: [loadTestExpectation], timeout: 30.0)
        
        // Verify system handled load gracefully
        XCTAssertGreaterThanOrEqual(successfulMatches, 50)
        XCTAssertLessThan(errors, 5) // Less than 5% error rate
    }
    
    // MARK: - Game Center Integration Tests
    
    func testGameCenterLeaderboardIntegration() throws {
        let leaderboardExpectation = XCTestExpectation(description: "Leaderboard updated")
        
        // Complete a game with player1 winning
        let gameResult = GameResult(
            gameId: "leaderboard-test",
            winner: player1.id,
            finalScores: [player1.id: 3, player2.id: 2],
            duration: 180,
            completedAt: Date()
        )
        
        player1.onLeaderboardUpdated = { leaderboard in
            XCTAssertGreaterThan(leaderboard.score, 0)
            leaderboardExpectation.fulfill()
        }
        
        gameService.submitGameResult(gameResult)
        
        wait(for: [leaderboardExpectation], timeout: 10.0)
    }
    
    func testGameCenterAchievements() throws {
        let achievementExpectation = XCTestExpectation(description: "Achievement unlocked")
        
        player1.onAchievementUnlocked = { achievement in
            XCTAssertEqual(achievement.id, "first_win")
            achievementExpectation.fulfill()
        }
        
        // Simulate first win
        let firstWinResult = GameResult(
            gameId: "first-win-test",
            winner: player1.id,
            finalScores: [player1.id: 3, player2.id: 0],
            duration: 120,
            completedAt: Date()
        )
        
        gameService.submitGameResult(firstWinResult)
        
        wait(for: [achievementExpectation], timeout: 10.0)
    }
}
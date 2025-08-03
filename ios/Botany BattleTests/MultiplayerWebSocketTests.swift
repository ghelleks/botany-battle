import XCTest
import Network
import GameKit
@testable import BotanyBattle

final class MultiplayerWebSocketTests: XCTestCase {
    
    var webSocketService: WebSocketService!
    var mockDelegate: MockWebSocketDelegate!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        webSocketService = WebSocketService()
        mockDelegate = MockWebSocketDelegate()
        webSocketService.delegate = mockDelegate
    }
    
    override func tearDownWithError() throws {
        webSocketService?.disconnect()
        webSocketService = nil
        mockDelegate = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Connection Tests
    
    func testWebSocketConnection() throws {
        let expectation = XCTestExpectation(description: "WebSocket connection established")
        
        mockDelegate.onConnected = {
            expectation.fulfill()
        }
        
        webSocketService.connect(to: TestConstants.testWebSocketURL)
        
        wait(for: [expectation], timeout: 10.0)
        XCTAssertTrue(webSocketService.isConnected)
    }
    
    func testWebSocketDisconnection() throws {
        let connectExpectation = XCTestExpectation(description: "WebSocket connected")
        let disconnectExpectation = XCTestExpectation(description: "WebSocket disconnected")
        
        mockDelegate.onConnected = {
            connectExpectation.fulfill()
        }
        
        mockDelegate.onDisconnected = {
            disconnectExpectation.fulfill()
        }
        
        webSocketService.connect(to: TestConstants.testWebSocketURL)
        wait(for: [connectExpectation], timeout: 10.0)
        
        webSocketService.disconnect()
        wait(for: [disconnectExpectation], timeout: 5.0)
        
        XCTAssertFalse(webSocketService.isConnected)
    }
    
    func testConnectionResilience() throws {
        let reconnectExpectation = XCTestExpectation(description: "WebSocket reconnected")
        reconnectExpectation.expectedFulfillmentCount = 2
        
        mockDelegate.onConnected = {
            reconnectExpectation.fulfill()
        }
        
        // Initial connection
        webSocketService.connect(to: TestConstants.testWebSocketURL)
        
        // Simulate connection loss and automatic reconnection
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.webSocketService.simulateConnectionLoss()
        }
        
        wait(for: [reconnectExpectation], timeout: 15.0)
    }
    
    // MARK: - Game Communication Tests
    
    func testGameStateReceived() throws {
        let expectation = XCTestExpectation(description: "Game state received")
        
        let expectedGameState = GameState(
            gameId: "test-game-123",
            round: 1,
            plant: PlantQuestion(
                id: "plant-456",
                imageUrl: "https://example.com/plant.jpg",
                options: ["Rose", "Tulip", "Daisy", "Lily"]
            ),
            timeRemaining: 30,
            scores: ["player1": 0, "player2": 0]
        )
        
        mockDelegate.onGameStateReceived = { gameState in
            XCTAssertEqual(gameState.gameId, expectedGameState.gameId)
            XCTAssertEqual(gameState.round, expectedGameState.round)
            XCTAssertEqual(gameState.timeRemaining, expectedGameState.timeRemaining)
            expectation.fulfill()
        }
        
        webSocketService.connect(to: TestConstants.testWebSocketURL)
        
        // Simulate receiving game state from server
        let gameStateMessage = WebSocketMessage(
            type: .gameState,
            data: expectedGameState
        )
        webSocketService.simulateMessageReceived(gameStateMessage)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testPlayerAnswerSubmission() throws {
        let expectation = XCTestExpectation(description: "Player answer sent")
        
        mockDelegate.onMessageSent = { message in
            if case .playerAnswer(let answer) = message.type {
                XCTAssertEqual(answer.answer, "Rose")
                XCTAssertEqual(answer.gameId, "test-game-123")
                expectation.fulfill()
            }
        }
        
        webSocketService.connect(to: TestConstants.testWebSocketURL)
        
        let playerAnswer = PlayerAnswer(
            playerId: "player-123",
            gameId: "test-game-123",
            round: 1,
            answer: "Rose",
            timestamp: Date()
        )
        
        webSocketService.sendPlayerAnswer(playerAnswer)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testRoundResultReceived() throws {
        let expectation = XCTestExpectation(description: "Round result received")
        
        let expectedResult = RoundResult(
            gameId: "test-game-123",
            round: 1,
            correctAnswer: "Rose",
            winner: "player-123",
            scores: ["player-123": 1, "player-456": 0],
            plantFact: "Roses are part of the Rosaceae family."
        )
        
        mockDelegate.onRoundResultReceived = { result in
            XCTAssertEqual(result.correctAnswer, expectedResult.correctAnswer)
            XCTAssertEqual(result.winner, expectedResult.winner)
            XCTAssertEqual(result.plantFact, expectedResult.plantFact)
            expectation.fulfill()
        }
        
        webSocketService.connect(to: TestConstants.testWebSocketURL)
        
        let resultMessage = WebSocketMessage(
            type: .roundResult,
            data: expectedResult
        )
        webSocketService.simulateMessageReceived(resultMessage)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Matchmaking Tests
    
    func testMatchmakingQueue() throws {
        let expectation = XCTestExpectation(description: "Queue position updated")
        
        let queueUpdate = MatchmakingQueueUpdate(
            position: 3,
            estimatedWaitTime: 15.0,
            playersInQueue: 12
        )
        
        mockDelegate.onQueueUpdateReceived = { update in
            XCTAssertEqual(update.position, queueUpdate.position)
            XCTAssertEqual(update.estimatedWaitTime, queueUpdate.estimatedWaitTime)
            XCTAssertEqual(update.playersInQueue, queueUpdate.playersInQueue)
            expectation.fulfill()
        }
        
        webSocketService.connect(to: TestConstants.testWebSocketURL)
        
        let queueMessage = WebSocketMessage(
            type: .queueUpdate,
            data: queueUpdate
        )
        webSocketService.simulateMessageReceived(queueMessage)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testMatchFound() throws {
        let expectation = XCTestExpectation(description: "Match found")
        
        let matchData = MatchFoundData(
            gameId: "new-game-789",
            opponent: Opponent(
                id: "opponent-456",
                username: "plantlover",
                rating: 1250
            )
        )
        
        mockDelegate.onMatchFoundReceived = { match in
            XCTAssertEqual(match.gameId, matchData.gameId)
            XCTAssertEqual(match.opponent.username, matchData.opponent.username)
            XCTAssertEqual(match.opponent.rating, matchData.opponent.rating)
            expectation.fulfill()
        }
        
        webSocketService.connect(to: TestConstants.testWebSocketURL)
        
        let matchMessage = WebSocketMessage(
            type: .matchFound,
            data: matchData
        )
        webSocketService.simulateMessageReceived(matchMessage)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Performance Tests
    
    func testHighVolumeMessageHandling() throws {
        let expectation = XCTestExpectation(description: "High volume messages handled")
        expectation.expectedFulfillmentCount = 100
        
        mockDelegate.onGameStateReceived = { _ in
            expectation.fulfill()
        }
        
        webSocketService.connect(to: TestConstants.testWebSocketURL)
        
        // Send 100 rapid messages
        for i in 0..<100 {
            let gameState = GameState(
                gameId: "performance-test-\(i)",
                round: 1,
                plant: PlantQuestion(id: "plant-\(i)", imageUrl: "test.jpg", options: ["A", "B", "C", "D"]),
                timeRemaining: 30,
                scores: ["player1": 0, "player2": 0]
            )
            
            let message = WebSocketMessage(type: .gameState, data: gameState)
            webSocketService.simulateMessageReceived(message)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testMessageLatency() throws {
        let expectation = XCTestExpectation(description: "Message latency measured")
        
        let startTime = Date()
        var endTime: Date?
        
        mockDelegate.onGameStateReceived = { _ in
            endTime = Date()
            expectation.fulfill()
        }
        
        webSocketService.connect(to: TestConstants.testWebSocketURL)
        
        let gameState = GameState(
            gameId: "latency-test",
            round: 1,
            plant: PlantQuestion(id: "plant-1", imageUrl: "test.jpg", options: ["A", "B", "C", "D"]),
            timeRemaining: 30,
            scores: ["player1": 0, "player2": 0]
        )
        
        let message = WebSocketMessage(type: .gameState, data: gameState)
        webSocketService.simulateMessageReceived(message)
        
        wait(for: [expectation], timeout: 5.0)
        
        if let endTime = endTime {
            let latency = endTime.timeIntervalSince(startTime)
            XCTAssertLessThan(latency, 0.1, "Message latency should be less than 100ms")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testMalformedMessageHandling() throws {
        let expectation = XCTestExpectation(description: "Error handled gracefully")
        
        mockDelegate.onError = { error in
            XCTAssertTrue(error is WebSocketError)
            expectation.fulfill()
        }
        
        webSocketService.connect(to: TestConstants.testWebSocketURL)
        
        // Simulate receiving malformed message
        webSocketService.simulateMalformedMessage()
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testNetworkTimeoutHandling() throws {
        let expectation = XCTestExpectation(description: "Network timeout handled")
        
        mockDelegate.onError = { error in
            if case WebSocketError.networkTimeout = error {
                expectation.fulfill()
            }
        }
        
        webSocketService.connect(to: TestConstants.testWebSocketURL)
        
        // Simulate network timeout
        webSocketService.simulateNetworkTimeout()
        
        wait(for: [expectation], timeout: 15.0)
    }
}

// MARK: - Mock Delegate

class MockWebSocketDelegate: WebSocketServiceDelegate {
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    var onError: ((Error) -> Void)?
    var onMessageSent: ((WebSocketMessage) -> Void)?
    var onGameStateReceived: ((GameState) -> Void)?
    var onRoundResultReceived: ((RoundResult) -> Void)?
    var onQueueUpdateReceived: ((MatchmakingQueueUpdate) -> Void)?
    var onMatchFoundReceived: ((MatchFoundData) -> Void)?
    
    func webSocketDidConnect() {
        onConnected?()
    }
    
    func webSocketDidDisconnect() {
        onDisconnected?()
    }
    
    func webSocketDidReceiveError(_ error: Error) {
        onError?(error)
    }
    
    func webSocketDidSendMessage(_ message: WebSocketMessage) {
        onMessageSent?(message)
    }
    
    func webSocketDidReceiveGameState(_ gameState: GameState) {
        onGameStateReceived?(gameState)
    }
    
    func webSocketDidReceiveRoundResult(_ result: RoundResult) {
        onRoundResultReceived?(result)
    }
    
    func webSocketDidReceiveQueueUpdate(_ update: MatchmakingQueueUpdate) {
        onQueueUpdateReceived?(update)
    }
    
    func webSocketDidReceiveMatchFound(_ matchData: MatchFoundData) {
        onMatchFoundReceived?(matchData)
    }
}

// MARK: - Test Constants

enum TestConstants {
    static let testWebSocketURL = "ws://localhost:3001"
    static let testGameId = "test-game-123"
    static let testPlayerId = "test-player-456"
}
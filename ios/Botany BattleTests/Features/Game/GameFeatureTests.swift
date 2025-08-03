import XCTest
import Combine
@testable import BotanyBattle

@MainActor
final class GameFeatureTests: XCTestCase {
    
    var sut: GameFeature!
    var mockPlantAPIService: MockPlantAPIService!
    var mockTimerService: MockTimerService!
    var mockUserDefaultsService: MockUserDefaultsService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        mockPlantAPIService = MockPlantAPIService()
        mockTimerService = MockTimerService()
        mockUserDefaultsService = MockUserDefaultsService()
        
        sut = GameFeature(
            plantAPIService: mockPlantAPIService,
            timerService: mockTimerService,
            userDefaultsService: mockUserDefaultsService
        )
        
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        sut = nil
        mockPlantAPIService = nil
        mockTimerService = nil
        mockUserDefaultsService = nil
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        // Given & When & Then
        XCTAssertEqual(sut.gameState, .idle)
        XCTAssertEqual(sut.currentMode, .practice)
        XCTAssertEqual(sut.currentQuestionIndex, 0)
        XCTAssertEqual(sut.score, 0)
        XCTAssertEqual(sut.correctAnswers, 0)
        XCTAssertTrue(sut.questions.isEmpty)
        XCTAssertNil(sut.currentQuestion)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
    
    // MARK: - Game Mode Selection Tests
    
    func testSetGameMode_UpdatesCurrentMode() {
        // Given
        XCTAssertEqual(sut.currentMode, .practice)
        
        // When
        sut.setGameMode(.speedrun)
        
        // Then
        XCTAssertEqual(sut.currentMode, .speedrun)
    }
    
    func testSetGameMode_ResetsGameState() {
        // Given
        sut.score = 100
        sut.correctAnswers = 5
        sut.currentQuestionIndex = 3
        
        // When
        sut.setGameMode(.timeAttack)
        
        // Then
        XCTAssertEqual(sut.score, 0)
        XCTAssertEqual(sut.correctAnswers, 0)
        XCTAssertEqual(sut.currentQuestionIndex, 0)
        XCTAssertEqual(sut.gameState, .idle)
    }
    
    // MARK: - Start Game Tests
    
    func testStartGame_Practice_Success() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 10)
        sut.setGameMode(.practice)
        
        // When
        await sut.startGame()
        
        // Then
        XCTAssertEqual(sut.gameState, .playing)
        XCTAssertEqual(sut.questions.count, 10)
        XCTAssertNotNil(sut.currentQuestion)
        XCTAssertFalse(mockTimerService.isRunning) // Practice mode doesn't use timer
        XCTAssertTrue(mockPlantAPIService.fetchPlantsCalled)
    }
    
    func testStartGame_TimeAttack_StartsTimer() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 5)
        sut.setGameMode(.timeAttack)
        
        // When
        await sut.startGame()
        
        // Then
        XCTAssertEqual(sut.gameState, .playing)
        XCTAssertTrue(mockTimerService.startTimerCalled)
        XCTAssertEqual(mockTimerService.lastTimerDuration, GameConstants.timeAttackLimit)
    }
    
    func testStartGame_Speedrun_ConfiguresCorrectly() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 25)
        sut.setGameMode(.speedrun)
        
        // When
        await sut.startGame()
        
        // Then
        XCTAssertEqual(sut.gameState, .playing)
        XCTAssertEqual(sut.questions.count, GameConstants.speedrunQuestionCount)
        XCTAssertTrue(mockTimerService.startTimerCalled)
    }
    
    func testStartGame_APIFailure_ShowsError() async {
        // Given
        mockPlantAPIService.shouldFail = true
        
        // When
        await sut.startGame()
        
        // Then
        XCTAssertEqual(sut.gameState, .error)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.questions.isEmpty)
    }
    
    func testStartGame_ShowsLoadingState() async {
        // Given
        let expectation = XCTestExpectation(description: "Loading state observed")
        mockPlantAPIService.responseDelay = 0.1
        mockPlantAPIService.mockPlants = createMockPlants(count: 5)
        
        var loadingStates: [Bool] = []
        sut.$isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
                if loadingStates.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        await sut.startGame()
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(loadingStates[0], false) // Initial state
        XCTAssertEqual(loadingStates[1], true)  // Loading state
    }
    
    // MARK: - Answer Submission Tests
    
    func testSubmitAnswer_Correct_UpdatesScore() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 5)
        await sut.startGame()
        
        guard let currentQuestion = sut.currentQuestion else {
            XCTFail("Should have current question")
            return
        }
        
        // When
        sut.submitAnswer(currentQuestion.correctAnswerIndex)
        
        // Then
        XCTAssertEqual(sut.correctAnswers, 1)
        XCTAssertGreaterThan(sut.score, 0)
    }
    
    func testSubmitAnswer_Incorrect_DoesNotUpdateScore() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 5)
        await sut.startGame()
        
        guard let currentQuestion = sut.currentQuestion else {
            XCTFail("Should have current question")
            return
        }
        
        let wrongAnswerIndex = (currentQuestion.correctAnswerIndex + 1) % currentQuestion.options.count
        
        // When
        sut.submitAnswer(wrongAnswerIndex)
        
        // Then
        XCTAssertEqual(sut.correctAnswers, 0)
        XCTAssertEqual(sut.score, 0)
    }
    
    func testSubmitAnswer_AdvancesToNextQuestion() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 5)
        await sut.startGame()
        XCTAssertEqual(sut.currentQuestionIndex, 0)
        
        // When
        sut.submitAnswer(0) // Any answer
        
        // Then
        XCTAssertEqual(sut.currentQuestionIndex, 1)
    }
    
    func testSubmitAnswer_LastQuestion_EndsGame() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 2)
        await sut.startGame()
        
        // Answer first question
        sut.submitAnswer(0)
        XCTAssertEqual(sut.currentQuestionIndex, 1)
        
        // When - Answer last question
        sut.submitAnswer(0)
        
        // Then
        XCTAssertEqual(sut.gameState, .completed)
        XCTAssertTrue(mockTimerService.stopTimerCalled)
    }
    
    // MARK: - Game Completion Tests
    
    func testCompleteGame_UpdatesStatistics() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 3)
        await sut.startGame()
        
        // Answer all questions correctly
        sut.submitAnswer(sut.currentQuestion!.correctAnswerIndex)
        sut.submitAnswer(sut.currentQuestion!.correctAnswerIndex)
        sut.submitAnswer(sut.currentQuestion!.correctAnswerIndex)
        
        // When - Game completes automatically
        
        // Then
        XCTAssertEqual(sut.gameState, .completed)
        XCTAssertTrue(mockUserDefaultsService.recordGameCompletionCalled)
        XCTAssertEqual(mockUserDefaultsService.lastCorrectAnswers, 3)
        XCTAssertTrue(mockUserDefaultsService.lastWasPerfect)
    }
    
    func testCompleteGame_UpdatesHighScore() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 2)
        mockUserDefaultsService.practiceHighScore = 50
        sut.setGameMode(.practice)
        await sut.startGame()
        
        // Score 100 points
        sut.score = 100
        sut.submitAnswer(0) // First question
        sut.submitAnswer(0) // Last question - triggers completion
        
        // Then
        XCTAssertTrue(mockUserDefaultsService.updatePracticeHighScoreCalled)
        XCTAssertEqual(mockUserDefaultsService.lastSubmittedScore, 100)
    }
    
    // MARK: - Timer Integration Tests
    
    func testTimerExpired_EndsGame() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 10)
        sut.setGameMode(.timeAttack)
        await sut.startGame()
        
        // When
        mockTimerService.simulateTimerExpiration()
        
        // Then
        XCTAssertEqual(sut.gameState, .completed)
    }
    
    func testPauseGame_PausesTimer() {
        // Given
        sut.setGameMode(.timeAttack)
        
        // When
        sut.pauseGame()
        
        // Then
        XCTAssertEqual(sut.gameState, .paused)
        XCTAssertTrue(mockTimerService.pauseTimerCalled)
    }
    
    func testResumeGame_ResumesTimer() {
        // Given
        sut.setGameMode(.timeAttack)
        sut.pauseGame()
        
        // When
        sut.resumeGame()
        
        // Then
        XCTAssertEqual(sut.gameState, .playing)
        XCTAssertTrue(mockTimerService.resumeTimerCalled)
    }
    
    // MARK: - Score Calculation Tests
    
    func testScoreCalculation_BasicPoints() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 1)
        await sut.startGame()
        
        // When
        sut.submitAnswer(sut.currentQuestion!.correctAnswerIndex)
        
        // Then
        XCTAssertEqual(sut.score, GameConstants.correctAnswerPoints)
    }
    
    func testScoreCalculation_SpeedBonus() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 1)
        sut.setGameMode(.speedrun)
        await sut.startGame()
        
        // Simulate fast answer (within speed bonus time)
        mockTimerService.timeRemaining = 58 // Answered quickly
        
        // When
        sut.submitAnswer(sut.currentQuestion!.correctAnswerIndex)
        
        // Then
        let expectedScore = GameConstants.correctAnswerPoints + GameConstants.speedBonus
        XCTAssertEqual(sut.score, expectedScore)
    }
    
    // MARK: - Error Handling Tests
    
    func testRestartGame_ResetsState() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 5)
        await sut.startGame()
        sut.submitAnswer(0) // Answer a question
        XCTAssertGreaterThan(sut.currentQuestionIndex, 0)
        
        // When
        await sut.restartGame()
        
        // Then
        XCTAssertEqual(sut.gameState, .playing)
        XCTAssertEqual(sut.currentQuestionIndex, 0)
        XCTAssertEqual(sut.score, 0)
        XCTAssertEqual(sut.correctAnswers, 0)
    }
    
    func testStopGame_ReturnsToIdle() {
        // Given
        sut.gameState = .playing
        
        // When
        sut.stopGame()
        
        // Then
        XCTAssertEqual(sut.gameState, .idle)
        XCTAssertTrue(mockTimerService.stopTimerCalled)
    }
    
    // MARK: - Publisher Tests
    
    func testGameStatePublisher_EmitsChanges() async {
        // Given
        let expectation = XCTestExpectation(description: "Game state changes")
        expectation.expectedFulfillmentCount = 2
        
        var gameStates: [GameState] = []
        sut.$gameState
            .sink { state in
                gameStates.append(state)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        mockPlantAPIService.mockPlants = createMockPlants(count: 1)
        
        // When
        await sut.startGame()
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(gameStates[0], .idle)
        XCTAssertEqual(gameStates[1], .playing)
    }
    
    // MARK: - Performance Tests
    
    func testGameStartPerformance() {
        measure {
            let expectation = XCTestExpectation(description: "Game start performance")
            mockPlantAPIService.mockPlants = createMockPlants(count: 10)
            
            Task {
                await sut.startGame()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 2.0)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockPlants(count: Int) -> [PlantData] {
        return (1...count).map { index in
            PlantData(
                name: "Plant \(index)",
                scientificName: "Plantus \(index)",
                imageURL: "https://example.com/plant\(index).jpg",
                description: "Description for plant \(index)"
            )
        }
    }
}

// MARK: - Mock Services

@MainActor
class MockPlantAPIService: ObservableObject {
    var mockPlants: [PlantData] = []
    var shouldFail = false
    var responseDelay: TimeInterval = 0
    var fetchPlantsCalled = false
    
    func fetchPlants() async -> [PlantData] {
        fetchPlantsCalled = true
        
        if responseDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }
        
        if shouldFail {
            return []
        }
        
        return mockPlants
    }
}

@MainActor
class MockTimerService: ObservableObject {
    @Published var timeRemaining: Int = 0
    @Published var isRunning = false
    
    var startTimerCalled = false
    var stopTimerCalled = false
    var pauseTimerCalled = false
    var resumeTimerCalled = false
    var lastTimerDuration: Int = 0
    
    var onTimerCompleted: (() -> Void)?
    
    func startTimer(duration: Int) {
        startTimerCalled = true
        lastTimerDuration = duration
        timeRemaining = duration
        isRunning = true
    }
    
    func stopTimer() {
        stopTimerCalled = true
        isRunning = false
        timeRemaining = 0
    }
    
    func pauseTimer() {
        pauseTimerCalled = true
        isRunning = false
    }
    
    func resumeTimer() {
        resumeTimerCalled = true
        isRunning = true
    }
    
    func simulateTimerExpiration() {
        timeRemaining = 0
        isRunning = false
        onTimerCompleted?()
    }
}

class MockUserDefaultsService: ObservableObject {
    var practiceHighScore = 0
    var speedrunBestTime = Double.greatestFiniteMagnitude
    var timeAttackHighScore = 0
    
    var recordGameCompletionCalled = false
    var updatePracticeHighScoreCalled = false
    var updateSpeedrunBestTimeCalled = false
    var updateTimeAttackHighScoreCalled = false
    
    var lastCorrectAnswers = 0
    var lastWasPerfect = false
    var lastSubmittedScore = 0
    var lastSubmittedTime = 0.0
    
    func recordGameCompletion(correctAnswers: Int, wasPerfect: Bool) {
        recordGameCompletionCalled = true
        lastCorrectAnswers = correctAnswers
        lastWasPerfect = wasPerfect
    }
    
    func updatePracticeHighScore(_ score: Int) {
        updatePracticeHighScoreCalled = true
        lastSubmittedScore = score
        practiceHighScore = max(practiceHighScore, score)
    }
    
    func updateSpeedrunBestTime(_ time: Double) {
        updateSpeedrunBestTimeCalled = true
        lastSubmittedTime = time
        speedrunBestTime = min(speedrunBestTime, time)
    }
    
    func updateTimeAttackHighScore(_ score: Int) {
        updateTimeAttackHighScoreCalled = true
        lastSubmittedScore = score
        timeAttackHighScore = max(timeAttackHighScore, score)
    }
}

// MARK: - Game State Enum

enum GameState {
    case idle
    case playing
    case paused
    case completed
    case error
}

enum GameMode {
    case practice
    case timeAttack
    case speedrun
}
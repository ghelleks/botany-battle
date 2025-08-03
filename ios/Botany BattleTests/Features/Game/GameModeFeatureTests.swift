import XCTest
import Combine
@testable import BotanyBattle

@MainActor
final class GameModeFeatureTests: XCTestCase {
    
    var gameFeature: GameFeature!
    var mockPlantAPIService: MockPlantAPIService!
    var mockTimerService: MockTimerService!
    var mockUserDefaultsService: MockUserDefaultsService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        mockPlantAPIService = MockPlantAPIService()
        mockTimerService = MockTimerService()
        mockUserDefaultsService = MockUserDefaultsService()
        
        gameFeature = GameFeature(
            plantAPIService: mockPlantAPIService,
            timerService: mockTimerService,
            userDefaultsService: mockUserDefaultsService
        )
        
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        gameFeature = nil
        mockPlantAPIService = nil
        mockTimerService = nil
        mockUserDefaultsService = nil
    }
    
    // MARK: - Practice Mode Tests
    
    func testPracticeMode_NoTimer() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 5)
        gameFeature.setGameMode(.practice)
        
        // When
        await gameFeature.startGame()
        
        // Then
        XCTAssertEqual(gameFeature.gameState, .playing)
        XCTAssertFalse(mockTimerService.startTimerCalled)
        XCTAssertFalse(gameFeature.canPause)
    }
    
    func testPracticeMode_UnlimitedQuestions() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 100)
        gameFeature.setGameMode(.practice)
        
        // When
        await gameFeature.startGame()
        
        // Then
        XCTAssertLessThanOrEqual(gameFeature.questions.count, 20) // Default max
        XCTAssertEqual(gameFeature.gameState, .playing)
    }
    
    func testPracticeMode_ScoreUpdates() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 3)
        gameFeature.setGameMode(.practice)
        await gameFeature.startGame()
        
        // When
        gameFeature.submitAnswer(gameFeature.currentQuestion!.correctAnswerIndex)
        
        // Then
        XCTAssertEqual(gameFeature.score, GameConstants.correctAnswerPoints)
        XCTAssertEqual(gameFeature.correctAnswers, 1)
    }
    
    // MARK: - Time Attack Mode Tests
    
    func testTimeAttackMode_StartsTimer() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 10)
        gameFeature.setGameMode(.timeAttack)
        
        // When
        await gameFeature.startGame()
        
        // Then
        XCTAssertEqual(gameFeature.gameState, .playing)
        XCTAssertTrue(mockTimerService.startTimerCalled)
        XCTAssertEqual(mockTimerService.lastTimerDuration, GameConstants.timeAttackLimit)
        XCTAssertTrue(gameFeature.canPause)
    }
    
    func testTimeAttackMode_TimerExpiration() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 10)
        gameFeature.setGameMode(.timeAttack)
        await gameFeature.startGame()
        
        // When
        mockTimerService.simulateTimerExpiration()
        
        // Then
        XCTAssertEqual(gameFeature.gameState, .completed)
        XCTAssertTrue(mockUserDefaultsService.updateTimeAttackHighScoreCalled)
    }
    
    func testTimeAttackMode_PauseResume() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 5)
        gameFeature.setGameMode(.timeAttack)
        await gameFeature.startGame()
        
        // When
        gameFeature.pauseGame()
        
        // Then
        XCTAssertEqual(gameFeature.gameState, .paused)
        XCTAssertTrue(mockTimerService.pauseTimerCalled)
        XCTAssertTrue(gameFeature.canResume)
        
        // When
        gameFeature.resumeGame()
        
        // Then
        XCTAssertEqual(gameFeature.gameState, .playing)
        XCTAssertTrue(mockTimerService.resumeTimerCalled)
    }
    
    func testTimeAttackMode_MaximizeScore() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 5)
        gameFeature.setGameMode(.timeAttack)
        await gameFeature.startGame()
        
        // Simulate fast answers for speed bonus
        mockTimerService.timeRemaining = GameConstants.timeAttackLimit - 1
        
        // When - Answer multiple questions correctly
        for _ in 0..<3 {
            guard gameFeature.currentQuestion != nil else { break }
            gameFeature.submitAnswer(gameFeature.currentQuestion!.correctAnswerIndex)
        }
        
        // Then
        XCTAssertGreaterThan(gameFeature.score, GameConstants.correctAnswerPoints * 3)
        XCTAssertEqual(gameFeature.correctAnswers, 3)
    }
    
    // MARK: - Speedrun Mode Tests
    
    func testSpeedrunMode_FixedQuestionCount() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 50)
        gameFeature.setGameMode(.speedrun)
        
        // When
        await gameFeature.startGame()
        
        // Then
        XCTAssertEqual(gameFeature.questions.count, GameConstants.speedrunQuestionCount)
        XCTAssertTrue(mockTimerService.startTimerCalled)
    }
    
    func testSpeedrunMode_CompletionByQuestions() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: GameConstants.speedrunQuestionCount)
        gameFeature.setGameMode(.speedrun)
        await gameFeature.startGame()
        
        // When - Answer all questions
        for _ in 0..<GameConstants.speedrunQuestionCount {
            guard gameFeature.currentQuestion != nil else { break }
            gameFeature.submitAnswer(0) // Any answer
        }
        
        // Then
        XCTAssertEqual(gameFeature.gameState, .completed)
        XCTAssertTrue(mockUserDefaultsService.updateSpeedrunBestTimeCalled)
    }
    
    func testSpeedrunMode_BestTimeTracking() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 3)
        gameFeature.setGameMode(.speedrun)
        mockUserDefaultsService.speedrunBestTime = 120.0 // 2 minutes
        await gameFeature.startGame()
        
        // When - Complete game quickly
        for _ in 0..<3 {
            gameFeature.submitAnswer(gameFeature.currentQuestion!.correctAnswerIndex)
        }
        
        // Then
        XCTAssertTrue(mockUserDefaultsService.updateSpeedrunBestTimeCalled)
        XCTAssertGreaterThan(mockUserDefaultsService.lastSubmittedTime, 0)
    }
    
    // MARK: - Score Calculation Tests
    
    func testSpeedBonus_TimeAttackMode() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 2)
        gameFeature.setGameMode(.timeAttack)
        await gameFeature.startGame()
        
        // Simulate very fast answer
        mockTimerService.timeRemaining = GameConstants.timeAttackLimit - 1
        
        // When
        gameFeature.submitAnswer(gameFeature.currentQuestion!.correctAnswerIndex)
        
        // Then
        let expectedMinScore = GameConstants.correctAnswerPoints
        XCTAssertGreaterThanOrEqual(gameFeature.score, expectedMinScore)
    }
    
    func testStreakBonus_MultipleCorrectAnswers() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 6)
        gameFeature.setGameMode(.practice)
        await gameFeature.startGame()
        
        // When - Answer 5 questions correctly for streak bonus
        for _ in 0..<5 {
            guard gameFeature.currentQuestion != nil else { break }
            gameFeature.submitAnswer(gameFeature.currentQuestion!.correctAnswerIndex)
        }
        
        // Then
        let expectedMinScore = GameConstants.correctAnswerPoints * 5
        XCTAssertGreaterThanOrEqual(gameFeature.score, expectedMinScore)
    }
    
    func testStreakReset_IncorrectAnswer() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 4)
        gameFeature.setGameMode(.practice)
        await gameFeature.startGame()
        
        // Answer first question correctly
        gameFeature.submitAnswer(gameFeature.currentQuestion!.correctAnswerIndex)
        let scoreAfterCorrect = gameFeature.score
        
        // When - Answer incorrectly
        let wrongIndex = (gameFeature.currentQuestion!.correctAnswerIndex + 1) % 
                        gameFeature.currentQuestion!.options.count
        gameFeature.submitAnswer(wrongIndex)
        
        // Then
        XCTAssertEqual(gameFeature.score, scoreAfterCorrect) // No additional points
        XCTAssertEqual(gameFeature.correctAnswers, 1) // Still only 1 correct
    }
    
    // MARK: - Statistics Tests
    
    func testAccuracyCalculation() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 4)
        gameFeature.setGameMode(.practice)
        await gameFeature.startGame()
        
        // Answer 2 correctly, 1 incorrectly
        gameFeature.submitAnswer(gameFeature.currentQuestion!.correctAnswerIndex) // Correct
        gameFeature.submitAnswer(gameFeature.currentQuestion!.correctAnswerIndex) // Correct
        let wrongIndex = (gameFeature.currentQuestion!.correctAnswerIndex + 1) % 
                        gameFeature.currentQuestion!.options.count
        gameFeature.submitAnswer(wrongIndex) // Incorrect
        
        // Then
        let expectedAccuracy = 2.0 / 3.0 // 2 correct out of 3 answered
        XCTAssertEqual(gameFeature.accuracy, expectedAccuracy, accuracy: 0.01)
    }
    
    func testNewHighScore_Detection() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 2)
        mockUserDefaultsService.practiceHighScore = 50
        gameFeature.setGameMode(.practice)
        await gameFeature.startGame()
        
        // Set a high score
        gameFeature.score = 100
        
        // When
        let isNewHighScore = gameFeature.isNewHighScore
        
        // Then
        XCTAssertTrue(isNewHighScore)
    }
    
    // MARK: - Error Handling Tests
    
    func testGameMode_InvalidTransition() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 5)
        await gameFeature.startGame()
        XCTAssertEqual(gameFeature.gameState, .playing)
        
        // When - Try to pause practice mode (not allowed)
        gameFeature.pauseGame()
        
        // Then
        XCTAssertEqual(gameFeature.gameState, .playing) // Should remain playing
        XCTAssertFalse(mockTimerService.pauseTimerCalled)
    }
    
    func testGameRestart_ResetsState() async {
        // Given
        mockPlantAPIService.mockPlants = createMockPlants(count: 3)
        await gameFeature.startGame()
        gameFeature.submitAnswer(0) // Answer first question
        XCTAssertGreaterThan(gameFeature.currentQuestionIndex, 0)
        
        // When
        await gameFeature.restartGame()
        
        // Then
        XCTAssertEqual(gameFeature.currentQuestionIndex, 0)
        XCTAssertEqual(gameFeature.score, 0)
        XCTAssertEqual(gameFeature.correctAnswers, 0)
        XCTAssertEqual(gameFeature.gameState, .playing)
    }
    
    // MARK: - Performance Tests
    
    func testLargeQuestionSet_Performance() {
        measure {
            let expectation = XCTestExpectation(description: "Large question set performance")
            mockPlantAPIService.mockPlants = createMockPlants(count: 100)
            
            Task {
                await gameFeature.startGame()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 3.0)
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

// MARK: - Game Mode Specific Feature Tests

@MainActor
final class PracticeModeFeatureTests: XCTestCase {
    
    var practiceFeature: PracticeFeature!
    var mockGameFeature: MockGameFeature!
    
    override func setUp() {
        mockGameFeature = MockGameFeature()
        practiceFeature = PracticeFeature(gameFeature: mockGameFeature)
    }
    
    override func tearDown() {
        practiceFeature = nil
        mockGameFeature = nil
    }
    
    func testPracticeFeature_ConfiguresGameCorrectly() {
        // When
        practiceFeature.startPractice()
        
        // Then
        XCTAssertTrue(mockGameFeature.setGameModeCalled)
        XCTAssertEqual(mockGameFeature.lastGameMode, .practice)
        XCTAssertTrue(mockGameFeature.startGameCalled)
    }
    
    func testPracticeFeature_ShowsEducationalContent() {
        // Given
        practiceFeature.showEducationalContent = true
        
        // When
        let hasEducationalFeatures = practiceFeature.hasEducationalFeatures
        
        // Then
        XCTAssertTrue(hasEducationalFeatures)
    }
}

// MARK: - Mock Classes for Game Mode Tests

@MainActor
class MockGameFeature: ObservableObject {
    @Published var gameState: GameState = .idle
    @Published var currentMode: GameMode = .practice
    
    var setGameModeCalled = false
    var startGameCalled = false
    var lastGameMode: GameMode?
    
    func setGameMode(_ mode: GameMode) {
        setGameModeCalled = true
        lastGameMode = mode
        currentMode = mode
    }
    
    func startGame() async {
        startGameCalled = true
        gameState = .playing
    }
}

// MARK: - Feature Classes

@MainActor
class PracticeFeature: ObservableObject {
    @Published var showEducationalContent = true
    @Published var enableHints = true
    
    private let gameFeature: GameFeature
    
    var hasEducationalFeatures: Bool {
        return showEducationalContent || enableHints
    }
    
    init(gameFeature: GameFeature) {
        self.gameFeature = gameFeature
    }
    
    func startPractice() {
        gameFeature.setGameMode(.practice)
        Task {
            await gameFeature.startGame()
        }
    }
    
    func toggleEducationalContent() {
        showEducationalContent.toggle()
    }
    
    func toggleHints() {
        enableHints.toggle()
    }
}
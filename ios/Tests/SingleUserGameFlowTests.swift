import XCTest
import SwiftUI
import ComposableArchitecture
@testable import BotanyBattle

@MainActor
final class SingleUserGameFlowTests: XCTestCase {
    
    var store: TestStoreOf<GameFeature>!
    
    override func setUp() {
        super.setUp()
        store = TestStore(
            initialState: GameFeature.State(),
            reducer: { GameFeature() },
            withDependencies: {
                $0.singleUserGameService = MockSingleUserGameService()
                $0.personalBestService = MockPersonalBestService()
                $0.gameTimerService = MockGameTimerService()
                $0.gameTimerValidationService = MockGameTimerValidationService()
                $0.gameTimerPersistenceService = MockGameTimerPersistenceService()
                $0.beatTheClockService = MockBeatTheClockService()
                $0.speedrunService = MockSpeedrunService()
                $0.trophyService = MockTrophyService()
            }
        )
    }
    
    override func tearDown() {
        store = nil
        super.tearDown()
    }
    
    // MARK: - Complete Beat the Clock Flow
    
    func testCompleteBeatTheClockFlow() async {
        // Start with mode selection
        XCTAssertTrue(store.state.showModeSelection)
        
        // Start beat the clock game
        await store.send(.startSingleUserGame(.beatTheClock, .medium)) {
            $0.selectedGameMode = .beatTheClock
            $0.selectedDifficulty = .medium
            $0.showModeSelection = false
            $0.singleUserSession = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
            $0.totalGameTime = 0
            $0.isPaused = false
        }
        
        await store.receive(.singleUserGameStarted(SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)))
        await store.receive(.loadNextQuestion)
        
        // Load a question
        let plant = Plant(
            id: "test-plant",
            commonName: "Test Plant",
            scientificName: "Testus plantus",
            imageURLs: ["https://example.com/plant.jpg"],
            description: "A test plant",
            facts: ["Interesting fact"],
            difficulty: .medium,
            family: "Testaceae"
        )
        
        await store.send(.questionLoaded(plant, ["Test Plant", "Wrong Plant", "Other Plant", "Another Plant"])) {
            $0.currentQuestion = (plant: plant, options: ["Test Plant", "Wrong Plant", "Other Plant", "Another Plant"])
        }
        
        // Answer correctly
        await store.send(.submitAnswer("Test Plant")) {
            $0.selectedAnswer = "Test Plant"
        }
        
        await store.receive(.loadNextQuestion)
        
        // Simulate timer updates
        let timerUpdate = GameTimerUpdate(
            totalTime: 30.0,
            timeRemaining: 30.0,
            pausedTime: 0.0,
            isExpired: false
        )
        
        await store.send(.timerUpdate(timerUpdate)) {
            $0.totalGameTime = 30.0
            $0.gameTimeRemaining = 30.0
        }
        
        // Simulate game completion by timer expiry
        let expiredUpdate = GameTimerUpdate(
            totalTime: 60.0,
            timeRemaining: 0.0,
            pausedTime: 0.0,
            isExpired: true
        )
        
        await store.send(.timerUpdate(expiredUpdate)) {
            $0.totalGameTime = 60.0
            $0.gameTimeRemaining = 60.0
        }
        
        // Should trigger game completion
        await store.receive(.beatTheClockGameCompleted(BeatTheClockScore(
            id: "mock-score",
            difficulty: .medium,
            correctAnswers: 10,
            totalAnswers: 12,
            timeUsed: 60.0,
            accuracy: 0.83,
            pointsPerSecond: 0.17,
            achievedAt: Date(),
            isNewRecord: false
        )))
        
        await store.receive(.loadBeatTheClockPersonalBest(.medium))
        await store.receive(.loadBeatTheClockLeaderboard(.medium))
        await store.receive(.showGameResults) {
            $0.showResults = true
        }
        
        // Return to menu
        await store.send(.hideGameResults) {
            $0.showResults = false
            $0.showModeSelection = true
        }
    }
    
    // MARK: - Complete Speedrun Flow
    
    func testCompleteSpeedrunFlow() async {
        // Start speedrun game
        await store.send(.startSingleUserGame(.speedrun, .hard)) {
            $0.selectedGameMode = .speedrun
            $0.selectedDifficulty = .hard
            $0.singleUserSession = SingleUserGameSession(mode: .speedrun, difficulty: .hard)
            $0.totalGameTime = 0
            $0.isPaused = false
        }
        
        await store.receive(.singleUserGameStarted(SingleUserGameSession(mode: .speedrun, difficulty: .hard)))
        await store.receive(.loadNextQuestion)
        
        // Simulate answering 25 questions
        let plant = Plant(
            id: "test-plant",
            commonName: "Test Plant",
            scientificName: "Testus plantus",
            imageURLs: ["https://example.com/plant.jpg"],
            description: "A test plant",
            facts: ["Interesting fact"],
            difficulty: .hard,
            family: "Testaceae"
        )
        
        await store.send(.questionLoaded(plant, ["Test Plant", "Wrong Plant", "Other Plant", "Another Plant"])) {
            $0.currentQuestion = (plant: plant, options: ["Test Plant", "Wrong Plant", "Other Plant", "Another Plant"])
        }
        
        // Simulate completing all 25 questions
        var session = SingleUserGameSession(mode: .speedrun, difficulty: .hard)
        session.correctAnswers = 25
        session.questionsAnswered = 25
        session.totalGameTime = 95.5
        session.state = .completed
        
        store.state.singleUserSession = session
        
        let speedrunScore = SpeedrunScore(
            id: "test-speedrun",
            difficulty: .hard,
            correctAnswers: 25,
            totalQuestions: 25,
            completionTime: 95.5,
            accuracy: 1.0,
            rating: 1250.0,
            achievedAt: Date(),
            isNewRecord: true
        )
        
        await store.send(.speedrunGameCompleted(speedrunScore)) {
            $0.speedrunScore = speedrunScore
            $0.currentQuestion = nil
            $0.isPaused = false
            $0.singleUserSession = nil
        }
        
        await store.receive(.loadSpeedrunPersonalBest(.hard))
        await store.receive(.loadSpeedrunLeaderboard(.hard))
        await store.receive(.showGameResults) {
            $0.showResults = true
        }
    }
    
    // MARK: - Game Pause/Resume Flow
    
    func testGamePauseResumeFlow() async {
        // Start game
        await store.send(.startSingleUserGame(.beatTheClock, .easy)) {
            $0.singleUserSession = SingleUserGameSession(mode: .beatTheClock, difficulty: .easy)
            $0.isPaused = false
        }
        
        await store.receive(.singleUserGameStarted(SingleUserGameSession(mode: .beatTheClock, difficulty: .easy)))
        await store.receive(.loadNextQuestion)
        
        // Pause game
        await store.send(.pauseGame) {
            $0.isPaused = true
            $0.singleUserSession?.state = .paused
        }
        
        // Resume game
        await store.send(.resumeGame) {
            $0.isPaused = false
            $0.singleUserSession?.state = .active
        }
        
        // Leave game
        await store.send(.leaveGame) {
            $0.singleUserSession = nil
            $0.currentQuestion = nil
            $0.isPaused = false
            $0.showModeSelection = true
        }
    }
    
    // MARK: - Navigation Flow Tests
    
    func testModeSelectionFlow() async {
        // Initially should show mode selection
        XCTAssertTrue(store.state.showModeSelection)
        
        // Hide mode selection when starting game
        await store.send(.startSingleUserGame(.speedrun, .medium)) {
            $0.showModeSelection = false
            $0.singleUserSession = SingleUserGameSession(mode: .speedrun, difficulty: .medium)
        }
        
        await store.receive(.singleUserGameStarted(SingleUserGameSession(mode: .speedrun, difficulty: .medium)))
        await store.receive(.loadNextQuestion)
        
        // Show mode selection when leaving game
        await store.send(.leaveGame) {
            $0.showModeSelection = true
            $0.singleUserSession = nil
        }
    }
    
    // MARK: - Error Handling Flow
    
    func testGameErrorHandling() async {
        // Start game
        await store.send(.startSingleUserGame(.beatTheClock, .medium)) {
            $0.singleUserSession = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
        }
        
        await store.receive(.singleUserGameStarted(SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)))
        await store.receive(.loadNextQuestion)
        
        // Simulate error
        await store.send(.gameError("Test error")) {
            $0.error = "Test error"
            $0.isSearchingForGame = false
        }
        
        // Clear error
        await store.send(.clearError) {
            $0.error = nil
        }
    }
    
    // MARK: - Trophy Integration Flow
    
    func testTrophyIntegrationFlow() async {
        // Complete a game and verify trophy calculation
        var session = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
        session.correctAnswers = 18
        session.questionsAnswered = 20
        session.totalGameTime = 60.0
        session.state = .completed
        
        store.state.singleUserSession = session
        
        let score = BeatTheClockScore(
            id: "trophy-test",
            difficulty: .medium,
            correctAnswers: 18,
            totalAnswers: 20,
            timeUsed: 60.0,
            accuracy: 0.9,
            pointsPerSecond: 0.3,
            achievedAt: Date(),
            isNewRecord: true
        )
        
        await store.send(.beatTheClockGameCompleted(score)) {
            $0.beatTheClockScore = score
            $0.singleUserSession = nil
            // Should calculate trophies
            $0.trophyReward = TrophyReward(
                totalTrophies: 200,
                breakdown: TrophyBreakdown(
                    baseTrophies: 90,
                    accuracyBonus: 50,
                    streakBonus: 25,
                    speedBonus: 0,
                    completionBonus: 75,
                    difficultyMultiplier: 1.0,
                    finalAmount: 200
                )
            )
        }
        
        await store.receive(.loadBeatTheClockPersonalBest(.medium))
        await store.receive(.loadBeatTheClockLeaderboard(.medium))
        await store.receive(.showGameResults) {
            $0.showResults = true
        }
        
        // Verify trophy reward is available for display
        XCTAssertNotNil(store.state.trophyReward)
        XCTAssertEqual(store.state.trophyReward?.totalTrophies, 200)
    }
    
    // MARK: - Personal Best Integration Flow
    
    func testPersonalBestFlow() async {
        // Load personal bests
        await store.send(.loadPersonalBests)
        
        await store.receive(.personalBestsLoaded([])) {
            $0.personalBests = []
        }
        
        // Complete a game that should set new personal best
        var session = SingleUserGameSession(mode: .speedrun, difficulty: .expert)
        session.correctAnswers = 24
        session.questionsAnswered = 25
        session.totalGameTime = 88.0
        session.state = .completed
        
        store.state.singleUserSession = session
        
        let score = SpeedrunScore(
            id: "pb-test",
            difficulty: .expert,
            correctAnswers: 24,
            totalQuestions: 25,
            completionTime: 88.0,
            accuracy: 0.96,
            rating: 1180.0,
            achievedAt: Date(),
            isNewRecord: true
        )
        
        await store.send(.speedrunGameCompleted(score)) {
            $0.speedrunScore = score
            $0.singleUserSession = nil
        }
        
        await store.receive(.loadSpeedrunPersonalBest(.expert))
        await store.receive(.loadSpeedrunLeaderboard(.expert))
        await store.receive(.showGameResults)
        
        // Personal best should be loaded for display
        await store.send(.loadPersonalBests)
        
        // Mock service should now include the new personal best
        await store.receive(.personalBestsLoaded([PersonalBest(
            id: "pb-test",
            mode: .speedrun,
            difficulty: .expert,
            score: 1180,
            correctAnswers: 24,
            totalGameTime: 88.0,
            accuracy: 0.96,
            achievedAt: Date()
        )])) {
            $0.personalBests = [PersonalBest(
                id: "pb-test",
                mode: .speedrun,
                difficulty: .expert,
                score: 1180,
                correctAnswers: 24,
                totalGameTime: 88.0,
                accuracy: 0.96,
                achievedAt: Date()
            )]
        }
    }
    
    // MARK: - State Consistency Tests
    
    func testStateConsistencyDuringFlow() async {
        // Verify initial state
        XCTAssertTrue(store.state.showModeSelection)
        XCTAssertNil(store.state.singleUserSession)
        XCTAssertNil(store.state.currentQuestion)
        XCTAssertFalse(store.state.isPaused)
        XCTAssertFalse(store.state.showResults)
        
        // Start game - verify state changes
        await store.send(.startSingleUserGame(.beatTheClock, .medium)) {
            // Mode selection should be hidden
            $0.showModeSelection = false
            // Session should be created
            $0.singleUserSession = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
            // Game should not be paused
            $0.isPaused = false
            // Results should not be shown
            $0.showResults = false
        }
        
        await store.receive(.singleUserGameStarted(SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)))
        await store.receive(.loadNextQuestion)
        
        // During game - verify consistent state
        XCTAssertFalse(store.state.showModeSelection)
        XCTAssertNotNil(store.state.singleUserSession)
        XCTAssertFalse(store.state.showResults)
        
        // Complete game - verify final state
        let score = BeatTheClockScore(
            id: "consistency-test",
            difficulty: .medium,
            correctAnswers: 12,
            totalAnswers: 15,
            timeUsed: 60.0,
            accuracy: 0.8,
            pointsPerSecond: 0.2,
            achievedAt: Date(),
            isNewRecord: false
        )
        
        store.state.singleUserSession = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
        
        await store.send(.beatTheClockGameCompleted(score)) {
            $0.beatTheClockScore = score
            $0.singleUserSession = nil // Should be cleared
            $0.currentQuestion = nil
            $0.isPaused = false
        }
        
        await store.receive(.loadBeatTheClockPersonalBest(.medium))
        await store.receive(.loadBeatTheClockLeaderboard(.medium))
        await store.receive(.showGameResults) {
            $0.showResults = true // Should show results
        }
        
        // Return to mode selection
        await store.send(.hideGameResults) {
            $0.showResults = false
            $0.showModeSelection = true // Should return to mode selection
            $0.trophyReward = nil
            $0.beatTheClockScore = nil
        }
        
        // Verify we're back to initial state
        XCTAssertTrue(store.state.showModeSelection)
        XCTAssertNil(store.state.singleUserSession)
        XCTAssertNil(store.state.currentQuestion)
        XCTAssertFalse(store.state.isPaused)
        XCTAssertFalse(store.state.showResults)
    }
}
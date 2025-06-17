import XCTest
import ComposableArchitecture
@testable import BotanyBattle

@MainActor
final class SingleUserGameTests: XCTestCase {
    
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
    
    // MARK: - Beat the Clock Tests
    
    func testBeatTheClockGameStart() async {
        await store.send(.startSingleUserGame(.beatTheClock, .medium)) {
            $0.selectedGameMode = .beatTheClock
            $0.selectedDifficulty = .medium
            $0.error = nil
            $0.newPersonalBest = nil
            $0.totalGameTime = 0
            $0.isPaused = false
            $0.singleUserSession = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
        }
        
        await store.receive(.singleUserGameStarted(SingleUserGameSession(mode: .beatTheClock, difficulty: .medium))) {
            $0.singleUserSession = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
        }
        
        await store.receive(.loadNextQuestion)
    }
    
    func testBeatTheClockGameCompletion() async {
        let session = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
        var completedSession = session
        completedSession.correctAnswers = 15
        completedSession.questionsAnswered = 18
        completedSession.totalGameTime = 60.0
        completedSession.state = .completed
        
        let score = BeatTheClockScore(
            id: "test-score",
            difficulty: .medium,
            correctAnswers: 15,
            totalAnswers: 18,
            timeUsed: 60.0,
            accuracy: 0.833,
            pointsPerSecond: 0.25,
            achievedAt: Date(),
            isNewRecord: true
        )
        
        store.state.singleUserSession = completedSession
        
        await store.send(.beatTheClockGameCompleted(score)) {
            $0.beatTheClockScore = score
            $0.currentQuestion = nil
            $0.isPaused = false
            $0.singleUserSession = nil
            $0.trophyReward = TrophyReward(
                totalTrophies: 200,
                breakdown: TrophyBreakdown(
                    baseTrophies: 75,
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
    }
    
    // MARK: - Speedrun Tests
    
    func testSpeedrunGameStart() async {
        await store.send(.startSingleUserGame(.speedrun, .hard)) {
            $0.selectedGameMode = .speedrun
            $0.selectedDifficulty = .hard
            $0.error = nil
            $0.newPersonalBest = nil
            $0.totalGameTime = 0
            $0.isPaused = false
            $0.singleUserSession = SingleUserGameSession(mode: .speedrun, difficulty: .hard)
        }
        
        await store.receive(.singleUserGameStarted(SingleUserGameSession(mode: .speedrun, difficulty: .hard))) {
            $0.singleUserSession = SingleUserGameSession(mode: .speedrun, difficulty: .hard)
        }
        
        await store.receive(.loadNextQuestion)
    }
    
    func testSpeedrunGameCompletion() async {
        let session = SingleUserGameSession(mode: .speedrun, difficulty: .hard)
        var completedSession = session
        completedSession.correctAnswers = 25
        completedSession.questionsAnswered = 25
        completedSession.totalGameTime = 95.5
        completedSession.state = .completed
        
        let score = SpeedrunScore(
            id: "test-speedrun",
            difficulty: .hard,
            correctAnswers: 25,
            totalQuestions: 25,
            completionTime: 95.5,
            accuracy: 1.0,
            rating: 1250.0,
            achievedAt: Date(),
            isNewRecord: false
        )
        
        store.state.singleUserSession = completedSession
        
        await store.send(.speedrunGameCompleted(score)) {
            $0.speedrunScore = score
            $0.currentQuestion = nil
            $0.isPaused = false
            $0.singleUserSession = nil
            $0.trophyReward = TrophyReward(
                totalTrophies: 200,
                breakdown: TrophyBreakdown(
                    baseTrophies: 200,
                    accuracyBonus: 100,
                    streakBonus: 25,
                    speedBonus: 40,
                    completionBonus: 150,
                    difficultyMultiplier: 1.3,
                    finalAmount: 200
                )
            )
        }
        
        await store.receive(.loadSpeedrunPersonalBest(.hard))
        await store.receive(.loadSpeedrunLeaderboard(.hard))
        await store.receive(.showGameResults) {
            $0.showResults = true
        }
    }
    
    // MARK: - Answer Submission Tests
    
    func testCorrectAnswerSubmission() async {
        let session = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
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
        
        store.state.singleUserSession = session
        store.state.currentQuestion = (plant: plant, options: ["Test Plant", "Other Plant", "Third Plant", "Fourth Plant"])
        
        await store.send(.submitAnswer("Test Plant")) {
            $0.selectedAnswer = "Test Plant"
        }
        
        await store.receive(.loadNextQuestion)
    }
    
    func testIncorrectAnswerSubmission() async {
        let session = SingleUserGameSession(mode: .speedrun, difficulty: .easy)
        let plant = Plant(
            id: "test-plant",
            commonName: "Test Plant",
            scientificName: "Testus plantus",
            imageURLs: ["https://example.com/plant.jpg"],
            description: "A test plant",
            facts: ["Interesting fact"],
            difficulty: .easy,
            family: "Testaceae"
        )
        
        store.state.singleUserSession = session
        store.state.currentQuestion = (plant: plant, options: ["Test Plant", "Wrong Plant", "Third Plant", "Fourth Plant"])
        
        await store.send(.submitAnswer("Wrong Plant")) {
            $0.selectedAnswer = "Wrong Plant"
        }
        
        await store.receive(.loadNextQuestion)
    }
    
    // MARK: - Game State Tests
    
    func testGamePauseResume() async {
        let session = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
        store.state.singleUserSession = session
        
        await store.send(.pauseGame) {
            $0.isPaused = true
            $0.singleUserSession?.state = .paused
        }
        
        await store.send(.resumeGame) {
            $0.isPaused = false
            $0.singleUserSession?.state = .active
        }
    }
    
    func testGameLeave() async {
        let session = SingleUserGameSession(mode: .speedrun, difficulty: .hard)
        store.state.singleUserSession = session
        store.state.currentQuestion = (
            plant: Plant(
                id: "test",
                commonName: "Test",
                scientificName: "Test",
                imageURLs: [],
                description: "",
                facts: [],
                difficulty: .medium,
                family: ""
            ),
            options: []
        )
        
        await store.send(.leaveGame) {
            $0.currentGame = nil
            $0.currentRound = nil
            $0.singleUserSession = nil
            $0.currentQuestion = nil
            $0.isSearchingForGame = false
            $0.hasAnswered = false
            $0.selectedAnswer = nil
            $0.isPaused = false
            $0.newPersonalBest = nil
            $0.showModeSelection = true
        }
    }
    
    // MARK: - Results Screen Tests
    
    func testShowHideResults() async {
        await store.send(.showGameResults) {
            $0.showResults = true
        }
        
        await store.send(.hideGameResults) {
            $0.showResults = false
            $0.trophyReward = nil
            $0.beatTheClockScore = nil
            $0.speedrunScore = nil
            $0.newPersonalBest = nil
        }
    }
    
    // MARK: - Timer Integration Tests
    
    func testTimerUpdate() async {
        let session = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
        store.state.singleUserSession = session
        
        let timerUpdate = GameTimerUpdate(
            totalTime: 30.0,
            timeRemaining: 30.0,
            pausedTime: 0.0,
            isExpired: false
        )
        
        await store.send(.timerUpdate(timerUpdate)) {
            $0.totalGameTime = 30.0
            $0.gameTimeRemaining = 30.0
            $0.singleUserSession?.totalPausedTime = 0.0
        }
    }
    
    func testTimerExpiry() async {
        let session = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
        var expiredSession = session
        expiredSession.totalGameTime = 60.0
        store.state.singleUserSession = expiredSession
        
        let expiredUpdate = GameTimerUpdate(
            totalTime: 60.0,
            timeRemaining: 0.0,
            pausedTime: 0.0,
            isExpired: true
        )
        
        await store.send(.timerUpdate(expiredUpdate)) {
            $0.totalGameTime = 60.0
            $0.gameTimeRemaining = 60.0
            $0.singleUserSession?.totalPausedTime = 0.0
        }
        
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
    }
}
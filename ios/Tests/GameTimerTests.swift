import XCTest
import Dependencies
@testable import BotanyBattle

final class GameTimerTests: XCTestCase {
    
    var timerService: GameTimerService!
    var validationService: GameTimerValidationService!
    var persistenceService: GameTimerPersistenceService!
    
    override func setUp() {
        super.setUp()
        timerService = GameTimerService()
        validationService = GameTimerValidationService()
        persistenceService = GameTimerPersistenceService()
    }
    
    override func tearDown() {
        timerService = nil
        validationService = nil
        persistenceService = nil
        super.tearDown()
    }
    
    // MARK: - Timer Validation Tests
    
    func testValidTimerState() {
        let session = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
        let timerUpdate = GameTimerUpdate(
            totalTime: 30.0,
            timeRemaining: 30.0,
            pausedTime: 0.0,
            isExpired: false
        )
        
        let validation = validationService.validateTimerState(session: session, timerUpdate: timerUpdate)
        
        XCTAssertTrue(validation.isValid)
        XCTAssertTrue(validation.warnings.isEmpty)
        XCTAssertNil(validation.adjustedTime)
    }
    
    func testInvalidTimerState_NegativeTime() {
        let session = SingleUserGameSession(mode: .speedrun, difficulty: .hard)
        let timerUpdate = GameTimerUpdate(
            totalTime: -5.0,
            timeRemaining: 0.0,
            pausedTime: 0.0,
            isExpired: false
        )
        
        let validation = validationService.validateTimerState(session: session, timerUpdate: timerUpdate)
        
        XCTAssertFalse(validation.isValid)
        XCTAssertFalse(validation.warnings.isEmpty)
        XCTAssertNotNil(validation.adjustedTime)
        XCTAssertEqual(validation.adjustedTime, 0.0)
    }
    
    func testInvalidTimerState_ExcessiveTime() {
        let session = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
        let timerUpdate = GameTimerUpdate(
            totalTime: 120.0, // More than 60 seconds for beat the clock
            timeRemaining: -60.0,
            pausedTime: 0.0,
            isExpired: true
        )
        
        let validation = validationService.validateTimerState(session: session, timerUpdate: timerUpdate)
        
        XCTAssertFalse(validation.isValid)
        XCTAssertFalse(validation.warnings.isEmpty)
        XCTAssertTrue(validation.warnings.contains { $0.contains("Excessive time") })
    }
    
    func testTimerManipulationDetection() {
        let session = SingleUserGameSession(mode: .speedrun, difficulty: .easy)
        let timerUpdate = GameTimerUpdate(
            totalTime: 5.0, // Suspiciously fast for 25 questions
            timeRemaining: 0.0,
            pausedTime: 0.0,
            isExpired: false
        )
        
        let validation = validationService.validateTimerState(session: session, timerUpdate: timerUpdate)
        
        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.warnings.contains { $0.contains("Suspiciously fast") })
    }
    
    // MARK: - Timer Persistence Tests
    
    func testSaveAndLoadTimerState() {
        let persistenceState = TimerPersistenceState(
            sessionId: "test-session",
            mode: .beatTheClock,
            startTime: Date(),
            totalPausedTime: 5.0,
            wasActive: true,
            lastSaveTime: Date(),
            questionsAnswered: 10,
            correctAnswers: 8
        )
        
        persistenceService.saveTimerState(persistenceState)
        let loaded = persistenceService.loadTimerState(sessionId: "test-session")
        
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.sessionId, "test-session")
        XCTAssertEqual(loaded?.mode, .beatTheClock)
        XCTAssertEqual(loaded?.totalPausedTime, 5.0)
        XCTAssertEqual(loaded?.questionsAnswered, 10)
        XCTAssertEqual(loaded?.correctAnswers, 8)
    }
    
    func testLoadNonexistentTimerState() {
        let loaded = persistenceService.loadTimerState(sessionId: "nonexistent")
        XCTAssertNil(loaded)
    }
    
    func testClearTimerState() {
        let persistenceState = TimerPersistenceState(
            sessionId: "test-clear",
            mode: .speedrun,
            startTime: Date(),
            totalPausedTime: 0.0,
            wasActive: false,
            lastSaveTime: Date(),
            questionsAnswered: 0,
            correctAnswers: 0
        )
        
        persistenceService.saveTimerState(persistenceState)
        XCTAssertNotNil(persistenceService.loadTimerState(sessionId: "test-clear"))
        
        persistenceService.clearTimerState(sessionId: "test-clear")
        XCTAssertNil(persistenceService.loadTimerState(sessionId: "test-clear"))
    }
    
    // MARK: - Timer Service Edge Cases
    
    func testTimerServicePauseResume() {
        // This test would ideally use a mock clock to test pause/resume behavior
        // For now, we test the basic interface
        
        timerService.pauseTimer()
        // Timer should be paused
        
        timerService.resumeTimer()
        // Timer should be resumed
        
        timerService.stopTimer()
        // Timer should be stopped
    }
    
    // MARK: - Game Mode Specific Timer Tests
    
    func testBeatTheClockTimerBounds() {
        let session = SingleUserGameSession(mode: .beatTheClock, difficulty: .medium)
        
        // Test within bounds
        let validUpdate = GameTimerUpdate(
            totalTime: 45.0,
            timeRemaining: 15.0,
            pausedTime: 2.0,
            isExpired: false
        )
        
        let validation1 = validationService.validateTimerState(session: session, timerUpdate: validUpdate)
        XCTAssertTrue(validation1.isValid)
        
        // Test expired
        let expiredUpdate = GameTimerUpdate(
            totalTime: 60.0,
            timeRemaining: 0.0,
            pausedTime: 0.0,
            isExpired: true
        )
        
        let validation2 = validationService.validateTimerState(session: session, timerUpdate: expiredUpdate)
        XCTAssertTrue(validation2.isValid) // Expired is valid for beat the clock
    }
    
    func testSpeedrunTimerValidation() {
        let session = SingleUserGameSession(mode: .speedrun, difficulty: .hard)
        
        // Test reasonable time
        let reasonableUpdate = GameTimerUpdate(
            totalTime: 120.0,
            timeRemaining: 0.0,
            pausedTime: 10.0,
            isExpired: false
        )
        
        let validation1 = validationService.validateTimerState(session: session, timerUpdate: reasonableUpdate)
        XCTAssertTrue(validation1.isValid)
        
        // Test unreasonably fast time
        let fastUpdate = GameTimerUpdate(
            totalTime: 10.0, // 10 seconds for 25 questions is impossible
            timeRemaining: 0.0,
            pausedTime: 0.0,
            isExpired: false
        )
        
        let validation2 = validationService.validateTimerState(session: session, timerUpdate: fastUpdate)
        XCTAssertFalse(validation2.isValid)
    }
    
    // MARK: - Recovery Tests
    
    func testTimerRecoveryAfterAppRestart() {
        let sessionId = "recovery-test"
        let startTime = Date().addingTimeInterval(-30) // Started 30 seconds ago
        
        let persistenceState = TimerPersistenceState(
            sessionId: sessionId,
            mode: .beatTheClock,
            startTime: startTime,
            totalPausedTime: 5.0,
            wasActive: true,
            lastSaveTime: Date().addingTimeInterval(-5), // Last saved 5 seconds ago
            questionsAnswered: 8,
            correctAnswers: 6
        )
        
        persistenceService.saveTimerState(persistenceState)
        
        // Simulate app restart and recovery
        let recovered = persistenceService.loadTimerState(sessionId: sessionId)
        XCTAssertNotNil(recovered)
        
        // Verify recovery state
        XCTAssertEqual(recovered?.mode, .beatTheClock)
        XCTAssertEqual(recovered?.totalPausedTime, 5.0)
        XCTAssertEqual(recovered?.questionsAnswered, 8)
        XCTAssertEqual(recovered?.correctAnswers, 6)
        
        // Calculate elapsed time since start
        let elapsedTime = Date().timeIntervalSince(startTime)
        XCTAssertGreaterThan(elapsedTime, 25.0) // Should be around 30 seconds
        XCTAssertLessThan(elapsedTime, 35.0)
    }
    
    // MARK: - Anti-Cheat Tests
    
    func testSystemClockManipulationDetection() {
        let session = SingleUserGameSession(mode: .speedrun, difficulty: .medium)
        
        // Simulate clock manipulation (time going backwards)
        let manipulatedUpdate = GameTimerUpdate(
            totalTime: -10.0,
            timeRemaining: 0.0,
            pausedTime: 0.0,
            isExpired: false
        )
        
        let validation = validationService.validateTimerState(session: session, timerUpdate: manipulatedUpdate)
        
        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.warnings.contains { $0.contains("Clock manipulation") || $0.contains("Negative time") })
        XCTAssertNotNil(validation.adjustedTime)
    }
    
    func testRapidFireAnswerDetection() {
        let session = SingleUserGameSession(mode: .beatTheClock, difficulty: .expert)
        
        // Simulate impossibly fast answer rate (25 questions in 5 seconds)
        let impossibleUpdate = GameTimerUpdate(
            totalTime: 5.0,
            timeRemaining: 55.0,
            pausedTime: 0.0,
            isExpired: false
        )
        
        let validation = validationService.validateTimerState(session: session, timerUpdate: impossibleUpdate)
        
        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.warnings.contains { $0.contains("Suspiciously fast") })
    }
}
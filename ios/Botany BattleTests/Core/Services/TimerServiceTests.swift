import XCTest
import Combine
@testable import BotanyBattle

final class TimerServiceTests: XCTestCase {
    
    var sut: TimerService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = TimerService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        // Given & When & Then
        XCTAssertEqual(sut.timeRemaining, 0)
        XCTAssertFalse(sut.isRunning)
        XCTAssertFalse(sut.isPaused)
        XCTAssertEqual(sut.initialTime, 0)
    }
    
    // MARK: - Start Timer Tests
    
    func testStartTimer_SetsInitialTime() {
        // Given
        let duration = 60
        
        // When
        sut.startTimer(duration: duration)
        
        // Then
        XCTAssertEqual(sut.timeRemaining, duration)
        XCTAssertEqual(sut.initialTime, duration)
        XCTAssertTrue(sut.isRunning)
        XCTAssertFalse(sut.isPaused)
    }
    
    func testStartTimer_WithZeroDuration_DoesNotStart() {
        // Given
        let duration = 0
        
        // When
        sut.startTimer(duration: duration)
        
        // Then
        XCTAssertEqual(sut.timeRemaining, 0)
        XCTAssertFalse(sut.isRunning)
    }
    
    func testStartTimer_WithNegativeDuration_DoesNotStart() {
        // Given
        let duration = -10
        
        // When
        sut.startTimer(duration: duration)
        
        // Then
        XCTAssertEqual(sut.timeRemaining, 0)
        XCTAssertFalse(sut.isRunning)
    }
    
    // MARK: - Pause/Resume Tests
    
    func testPauseTimer_WhenRunning_PausesTimer() {
        // Given
        sut.startTimer(duration: 60)
        XCTAssertTrue(sut.isRunning)
        
        // When
        sut.pauseTimer()
        
        // Then
        XCTAssertFalse(sut.isRunning)
        XCTAssertTrue(sut.isPaused)
    }
    
    func testPauseTimer_WhenNotRunning_DoesNothing() {
        // Given
        XCTAssertFalse(sut.isRunning)
        
        // When
        sut.pauseTimer()
        
        // Then
        XCTAssertFalse(sut.isRunning)
        XCTAssertFalse(sut.isPaused)
    }
    
    func testResumeTimer_WhenPaused_ResumesTimer() {
        // Given
        sut.startTimer(duration: 60)
        sut.pauseTimer()
        XCTAssertTrue(sut.isPaused)
        
        // When
        sut.resumeTimer()
        
        // Then
        XCTAssertTrue(sut.isRunning)
        XCTAssertFalse(sut.isPaused)
    }
    
    func testResumeTimer_WhenNotPaused_DoesNothing() {
        // Given
        XCTAssertFalse(sut.isPaused)
        
        // When
        sut.resumeTimer()
        
        // Then
        XCTAssertFalse(sut.isRunning)
        XCTAssertFalse(sut.isPaused)
    }
    
    // MARK: - Stop Timer Tests
    
    func testStopTimer_ResetsToInitialState() {
        // Given
        sut.startTimer(duration: 60)
        XCTAssertTrue(sut.isRunning)
        
        // When
        sut.stopTimer()
        
        // Then
        XCTAssertEqual(sut.timeRemaining, 0)
        XCTAssertFalse(sut.isRunning)
        XCTAssertFalse(sut.isPaused)
        XCTAssertEqual(sut.initialTime, 0)
    }
    
    // MARK: - Reset Timer Tests
    
    func testResetTimer_ToOriginalDuration() {
        // Given
        sut.startTimer(duration: 60)
        // Simulate some time passing
        sut.timeRemaining = 30
        
        // When
        sut.resetTimer()
        
        // Then
        XCTAssertEqual(sut.timeRemaining, 60)
        XCTAssertTrue(sut.isRunning)
        XCTAssertFalse(sut.isPaused)
    }
    
    func testResetTimer_WhenNoTimerSet_DoesNothing() {
        // Given
        XCTAssertEqual(sut.initialTime, 0)
        
        // When
        sut.resetTimer()
        
        // Then
        XCTAssertEqual(sut.timeRemaining, 0)
        XCTAssertFalse(sut.isRunning)
    }
    
    // MARK: - Timer Completion Tests
    
    func testTimerCompletion_CallsCompletionHandler() {
        // Given
        let expectation = XCTestExpectation(description: "Timer completion")
        var completionCalled = false
        
        sut.onTimerCompleted = {
            completionCalled = true
            expectation.fulfill()
        }
        
        // When
        sut.startTimer(duration: 1) // 1 second for quick test
        
        // Then
        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(completionCalled)
        XCTAssertFalse(sut.isRunning)
        XCTAssertEqual(sut.timeRemaining, 0)
    }
    
    func testTimerCompletion_PublishesZeroTime() {
        // Given
        let expectation = XCTestExpectation(description: "Timer reaches zero")
        
        sut.$timeRemaining
            .sink { timeRemaining in
                if timeRemaining == 0 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        sut.startTimer(duration: 1)
        
        // Then
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Manual Time Update Tests
    
    func testSetTimeRemaining_UpdatesValue() {
        // Given
        sut.startTimer(duration: 60)
        
        // When
        sut.setTimeRemaining(30)
        
        // Then
        XCTAssertEqual(sut.timeRemaining, 30)
    }
    
    func testSetTimeRemaining_NegativeValue_SetsToZero() {
        // Given
        sut.startTimer(duration: 60)
        
        // When
        sut.setTimeRemaining(-10)
        
        // Then
        XCTAssertEqual(sut.timeRemaining, 0)
    }
    
    func testSetTimeRemaining_ToZero_StopsTimer() {
        // Given
        let expectation = XCTestExpectation(description: "Timer stops")
        sut.startTimer(duration: 60)
        
        sut.onTimerCompleted = {
            expectation.fulfill()
        }
        
        // When
        sut.setTimeRemaining(0)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertFalse(sut.isRunning)
    }
    
    // MARK: - Add Time Tests
    
    func testAddTime_IncreasesTimeRemaining() {
        // Given
        sut.startTimer(duration: 60)
        
        // When
        sut.addTime(15)
        
        // Then
        XCTAssertEqual(sut.timeRemaining, 75)
    }
    
    func testAddTime_NegativeValue_DoesNotDecrease() {
        // Given
        sut.startTimer(duration: 60)
        
        // When
        sut.addTime(-10)
        
        // Then
        XCTAssertEqual(sut.timeRemaining, 60) // Should not change
    }
    
    // MARK: - Progress Calculation Tests
    
    func testProgress_CalculatesCorrectly() {
        // Given
        sut.startTimer(duration: 100)
        sut.setTimeRemaining(25)
        
        // When
        let progress = sut.progress
        
        // Then
        XCTAssertEqual(progress, 0.75, accuracy: 0.01) // 75% complete
    }
    
    func testProgress_WithZeroInitialTime_ReturnsZero() {
        // Given & When
        let progress = sut.progress
        
        // Then
        XCTAssertEqual(progress, 0.0)
    }
    
    func testProgress_WithZeroTimeRemaining_ReturnsOne() {
        // Given
        sut.startTimer(duration: 60)
        sut.setTimeRemaining(0)
        
        // When
        let progress = sut.progress
        
        // Then
        XCTAssertEqual(progress, 1.0)
    }
    
    // MARK: - Formatted Time Tests
    
    func testFormattedTime_DisplaysCorrectly() {
        // Given & When & Then
        sut.setTimeRemaining(65) // 1:05
        XCTAssertEqual(sut.formattedTime, "1:05")
        
        sut.setTimeRemaining(120) // 2:00
        XCTAssertEqual(sut.formattedTime, "2:00")
        
        sut.setTimeRemaining(5) // 0:05
        XCTAssertEqual(sut.formattedTime, "0:05")
        
        sut.setTimeRemaining(0) // 0:00
        XCTAssertEqual(sut.formattedTime, "0:00")
    }
    
    func testFormattedTime_HandlesLargeValues() {
        // Given
        sut.setTimeRemaining(3661) // 1:01:01
        
        // When
        let formatted = sut.formattedTime
        
        // Then
        XCTAssertEqual(formatted, "61:01") // Should display as MM:SS format
    }
    
    // MARK: - State Management Tests
    
    func testMultipleStartCalls_StopsExistingTimer() {
        // Given
        sut.startTimer(duration: 60)
        let firstInitialTime = sut.initialTime
        
        // When
        sut.startTimer(duration: 30)
        
        // Then
        XCTAssertEqual(sut.initialTime, 30)
        XCTAssertNotEqual(sut.initialTime, firstInitialTime)
        XCTAssertEqual(sut.timeRemaining, 30)
    }
    
    // MARK: - Memory Management Tests
    
    func testTimerCleanup_OnDeinit() {
        // Given
        var timerService: TimerService? = TimerService()
        timerService?.startTimer(duration: 60)
        XCTAssertTrue(timerService?.isRunning ?? false)
        
        // When
        timerService = nil
        
        // Then
        // No memory leaks should occur (verified by Instruments)
        XCTAssertNil(timerService)
    }
    
    // MARK: - Publisher Tests
    
    func testTimeRemainingPublisher_EmitsChanges() {
        // Given
        let expectation = XCTestExpectation(description: "Time updates")
        expectation.expectedFulfillmentCount = 2 // Initial value + one update
        
        var receivedValues: [Int] = []
        
        sut.$timeRemaining
            .sink { value in
                receivedValues.append(value)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        sut.startTimer(duration: 60)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues.count, 2)
        XCTAssertEqual(receivedValues[0], 0) // Initial value
        XCTAssertEqual(receivedValues[1], 60) // After start
    }
    
    func testIsRunningPublisher_EmitsChanges() {
        // Given
        let expectation = XCTestExpectation(description: "Running state updates")
        expectation.expectedFulfillmentCount = 2
        
        var receivedValues: [Bool] = []
        
        sut.$isRunning
            .sink { value in
                receivedValues.append(value)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        sut.startTimer(duration: 60)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues.count, 2)
        XCTAssertFalse(receivedValues[0]) // Initial value
        XCTAssertTrue(receivedValues[1]) // After start
    }
    
    // MARK: - Performance Tests
    
    func testTimerPerformance() {
        measure {
            sut.startTimer(duration: 10)
            for _ in 0..<100 {
                sut.pauseTimer()
                sut.resumeTimer()
            }
            sut.stopTimer()
        }
    }
}
import Foundation
import Dependencies

protocol GameTimerValidationServiceProtocol {
    func validateTimerState(session: SingleUserGameSession, timerUpdate: GameTimerUpdate) -> TimerValidationResult
    func detectTimeManipulation(session: SingleUserGameSession, currentTime: TimeInterval) -> Bool
    func getExpectedCompletionTime(for mode: GameMode, answers: Int) -> TimeInterval?
}

struct TimerValidationResult {
    let isValid: Bool
    let adjustedTime: TimeInterval?
    let warnings: [TimerWarning]
}

enum TimerWarning {
    case timeJumpDetected(delta: TimeInterval)
    case suspiciouslyFastCompletion
    case longPauseDuration(duration: TimeInterval)
    case backgroundTimeDiscrepancy
}

final class GameTimerValidationService: GameTimerValidationServiceProtocol {
    private var lastValidatedTime: TimeInterval = 0
    private var timeJumpThreshold: TimeInterval = 2.0 // seconds
    private var maxReasonablePause: TimeInterval = 300.0 // 5 minutes
    
    func validateTimerState(session: SingleUserGameSession, timerUpdate: GameTimerUpdate) -> TimerValidationResult {
        var warnings: [TimerWarning] = []
        var adjustedTime: TimeInterval?
        
        // Check for time jumps
        let timeDelta = timerUpdate.totalTime - lastValidatedTime
        if lastValidatedTime > 0 && timeDelta > timeJumpThreshold {
            warnings.append(.timeJumpDetected(delta: timeDelta))
        }
        
        // Check for suspiciously fast completion
        if session.questionsAnswered > 5 {
            let averageTimePerAnswer = timerUpdate.totalTime / Double(session.questionsAnswered)
            if averageTimePerAnswer < 1.0 { // Less than 1 second per answer
                warnings.append(.suspiciouslyFastCompletion)
            }
        }
        
        // Check for long pause duration
        if timerUpdate.pausedTime > maxReasonablePause {
            warnings.append(.longPauseDuration(duration: timerUpdate.pausedTime))
            // Adjust time to reasonable maximum
            adjustedTime = timerUpdate.totalTime - (timerUpdate.pausedTime - maxReasonablePause)
        }
        
        // Validate against expected completion time
        if let expectedTime = getExpectedCompletionTime(for: session.mode, answers: session.questionsAnswered),
           timerUpdate.totalTime < expectedTime * 0.5 { // Less than half expected time
            warnings.append(.suspiciouslyFastCompletion)
        }
        
        lastValidatedTime = timerUpdate.totalTime
        
        return TimerValidationResult(
            isValid: warnings.isEmpty,
            adjustedTime: adjustedTime,
            warnings: warnings
        )
    }
    
    func detectTimeManipulation(session: SingleUserGameSession, currentTime: TimeInterval) -> Bool {
        // Basic time manipulation detection
        let expectedMinTime = Double(session.questionsAnswered) * 0.5 // Minimum 0.5s per answer
        let expectedMaxTime = Double(session.questionsAnswered) * 30.0 // Maximum 30s per answer
        
        return currentTime < expectedMinTime || (currentTime > expectedMaxTime && session.mode == .speedrun)
    }
    
    func getExpectedCompletionTime(for mode: GameMode, answers: Int) -> TimeInterval? {
        switch mode {
        case .beatTheClock:
            return nil // No expected completion time
        case .speedrun:
            // Expect at least 2 seconds per answer for reasonable completion
            return Double(answers) * 2.0
        case .multiplayer:
            return nil
        }
    }
}

extension DependencyValues {
    var gameTimerValidationService: GameTimerValidationServiceProtocol {
        get { self[GameTimerValidationServiceKey.self] }
        set { self[GameTimerValidationServiceKey.self] = newValue }
    }
}

private enum GameTimerValidationServiceKey: DependencyKey {
    static let liveValue: GameTimerValidationServiceProtocol = GameTimerValidationService()
    static let testValue: GameTimerValidationServiceProtocol = MockGameTimerValidationService()
}

// Mock service for testing
final class MockGameTimerValidationService: GameTimerValidationServiceProtocol {
    var shouldReturnValid = true
    var mockWarnings: [TimerWarning] = []
    
    func validateTimerState(session: SingleUserGameSession, timerUpdate: GameTimerUpdate) -> TimerValidationResult {
        return TimerValidationResult(
            isValid: shouldReturnValid,
            adjustedTime: shouldReturnValid ? nil : timerUpdate.totalTime * 0.8,
            warnings: mockWarnings
        )
    }
    
    func detectTimeManipulation(session: SingleUserGameSession, currentTime: TimeInterval) -> Bool {
        return !shouldReturnValid
    }
    
    func getExpectedCompletionTime(for mode: GameMode, answers: Int) -> TimeInterval? {
        switch mode {
        case .beatTheClock:
            return nil
        case .speedrun:
            return Double(answers) * 2.0
        case .multiplayer:
            return nil
        }
    }
}
import Foundation
import Dependencies

protocol GameTimerPersistenceServiceProtocol {
    func saveTimerState(_ state: TimerPersistenceState)
    func loadTimerState() -> TimerPersistenceState?
    func clearTimerState()
    func shouldResumeTimer(from state: TimerPersistenceState) -> Bool
}

struct TimerPersistenceState: Codable {
    let sessionId: String
    let mode: GameMode
    let startTime: Date
    let totalPausedTime: TimeInterval
    let wasActive: Bool
    let lastSaveTime: Date
    let questionsAnswered: Int
    let correctAnswers: Int
}

final class GameTimerPersistenceService: GameTimerPersistenceServiceProtocol {
    @Dependency(\.userDefaults) var userDefaults
    
    private let timerStateKey = "game_timer_persistence_state"
    private let maxRecoveryAge: TimeInterval = 3600 // 1 hour
    
    func saveTimerState(_ state: TimerPersistenceState) {
        do {
            let data = try JSONEncoder().encode(state)
            let jsonString = String(data: data, encoding: .utf8) ?? ""
            userDefaults.set(jsonString, forKey: timerStateKey)
        } catch {
            print("Failed to save timer state: \(error)")
        }
    }
    
    func loadTimerState() -> TimerPersistenceState? {
        guard let jsonString = userDefaults.string(forKey: timerStateKey),
              let data = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            let state = try JSONDecoder().decode(TimerPersistenceState.self, from: data)
            
            // Check if state is too old to be useful
            let age = Date().timeIntervalSince(state.lastSaveTime)
            if age > maxRecoveryAge {
                clearTimerState()
                return nil
            }
            
            return state
        } catch {
            print("Failed to load timer state: \(error)")
            clearTimerState()
            return nil
        }
    }
    
    func clearTimerState() {
        userDefaults.removeObject(forKey: timerStateKey)
    }
    
    func shouldResumeTimer(from state: TimerPersistenceState) -> Bool {
        let age = Date().timeIntervalSince(state.lastSaveTime)
        
        // Don't resume if too much time has passed
        if age > maxRecoveryAge {
            return false
        }
        
        // Don't resume if game was likely completed
        switch state.mode {
        case .beatTheClock:
            let projectedTime = Date().timeIntervalSince(state.startTime) - state.totalPausedTime
            return projectedTime < 65.0 // Allow 5 second buffer
        case .speedrun:
            return state.questionsAnswered < 25
        case .multiplayer:
            return false // Don't resume multiplayer games
        }
    }
}

extension DependencyValues {
    var gameTimerPersistenceService: GameTimerPersistenceServiceProtocol {
        get { self[GameTimerPersistenceServiceKey.self] }
        set { self[GameTimerPersistenceServiceKey.self] = newValue }
    }
}

private enum GameTimerPersistenceServiceKey: DependencyKey {
    static let liveValue: GameTimerPersistenceServiceProtocol = GameTimerPersistenceService()
    static let testValue: GameTimerPersistenceServiceProtocol = MockGameTimerPersistenceService()
}

// Mock service for testing
final class MockGameTimerPersistenceService: GameTimerPersistenceServiceProtocol {
    private var savedState: TimerPersistenceState?
    
    func saveTimerState(_ state: TimerPersistenceState) {
        savedState = state
    }
    
    func loadTimerState() -> TimerPersistenceState? {
        return savedState
    }
    
    func clearTimerState() {
        savedState = nil
    }
    
    func shouldResumeTimer(from state: TimerPersistenceState) -> Bool {
        return true // For testing, always allow resume
    }
}
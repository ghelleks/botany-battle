import Foundation
import Combine

@MainActor
class TimerService: ObservableObject {
    @Published var timeRemaining: Int = 0
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    
    private(set) var initialTime: Int = 0
    private var timer: AnyCancellable?
    private var timerPublisher: Timer.TimerPublisher?
    
    // Completion callback
    var onTimerCompleted: (() -> Void)?
    
    // MARK: - Computed Properties
    
    var progress: Double {
        guard initialTime > 0 else { return 0.0 }
        let elapsed = Double(initialTime - timeRemaining)
        return elapsed / Double(initialTime)
    }
    
    var formattedTime: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var isExpired: Bool {
        return timeRemaining <= 0 && initialTime > 0
    }
    
    // MARK: - Timer Control
    
    func startTimer(duration: Int) {
        guard duration > 0 else {
            print("❌ Invalid timer duration: \(duration)")
            return
        }
        
        // Stop any existing timer
        stopTimer()
        
        // Set initial state
        initialTime = duration
        timeRemaining = duration
        isRunning = true
        isPaused = false
        
        // Create and start timer
        createTimer()
        
        print("⏰ Timer started for \(duration) seconds")
    }
    
    func pauseTimer() {
        guard isRunning else { return }
        
        isRunning = false
        isPaused = true
        timer?.cancel()
        timer = nil
        
        print("⏸️ Timer paused at \(timeRemaining) seconds")
    }
    
    func resumeTimer() {
        guard isPaused else { return }
        
        isRunning = true
        isPaused = false
        createTimer()
        
        print("▶️ Timer resumed with \(timeRemaining) seconds remaining")
    }
    
    func stopTimer() {
        timer?.cancel()
        timer = nil
        timerPublisher = nil
        
        timeRemaining = 0
        initialTime = 0
        isRunning = false
        isPaused = false
        
        print("⏹️ Timer stopped")
    }
    
    func resetTimer() {
        guard initialTime > 0 else { return }
        
        timer?.cancel()
        timeRemaining = initialTime
        
        if !isPaused {
            isRunning = true
            createTimer()
        }
        
        print("🔄 Timer reset to \(initialTime) seconds")
    }
    
    // MARK: - Manual Time Control
    
    func setTimeRemaining(_ seconds: Int) {
        let clampedSeconds = max(0, seconds)
        timeRemaining = clampedSeconds
        
        if clampedSeconds == 0 && isRunning {
            handleTimerCompletion()
        }
    }
    
    func addTime(_ seconds: Int) {
        guard seconds > 0 else { return }
        timeRemaining += seconds
        print("⏰ Added \(seconds) seconds to timer. New time: \(timeRemaining)")
    }
    
    // MARK: - Private Implementation
    
    private func createTimer() {
        // Cancel existing timer
        timer?.cancel()
        
        // Create new timer that fires every second
        timerPublisher = Timer.publish(every: 1.0, on: .main, in: .common)
        timer = timerPublisher?
            .autoconnect()
            .sink { [weak self] _ in
                self?.timerTick()
            }
    }
    
    private func timerTick() {
        guard isRunning else { return }
        
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            handleTimerCompletion()
        }
    }
    
    private func handleTimerCompletion() {
        timer?.cancel()
        timer = nil
        timerPublisher = nil
        
        isRunning = false
        isPaused = false
        timeRemaining = 0
        
        print("⏰ Timer completed!")
        onTimerCompleted?()
    }
    
    // MARK: - Cleanup
    
    deinit {
        timer?.cancel()
        timer = nil
        timerPublisher = nil
        print("🗑️ TimerService deallocated")
    }
}

// MARK: - Convenience Extensions

extension TimerService {
    func startCountdownTimer(minutes: Int) {
        startTimer(duration: minutes * 60)
    }
    
    func addMinutes(_ minutes: Int) {
        addTime(minutes * 60)
    }
    
    var timeRemainingInMinutes: Double {
        return Double(timeRemaining) / 60.0
    }
    
    var isInFinalMinute: Bool {
        return timeRemaining > 0 && timeRemaining <= 60
    }
    
    var isInFinalTenSeconds: Bool {
        return timeRemaining > 0 && timeRemaining <= 10
    }
    
    var percentageComplete: Int {
        return Int(progress * 100)
    }
}

// MARK: - Game Mode Helpers

extension TimerService {
    func startPracticeMode() {
        startTimer(duration: GameConstants.practiceTimeLimit)
    }
    
    func startTimeAttackMode() {
        startTimer(duration: GameConstants.timeAttackLimit)
    }
    
    func startCustomTimer(seconds: Int) {
        startTimer(duration: seconds)
    }
}

// MARK: - Timer State

enum TimerState {
    case idle
    case running
    case paused
    case expired
}

extension TimerService {
    var state: TimerState {
        if isExpired {
            return .expired
        } else if isRunning {
            return .running
        } else if isPaused {
            return .paused
        } else {
            return .idle
        }
    }
}
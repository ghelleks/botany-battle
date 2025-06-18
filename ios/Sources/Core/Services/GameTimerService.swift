import Foundation
import Combine
import Dependencies
import UIKit

protocol GameTimerServiceProtocol {
    func startTimer(mode: GameMode, startTime: Date) -> AnyPublisher<GameTimerUpdate, Never>
    func pauseTimer()
    func resumeTimer()
    func stopTimer()
    func getCurrentTime() -> TimeInterval
    func getTotalPausedTime() -> TimeInterval
}

struct GameTimerUpdate {
    let totalTime: TimeInterval
    let timeRemaining: TimeInterval?
    let isExpired: Bool
    let pausedTime: TimeInterval
}

final class GameTimerService: GameTimerServiceProtocol {
    private var timer: Timer?
    private var updateSubject = PassthroughSubject<GameTimerUpdate, Never>()
    private var startTime: Date?
    private var gameMode: GameMode?
    private var pausedAt: Date?
    private var totalPausedTime: TimeInterval = 0
    private var isActive = false
    private var lastUpdateTime: Date?
    private var backgroundStartTime: Date?
    
    init() {
        setupAppLifecycleObservers()
    }
    
    deinit {
        stopTimer()
        removeAppLifecycleObservers()
    }
    
    func startTimer(mode: GameMode, startTime: Date) -> AnyPublisher<GameTimerUpdate, Never> {
        self.gameMode = mode
        self.startTime = startTime
        self.totalPausedTime = 0
        self.pausedAt = nil
        self.isActive = true
        
        startTimerLoop()
        
        return updateSubject.eraseToAnyPublisher()
    }
    
    func pauseTimer() {
        guard isActive, pausedAt == nil else { return }
        pausedAt = Date()
        stopTimerLoop()
    }
    
    func resumeTimer() {
        guard isActive, let pausedTime = pausedAt else { return }
        totalPausedTime += Date().timeIntervalSince(pausedTime)
        pausedAt = nil
        startTimerLoop()
    }
    
    func stopTimer() {
        stopTimerLoop()
        isActive = false
        pausedAt = nil
        totalPausedTime = 0
        startTime = nil
        gameMode = nil
    }
    
    func getCurrentTime() -> TimeInterval {
        guard let startTime = startTime else { return 0 }
        let currentTime = pausedAt ?? Date()
        return currentTime.timeIntervalSince(startTime) - totalPausedTime
    }
    
    func getTotalPausedTime() -> TimeInterval {
        return totalPausedTime
    }
    
    // MARK: - Private Methods
    
    private func startTimerLoop() {
        stopTimerLoop()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.timerTick()
        }
        
        // Ensure timer works in all run loop modes
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func stopTimerLoop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func timerTick() {
        guard let mode = gameMode, isActive else { return }
        
        let now = Date()
        lastUpdateTime = now
        
        let currentTime = getCurrentTime()
        var timeRemaining: TimeInterval?
        var isExpired = false
        
        switch mode {
        case .beatTheClock:
            timeRemaining = max(0, 60.0 - currentTime)
            isExpired = currentTime >= 60.0
        case .speedrun:
            timeRemaining = nil // No time limit
        case .multiplayer:
            timeRemaining = nil // Handled elsewhere
        }
        
        let update = GameTimerUpdate(
            totalTime: currentTime,
            timeRemaining: timeRemaining,
            isExpired: isExpired,
            pausedTime: totalPausedTime
        )
        
        updateSubject.send(update)
        
        if isExpired {
            stopTimer()
        }
    }
    
    // MARK: - App Lifecycle Handling
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    private func removeAppLifecycleObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func appDidEnterBackground() {
        backgroundStartTime = Date()
        if isActive && pausedAt == nil {
            pauseTimer()
        }
    }
    
    @objc private func appWillEnterForeground() {
        // Handle potential time discrepancies from background
        if let backgroundStart = backgroundStartTime {
            let backgroundDuration = Date().timeIntervalSince(backgroundStart)
            
            // If app was in background for more than 30 seconds, keep the pause
            if backgroundDuration > 30.0 && isActive {
                // Timer is already paused, but update total paused time to account for background time
                if pausedAt != nil {
                    totalPausedTime += backgroundDuration
                }
            }
        }
        
        backgroundStartTime = nil
        
        if isActive && pausedAt != nil {
            resumeTimer()
        }
    }
    
    @objc private func appWillTerminate() {
        stopTimer()
    }
}

extension DependencyValues {
    var gameTimerService: GameTimerServiceProtocol {
        get { self[GameTimerServiceKey.self] }
        set { self[GameTimerServiceKey.self] = newValue }
    }
}

private enum GameTimerServiceKey: DependencyKey {
    static let liveValue: GameTimerServiceProtocol = GameTimerService()
    static let testValue: GameTimerServiceProtocol = MockGameTimerService()
}

// Mock service for testing
final class MockGameTimerService: GameTimerServiceProtocol {
    private var updateSubject = PassthroughSubject<GameTimerUpdate, Never>()
    private var currentTime: TimeInterval = 0
    private var pausedTime: TimeInterval = 0
    private var isRunning = false
    
    func startTimer(mode: GameMode, startTime: Date) -> AnyPublisher<GameTimerUpdate, Never> {
        isRunning = true
        currentTime = 0
        pausedTime = 0
        
        // Simulate timer updates for testing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.isRunning {
                self.simulateTimerTick(mode: mode)
            }
        }
        
        return updateSubject.eraseToAnyPublisher()
    }
    
    func pauseTimer() {
        isRunning = false
    }
    
    func resumeTimer() {
        isRunning = true
    }
    
    func stopTimer() {
        isRunning = false
        currentTime = 0
        pausedTime = 0
    }
    
    func getCurrentTime() -> TimeInterval {
        return currentTime
    }
    
    func getTotalPausedTime() -> TimeInterval {
        return pausedTime
    }
    
    private func simulateTimerTick(mode: GameMode) {
        guard isRunning else { return }
        
        currentTime += 0.1
        
        var timeRemaining: TimeInterval?
        var isExpired = false
        
        switch mode {
        case .beatTheClock:
            timeRemaining = max(0, 60.0 - currentTime)
            isExpired = currentTime >= 60.0
        case .speedrun:
            timeRemaining = nil
        case .multiplayer:
            timeRemaining = nil
        }
        
        let update = GameTimerUpdate(
            totalTime: currentTime,
            timeRemaining: timeRemaining,
            isExpired: isExpired,
            pausedTime: pausedTime
        )
        
        updateSubject.send(update)
        
        if !isExpired && isRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.simulateTimerTick(mode: mode)
            }
        }
    }
}
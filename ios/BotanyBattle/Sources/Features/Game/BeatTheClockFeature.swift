import Foundation
import Combine

@MainActor
class BeatTheClockFeature: ObservableObject {
    @Published var gameFeature: GameFeature
    @Published var showTimeWarnings = true
    @Published var enableSoundEffects = true
    @Published var currentStreak: Int = 0
    @Published var timeWarningTriggered = false
    
    private var cancellables = Set<AnyCancellable>()
    private let userDefaultsService: UserDefaultsService
    
    // Beat the Clock specific settings
    var timeLimit: Int = GameConstants.timeAttackLimit
    var warningThreshold: Int = 10 // Warn when 10 seconds left
    
    var isInWarningZone: Bool {
        return gameFeature.timeRemaining <= warningThreshold && gameFeature.timeRemaining > 0
    }
    
    var formattedTimeRemaining: String {
        let minutes = gameFeature.timeRemaining / 60
        let seconds = gameFeature.timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var timeRemainingPercentage: Double {
        guard timeLimit > 0 else { return 0 }
        return Double(gameFeature.timeRemaining) / Double(timeLimit)
    }
    
    var scoreRate: Double {
        guard gameFeature.timeRemaining < timeLimit else { return 0 }
        let elapsedTime = timeLimit - gameFeature.timeRemaining
        guard elapsedTime > 0 else { return 0 }
        return Double(gameFeature.score) / Double(elapsedTime)
    }
    
    init(gameFeature: GameFeature = GameFeature(), 
         userDefaultsService: UserDefaultsService = UserDefaultsService()) {
        self.gameFeature = gameFeature
        self.userDefaultsService = userDefaultsService
        
        setupObservers()
        configureForBeatTheClock()
    }
    
    // MARK: - Public Methods
    
    func startBeatTheClock() async {
        gameFeature.setGameMode(.timeAttack)
        resetFeatureState()
        await gameFeature.startGame()
    }
    
    func pauseGame() {
        gameFeature.pauseGame()
    }
    
    func resumeGame() {
        gameFeature.resumeGame()
    }
    
    func submitAnswer(_ answerIndex: Int) {
        let wasCorrect = gameFeature.currentQuestion?.isCorrectAnswer(answerIndex) ?? false
        
        if wasCorrect {
            currentStreak += 1
            triggerPositiveFeedback()
        } else {
            currentStreak = 0
            triggerNegativeFeedback()
        }
        
        gameFeature.submitAnswer(answerIndex)
    }
    
    func restartGame() async {
        resetFeatureState()
        await gameFeature.restartGame()
    }
    
    func endGame() {
        gameFeature.stopGame()
        resetFeatureState()
    }
    
    // MARK: - Settings
    
    func toggleTimeWarnings() {
        showTimeWarnings.toggle()
        userDefaultsService.set(showTimeWarnings, forKey: "beatTheClock_showTimeWarnings")
    }
    
    func toggleSoundEffects() {
        enableSoundEffects.toggle()
        userDefaultsService.set(enableSoundEffects, forKey: "beatTheClock_enableSoundEffects")
    }
    
    func setTimeLimit(_ limit: Int) {
        guard limit > 0 && limit <= 300 else { return } // Max 5 minutes
        timeLimit = limit
        userDefaultsService.set(timeLimit, forKey: "beatTheClock_timeLimit")
    }
    
    func setWarningThreshold(_ threshold: Int) {
        guard threshold > 0 && threshold < timeLimit else { return }
        warningThreshold = threshold
        userDefaultsService.set(warningThreshold, forKey: "beatTheClock_warningThreshold")
    }
    
    // MARK: - Statistics
    
    var currentHighScore: Int {
        return userDefaultsService.timeAttackHighScore
    }
    
    var averageScorePerSecond: Double {
        guard gameFeature.timeRemaining < timeLimit else { return 0 }
        let timeUsed = timeLimit - gameFeature.timeRemaining
        guard timeUsed > 0 else { return 0 }
        return Double(gameFeature.score) / Double(timeUsed)
    }
    
    var projectedFinalScore: Int {
        let averageRate = averageScorePerSecond
        let totalTime = Double(timeLimit)
        return Int(averageRate * totalTime)
    }
    
    var isOnPaceForHighScore: Bool {
        return projectedFinalScore > currentHighScore
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe timer changes for warnings
        gameFeature.$timeRemaining
            .sink { [weak self] timeRemaining in
                self?.handleTimeUpdate(timeRemaining)
            }
            .store(in: &cancellables)
        
        // Observe game state changes
        gameFeature.$gameState
            .sink { [weak self] gameState in
                self?.handleGameStateChange(gameState)
            }
            .store(in: &cancellables)
        
        // Load settings
        loadSettings()
    }
    
    private func configureForBeatTheClock() {
        gameFeature.setGameMode(.timeAttack)
    }
    
    private func handleTimeUpdate(_ timeRemaining: Int) {
        if showTimeWarnings && timeRemaining == warningThreshold && !timeWarningTriggered {
            triggerTimeWarning()
            timeWarningTriggered = true
        }
        
        if timeRemaining == 5 && enableSoundEffects {
            triggerFinalCountdown()
        }
    }
    
    private func handleGameStateChange(_ gameState: GameState) {
        switch gameState {
        case .playing:
            timeWarningTriggered = false
        case .completed:
            handleGameCompletion()
        case .paused:
            break
        case .idle, .error:
            resetFeatureState()
        }
    }
    
    private func handleGameCompletion() {
        let finalScore = gameFeature.score
        let wasNewHighScore = finalScore > currentHighScore
        
        if wasNewHighScore {
            triggerNewHighScore()
        }
        
        // Award bonus trophies for exceptional performance
        awardBonusTrophies()
        
        print("🏁 Beat the Clock completed! Score: \(finalScore), High Score: \(wasNewHighScore)")
    }
    
    private func awardBonusTrophies() {
        var bonusTrophies = 0
        
        // Streak bonus
        if currentStreak >= 5 {
            bonusTrophies += 5
        }
        
        // High score bonus
        if gameFeature.score > currentHighScore {
            bonusTrophies += 10
        }
        
        // Perfect accuracy bonus
        if gameFeature.accuracy >= 1.0 {
            bonusTrophies += 15
        }
        
        if bonusTrophies > 0 {
            userDefaultsService.addTrophies(bonusTrophies)
            print("🏆 Bonus trophies awarded: \(bonusTrophies)")
        }
    }
    
    private func resetFeatureState() {
        currentStreak = 0
        timeWarningTriggered = false
    }
    
    private func loadSettings() {
        showTimeWarnings = userDefaultsService.bool(forKey: "beatTheClock_showTimeWarnings") 
        enableSoundEffects = userDefaultsService.bool(forKey: "beatTheClock_enableSoundEffects")
        
        let savedTimeLimit = userDefaultsService.integer(forKey: "beatTheClock_timeLimit")
        if savedTimeLimit > 0 {
            timeLimit = savedTimeLimit
        }
        
        let savedWarningThreshold = userDefaultsService.integer(forKey: "beatTheClock_warningThreshold")
        if savedWarningThreshold > 0 {
            warningThreshold = savedWarningThreshold
        }
    }
    
    // MARK: - Feedback Methods
    
    private func triggerPositiveFeedback() {
        if enableSoundEffects {
            // Play success sound
            print("🔊 Positive feedback sound")
        }
        
        // Could trigger haptic feedback here
        print("✅ Correct answer feedback")
    }
    
    private func triggerNegativeFeedback() {
        if enableSoundEffects {
            // Play error sound
            print("🔊 Negative feedback sound")
        }
        
        // Could trigger haptic feedback here
        print("❌ Incorrect answer feedback")
    }
    
    private func triggerTimeWarning() {
        if enableSoundEffects {
            // Play warning sound
            print("🔊 Time warning sound")
        }
        
        print("⚠️ Time warning: \(warningThreshold) seconds remaining!")
    }
    
    private func triggerFinalCountdown() {
        if enableSoundEffects {
            // Play countdown sound
            print("🔊 Final countdown sound")
        }
        
        print("⏰ Final countdown!")
    }
    
    private func triggerNewHighScore() {
        if enableSoundEffects {
            // Play celebration sound
            print("🔊 New high score celebration sound")
        }
        
        print("🎉 New high score achieved!")
    }
}

// MARK: - Extensions

extension BeatTheClockFeature {
    
    var difficultyLevel: DifficultyLevel {
        switch timeLimit {
        case ...30:
            return .extreme
        case 31...60:
            return .hard
        case 61...120:
            return .medium
        default:
            return .easy
        }
    }
    
    var timeColor: String {
        switch timeRemainingPercentage {
        case 0.5...1.0:
            return "green"
        case 0.2..<0.5:
            return "orange"
        default:
            return "red"
        }
    }
    
    var shouldShowUrgentWarning: Bool {
        return gameFeature.timeRemaining <= 5 && gameFeature.gameState == .playing
    }
}

enum DifficultyLevel: String, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    case extreme = "Extreme"
    
    var timeLimit: Int {
        switch self {
        case .easy:
            return 180 // 3 minutes
        case .medium:
            return 120 // 2 minutes
        case .hard:
            return 60  // 1 minute
        case .extreme:
            return 30  // 30 seconds
        }
    }
    
    var color: String {
        switch self {
        case .easy:
            return "green"
        case .medium:
            return "yellow"
        case .hard:
            return "orange"
        case .extreme:
            return "red"
        }
    }
}
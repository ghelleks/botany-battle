import Foundation
import Combine

enum GameState: Equatable {
    case idle
    case playing
    case paused
    case completed
    case error
}

enum GameMode: String, CaseIterable {
    case practice = "practice"
    case timeAttack = "timeAttack"
    case speedrun = "speedrun"
    
    var displayName: String {
        switch self {
        case .practice:
            return "Practice"
        case .timeAttack:
            return "Time Attack"
        case .speedrun:
            return "Speedrun"
        }
    }
    
    var description: String {
        switch self {
        case .practice:
            return "Learn without pressure"
        case .timeAttack:
            return "\(GameConstants.timeAttackLimit) seconds to identify as many plants as possible"
        case .speedrun:
            return "Race to identify \(GameConstants.speedrunQuestionCount) plants as fast as possible"
        }
    }
    
    var icon: String {
        switch self {
        case .practice:
            return "book.fill"
        case .timeAttack:
            return "timer"
        case .speedrun:
            return "bolt.fill"
        }
    }
    
    var usesTimer: Bool {
        return self != .practice
    }
    
    var maxQuestions: Int? {
        switch self {
        case .practice:
            return nil // Unlimited
        case .timeAttack:
            return nil // Limited by time
        case .speedrun:
            return GameConstants.speedrunQuestionCount
        }
    }
}

@MainActor
class GameFeature: ObservableObject {
    @Published var gameState: GameState = .idle
    @Published var currentMode: GameMode = .practice
    @Published var currentQuestionIndex: Int = 0
    @Published var score: Int = 0
    @Published var correctAnswers: Int = 0
    @Published var questions: [PlantQuestion] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let plantAPIService: PlantAPIService
    private let timerService: TimerService
    private let userDefaultsService: UserDefaultsService
    private var cancellables = Set<AnyCancellable>()
    private var gameStartTime: Date?
    private var currentStreak: Int = 0
    
    var currentQuestion: PlantQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }
    
    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentQuestionIndex) / Double(questions.count)
    }
    
    var timeRemaining: Int {
        return timerService.timeRemaining
    }
    
    var isTimerRunning: Bool {
        return timerService.isRunning
    }
    
    var canPause: Bool {
        return gameState == .playing && currentMode.usesTimer
    }
    
    var canResume: Bool {
        return gameState == .paused
    }
    
    init(plantAPIService: PlantAPIService = PlantAPIService(),
         timerService: TimerService = TimerService(),
         userDefaultsService: UserDefaultsService = UserDefaultsService()) {
        self.plantAPIService = plantAPIService
        self.timerService = timerService
        self.userDefaultsService = userDefaultsService
        
        setupTimerObserver()
    }
    
    // MARK: - Game Control
    
    func setGameMode(_ mode: GameMode) {
        currentMode = mode
        resetGameState()
    }
    
    func startGame() async {
        isLoading = true
        errorMessage = nil
        gameState = .idle
        
        do {
            // Fetch plants from API
            let plants = await plantAPIService.fetchPlants()
            
            guard !plants.isEmpty else {
                throw GameError.noPlantsAvailable
            }
            
            // Generate questions
            let generatedQuestions = generateQuestions(from: plants)
            
            guard !generatedQuestions.isEmpty else {
                throw GameError.questionGenerationFailed
            }
            
            // Update state
            questions = generatedQuestions
            currentQuestionIndex = 0
            score = 0
            correctAnswers = 0
            currentStreak = 0
            gameStartTime = Date()
            gameState = .playing
            
            // Start timer if needed
            if currentMode.usesTimer {
                setupGameTimer()
            }
            
            isLoading = false
            print("🎮 Game started in \(currentMode.displayName) mode with \(questions.count) questions")
            
        } catch {
            gameState = .error
            errorMessage = error.localizedDescription
            isLoading = false
            print("❌ Failed to start game: \(error)")
        }
    }
    
    func submitAnswer(_ selectedIndex: Int) {
        guard let question = currentQuestion,
              gameState == .playing else { return }
        
        let isCorrect = question.isCorrectAnswer(selectedIndex)
        
        if isCorrect {
            handleCorrectAnswer()
        } else {
            handleIncorrectAnswer()
        }
        
        // Move to next question or end game
        if shouldContinueGame() {
            advanceToNextQuestion()
        } else {
            completeGame()
        }
    }
    
    func pauseGame() {
        guard canPause else { return }
        
        gameState = .paused
        timerService.pauseTimer()
        print("⏸️ Game paused")
    }
    
    func resumeGame() {
        guard canResume else { return }
        
        gameState = .playing
        timerService.resumeTimer()
        print("▶️ Game resumed")
    }
    
    func stopGame() {
        timerService.stopTimer()
        gameState = .idle
        resetGameState()
        print("⏹️ Game stopped")
    }
    
    func restartGame() async {
        stopGame()
        await startGame()
    }
    
    // MARK: - Private Implementation
    
    private func setupTimerObserver() {
        timerService.onTimerCompleted = { [weak self] in
            Task { @MainActor in
                self?.handleTimerExpired()
            }
        }
    }
    
    private func setupGameTimer() {
        let duration: Int
        
        switch currentMode {
        case .practice:
            return // No timer for practice mode
        case .timeAttack:
            duration = GameConstants.timeAttackLimit
        case .speedrun:
            duration = 300 // 5 minutes max for speedrun
        }
        
        timerService.startTimer(duration: duration)
    }
    
    private func generateQuestions(from plants: [PlantData]) -> [PlantQuestion] {
        let shuffledPlants = plants.shuffled()
        let questionsToGenerate: Int
        
        if let maxQuestions = currentMode.maxQuestions {
            questionsToGenerate = min(maxQuestions, shuffledPlants.count)
        } else {
            questionsToGenerate = min(20, shuffledPlants.count) // Default max for unlimited modes
        }
        
        return shuffledPlants.prefix(questionsToGenerate).compactMap { plant in
            generateQuestion(for: plant, from: shuffledPlants)
        }
    }
    
    private func generateQuestion(for plant: PlantData, from allPlants: [PlantData]) -> PlantQuestion? {
        let otherPlants = allPlants.filter { $0.id != plant.id }
        let wrongAnswers = Array(otherPlants.shuffled().prefix(GameConstants.answerOptionsCount - 1))
        
        guard wrongAnswers.count == GameConstants.answerOptionsCount - 1 else {
            return nil
        }
        
        var options = wrongAnswers.map { $0.name }
        let correctIndex = Int.random(in: 0..<GameConstants.answerOptionsCount)
        options.insert(plant.name, at: correctIndex)
        
        return PlantQuestion(
            plant: plant,
            options: options,
            correctAnswerIndex: correctIndex
        )
    }
    
    private func handleCorrectAnswer() {
        correctAnswers += 1
        currentStreak += 1
        
        let basePoints = GameConstants.correctAnswerPoints
        let speedBonus = calculateSpeedBonus()
        let streakBonus = calculateStreakBonus()
        
        let totalPoints = basePoints + speedBonus + streakBonus
        score += totalPoints
        
        print("✅ Correct! +\(totalPoints) points (streak: \(currentStreak))")
    }
    
    private func handleIncorrectAnswer() {
        currentStreak = 0
        print("❌ Incorrect answer - streak reset")
    }
    
    private func calculateSpeedBonus() -> Int {
        guard currentMode == .speedrun || currentMode == .timeAttack else { return 0 }
        
        // Award speed bonus for quick answers
        let timePerQuestion: Double = currentMode == .speedrun ? 12.0 : 3.0
        let idealTime = timePerQuestion
        let actualTime = timerService.timeRemainingInMinutes * 60
        
        if actualTime > idealTime * 0.5 {
            return GameConstants.speedBonus
        }
        
        return 0
    }
    
    private func calculateStreakBonus() -> Int {
        if currentStreak >= 5 {
            return GameConstants.correctAnswerPoints * (GameConstants.streakMultiplier - 1)
        }
        return 0
    }
    
    private func shouldContinueGame() -> Bool {
        switch currentMode {
        case .practice:
            return currentQuestionIndex < questions.count - 1
        case .timeAttack:
            return timerService.timeRemaining > 0 && currentQuestionIndex < questions.count - 1
        case .speedrun:
            return currentQuestionIndex < questions.count - 1
        }
    }
    
    private func advanceToNextQuestion() {
        currentQuestionIndex += 1
    }
    
    private func handleTimerExpired() {
        print("⏰ Timer expired")
        completeGame()
    }
    
    private func completeGame() {
        timerService.stopTimer()
        gameState = .completed
        
        let gameEndTime = Date()
        let totalTime = gameStartTime?.timeIntervalSince(gameEndTime) ?? 0
        let wasPerfect = correctAnswers == currentQuestionIndex + 1
        
        // Record statistics
        userDefaultsService.recordGameCompletion(
            correctAnswers: correctAnswers,
            wasPerfect: wasPerfect
        )
        
        // Update high scores
        updateHighScores(totalTime: abs(totalTime))
        
        // Award trophies
        awardTrophies(wasPerfect: wasPerfect)
        
        print("🏁 Game completed! Score: \(score), Correct: \(correctAnswers)/\(currentQuestionIndex + 1)")
    }
    
    private func updateHighScores(totalTime: TimeInterval) {
        switch currentMode {
        case .practice:
            userDefaultsService.updatePracticeHighScore(score)
        case .timeAttack:
            userDefaultsService.updateTimeAttackHighScore(score)
        case .speedrun:
            userDefaultsService.updateSpeedrunBestTime(totalTime)
        }
    }
    
    private func awardTrophies(wasPerfect: Bool) {
        var trophiesToAward = GameConstants.trophiesPerWin
        
        if wasPerfect {
            trophiesToAward = GameConstants.trophiesPerPerfectGame
        }
        
        userDefaultsService.addTrophies(trophiesToAward)
    }
    
    private func resetGameState() {
        currentQuestionIndex = 0
        score = 0
        correctAnswers = 0
        questions = []
        currentStreak = 0
        errorMessage = nil
        gameStartTime = nil
    }
}

// MARK: - Error Types

enum GameError: LocalizedError {
    case noPlantsAvailable
    case questionGenerationFailed
    case invalidGameState
    
    var errorDescription: String? {
        switch self {
        case .noPlantsAvailable:
            return GameConstants.ErrorMessages.apiError
        case .questionGenerationFailed:
            return "Unable to generate questions"
        case .invalidGameState:
            return GameConstants.ErrorMessages.gameError
        }
    }
}

// MARK: - Statistics

extension GameFeature {
    var accuracy: Double {
        guard currentQuestionIndex > 0 else { return 0 }
        return Double(correctAnswers) / Double(currentQuestionIndex + 1)
    }
    
    var averageTimePerQuestion: TimeInterval {
        guard let startTime = gameStartTime else { return 0 }
        let elapsedTime = Date().timeIntervalSince(startTime)
        return elapsedTime / Double(max(1, currentQuestionIndex))
    }
    
    var isNewHighScore: Bool {
        switch currentMode {
        case .practice:
            return score > userDefaultsService.practiceHighScore
        case .timeAttack:
            return score > userDefaultsService.timeAttackHighScore
        case .speedrun:
            guard let startTime = gameStartTime else { return false }
            let totalTime = Date().timeIntervalSince(startTime)
            return totalTime < userDefaultsService.speedrunBestTime
        }
    }
}
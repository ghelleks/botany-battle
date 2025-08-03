import Foundation
import Combine

@MainActor
class SpeedrunFeature: ObservableObject {
    @Published var gameFeature: GameFeature
    @Published var enableSpeedBoosts = true
    @Published var showPerformanceMetrics = true
    @Published var targetTime: TimeInterval = 120.0 // 2 minutes target
    @Published var currentPace: SpeedrunPace = .onTarget
    @Published var splitTimes: [TimeInterval] = []
    @Published var averageTimePerQuestion: TimeInterval = 0
    
    private var cancellables = Set<AnyCancellable>()
    private let userDefaultsService: UserDefaultsService
    private var questionStartTime: Date?
    private var gameStartTime: Date?
    
    // Performance tracking
    private var fastestQuestionTime: TimeInterval = Double.greatestFiniteMagnitude
    private var slowestQuestionTime: TimeInterval = 0
    private var consecutiveQuickAnswers: Int = 0
    
    let questionsToComplete = GameConstants.speedrunQuestionCount
    
    var currentBestTime: TimeInterval {
        return userDefaultsService.speedrunBestTime
    }
    
    var elapsedTime: TimeInterval {
        guard let startTime = gameStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    var remainingQuestions: Int {
        return max(0, questionsToComplete - gameFeature.currentQuestionIndex)
    }
    
    var projectedFinishTime: TimeInterval {
        guard gameFeature.currentQuestionIndex > 0 else { return targetTime }
        return averageTimePerQuestion * Double(questionsToComplete)
    }
    
    var isOnPaceForRecord: Bool {
        return projectedFinishTime < currentBestTime
    }
    
    var progressPercentage: Double {
        return Double(gameFeature.currentQuestionIndex) / Double(questionsToComplete)
    }
    
    var currentSplit: String {
        let checkpoint = (gameFeature.currentQuestionIndex / 5) * 5 // Every 5 questions
        return "Split \(checkpoint + 5)"
    }
    
    init(gameFeature: GameFeature = GameFeature(), 
         userDefaultsService: UserDefaultsService = UserDefaultsService()) {
        self.gameFeature = gameFeature
        self.userDefaultsService = userDefaultsService
        
        setupObservers()
        loadSettings()
        configureForSpeedrun()
    }
    
    // MARK: - Public Methods
    
    func startSpeedrun() async {
        gameFeature.setGameMode(.speedrun)
        resetSpeedrunState()
        gameStartTime = Date()
        questionStartTime = Date()
        await gameFeature.startGame()
    }
    
    func submitAnswer(_ answerIndex: Int) {
        recordQuestionTime()
        
        let wasCorrect = gameFeature.currentQuestion?.isCorrectAnswer(answerIndex) ?? false
        
        if wasCorrect {
            handleCorrectAnswer()
        } else {
            handleIncorrectAnswer()
        }
        
        gameFeature.submitAnswer(answerIndex)
        
        if gameFeature.currentQuestionIndex < questionsToComplete {
            startNextQuestionTimer()
        }
        
        updatePaceMetrics()
    }
    
    func pauseSpeedrun() {
        gameFeature.pauseGame()
    }
    
    func resumeSpeedrun() {
        gameFeature.resumeGame()
        questionStartTime = Date() // Reset question timer
    }
    
    func restartSpeedrun() async {
        resetSpeedrunState()
        await gameFeature.restartGame()
        gameStartTime = Date()
        questionStartTime = Date()
    }
    
    func endSpeedrun() {
        completeSpeedrun()
        gameFeature.stopGame()
    }
    
    // MARK: - Settings
    
    func setTargetTime(_ time: TimeInterval) {
        guard time > 0 && time <= 600 else { return } // Max 10 minutes
        targetTime = time
        userDefaultsService.set(time, forKey: "speedrun_targetTime")
    }
    
    func toggleSpeedBoosts() {
        enableSpeedBoosts.toggle()
        userDefaultsService.set(enableSpeedBoosts, forKey: "speedrun_enableSpeedBoosts")
    }
    
    func togglePerformanceMetrics() {
        showPerformanceMetrics.toggle()
        userDefaultsService.set(showPerformanceMetrics, forKey: "speedrun_showPerformanceMetrics")
    }
    
    // MARK: - Performance Analysis
    
    func getPerformanceAnalysis() -> SpeedrunAnalysis {
        return SpeedrunAnalysis(
            totalTime: elapsedTime,
            questionsCompleted: gameFeature.currentQuestionIndex,
            accuracy: gameFeature.accuracy,
            averageTimePerQuestion: averageTimePerQuestion,
            fastestQuestion: fastestQuestionTime,
            slowestQuestion: slowestQuestionTime,
            splitTimes: splitTimes,
            pace: currentPace,
            isNewRecord: elapsedTime < currentBestTime
        )
    }
    
    func getSpeedrunTips() -> [String] {
        var tips: [String] = []
        
        if averageTimePerQuestion > 5.0 {
            tips.append("Try to answer questions more quickly - aim for under 5 seconds per question")
        }
        
        if gameFeature.accuracy < 0.8 {
            tips.append("Focus on accuracy - incorrect answers slow you down")
        }
        
        if consecutiveQuickAnswers < 3 {
            tips.append("Build momentum with consecutive quick correct answers")
        }
        
        if splitTimes.count > 1 {
            let lastSplit = splitTimes.last!
            let previousSplit = splitTimes[splitTimes.count - 2]
            if lastSplit > previousSplit * 1.1 {
                tips.append("You're slowing down - maintain your pace!")
            }
        }
        
        return tips.isEmpty ? ["You're doing great! Keep up the pace!"] : tips
    }
    
    func compareToPersonalBest() -> SpeedrunComparison {
        guard currentBestTime != Double.greatestFiniteMagnitude else {
            return SpeedrunComparison(
                timeDifference: 0,
                isImproving: true,
                percentageChange: 0,
                message: "This is your first speedrun!"
            )
        }
        
        let timeDiff = elapsedTime - currentBestTime
        let percentChange = (timeDiff / currentBestTime) * 100
        
        return SpeedrunComparison(
            timeDifference: timeDiff,
            isImproving: timeDiff < 0,
            percentageChange: abs(percentChange),
            message: timeDiff < 0 ? "You're beating your record!" : "Behind your best time"
        )
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        gameFeature.$gameState
            .sink { [weak self] gameState in
                self?.handleGameStateChange(gameState)
            }
            .store(in: &cancellables)
        
        gameFeature.$currentQuestionIndex
            .sink { [weak self] questionIndex in
                self?.handleQuestionChange(questionIndex)
            }
            .store(in: &cancellables)
    }
    
    private func configureForSpeedrun() {
        gameFeature.setGameMode(.speedrun)
    }
    
    private func handleGameStateChange(_ gameState: GameState) {
        switch gameState {
        case .playing:
            if questionStartTime == nil {
                questionStartTime = Date()
            }
        case .completed:
            completeSpeedrun()
        case .paused:
            break
        case .idle, .error:
            resetSpeedrunState()
        }
    }
    
    private func handleQuestionChange(_ questionIndex: Int) {
        // Record split time every 5 questions
        if questionIndex > 0 && questionIndex % 5 == 0 {
            recordSplitTime()
        }
        
        updatePaceMetrics()
    }
    
    private func recordQuestionTime() {
        guard let startTime = questionStartTime else { return }
        
        let questionTime = Date().timeIntervalSince(startTime)
        
        // Update statistics
        fastestQuestionTime = min(fastestQuestionTime, questionTime)
        slowestQuestionTime = max(slowestQuestionTime, questionTime)
        
        // Update average
        let totalTime = elapsedTime
        let questionsAnswered = Double(gameFeature.currentQuestionIndex + 1)
        averageTimePerQuestion = totalTime / questionsAnswered
        
        // Track consecutive quick answers
        if questionTime <= 3.0 { // Quick answer threshold
            consecutiveQuickAnswers += 1
        } else {
            consecutiveQuickAnswers = 0
        }
        
        print("⏱️ Question time: \(String(format: "%.2f", questionTime))s")
    }
    
    private func startNextQuestionTimer() {
        questionStartTime = Date()
    }
    
    private func recordSplitTime() {
        splitTimes.append(elapsedTime)
        print("🏃‍♂️ Split recorded: \(String(format: "%.2f", elapsedTime))s")
    }
    
    private func updatePaceMetrics() {
        guard gameFeature.currentQuestionIndex > 0 else { return }
        
        let targetPace = targetTime / Double(questionsToComplete)
        let currentActualPace = averageTimePerQuestion
        
        if currentActualPace <= targetPace * 0.9 {
            currentPace = .ahead
        } else if currentActualPace <= targetPace * 1.1 {
            currentPace = .onTarget
        } else {
            currentPace = .behind
        }
    }
    
    private func handleCorrectAnswer() {
        if enableSpeedBoosts && consecutiveQuickAnswers >= 3 {
            // Award speed boost bonus
            print("🚀 Speed boost activated!")
        }
    }
    
    private func handleIncorrectAnswer() {
        consecutiveQuickAnswers = 0
        print("❌ Speed boost reset")
    }
    
    private func completeSpeedrun() {
        let finalTime = elapsedTime
        let wasNewRecord = finalTime < currentBestTime
        
        // Update best time
        if wasNewRecord || currentBestTime == Double.greatestFiniteMagnitude {
            userDefaultsService.updateSpeedrunBestTime(finalTime)
        }
        
        // Award trophies based on performance
        awardSpeedrunTrophies(finalTime: finalTime, wasNewRecord: wasNewRecord)
        
        // Record detailed statistics
        recordSpeedrunStatistics(finalTime: finalTime)
        
        print("🏁 Speedrun completed in \(String(format: "%.2f", finalTime))s (Record: \(wasNewRecord))")
    }
    
    private func awardSpeedrunTrophies(finalTime: TimeInterval, wasNewRecord: Bool) {
        var trophies = GameConstants.trophiesPerWin
        
        // New record bonus
        if wasNewRecord {
            trophies += 20
        }
        
        // Speed bonus
        if finalTime < targetTime {
            trophies += 10
        }
        
        // Perfect accuracy bonus
        if gameFeature.accuracy >= 1.0 {
            trophies += 15
        }
        
        // Consecutive quick answers bonus
        if consecutiveQuickAnswers >= 10 {
            trophies += 5
        }
        
        userDefaultsService.addTrophies(trophies)
        print("🏆 Speedrun trophies awarded: \(trophies)")
    }
    
    private func recordSpeedrunStatistics(finalTime: TimeInterval) {
        let currentRuns = userDefaultsService.integer(forKey: "speedrun_totalRuns")
        userDefaultsService.set(currentRuns + 1, forKey: "speedrun_totalRuns")
        
        let currentTotalTime = userDefaultsService.double(forKey: "speedrun_totalTime")
        userDefaultsService.set(currentTotalTime + finalTime, forKey: "speedrun_totalTime")
        
        // Save detailed analysis
        let analysis = getPerformanceAnalysis()
        if let data = try? JSONEncoder().encode(analysis) {
            userDefaultsService.set(data, forKey: "speedrun_lastAnalysis")
        }
    }
    
    private func resetSpeedrunState() {
        splitTimes.removeAll()
        averageTimePerQuestion = 0
        fastestQuestionTime = Double.greatestFiniteMagnitude
        slowestQuestionTime = 0
        consecutiveQuickAnswers = 0
        currentPace = .onTarget
        questionStartTime = nil
        gameStartTime = nil
    }
    
    private func loadSettings() {
        let savedTargetTime = userDefaultsService.double(forKey: "speedrun_targetTime")
        if savedTargetTime > 0 {
            targetTime = savedTargetTime
        }
        
        enableSpeedBoosts = userDefaultsService.bool(forKey: "speedrun_enableSpeedBoosts")
        showPerformanceMetrics = userDefaultsService.bool(forKey: "speedrun_showPerformanceMetrics")
    }
}

// MARK: - Supporting Types

enum SpeedrunPace: String, CaseIterable {
    case ahead = "Ahead"
    case onTarget = "On Target"
    case behind = "Behind"
    
    var color: String {
        switch self {
        case .ahead:
            return "green"
        case .onTarget:
            return "blue"
        case .behind:
            return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .ahead:
            return "arrow.up.circle.fill"
        case .onTarget:
            return "target"
        case .behind:
            return "arrow.down.circle.fill"
        }
    }
}

struct SpeedrunAnalysis: Codable {
    let totalTime: TimeInterval
    let questionsCompleted: Int
    let accuracy: Double
    let averageTimePerQuestion: TimeInterval
    let fastestQuestion: TimeInterval
    let slowestQuestion: TimeInterval
    let splitTimes: [TimeInterval]
    let pace: SpeedrunPace
    let isNewRecord: Bool
    
    var formattedTotalTime: String {
        return String(format: "%.2f", totalTime)
    }
    
    var formattedAverageTime: String {
        return String(format: "%.2f", averageTimePerQuestion)
    }
    
    var grade: SpeedrunGrade {
        switch (accuracy, totalTime) {
        case (0.95...1.0, ...90):
            return .perfect
        case (0.9...1.0, ...120):
            return .excellent
        case (0.8...1.0, ...150):
            return .good
        case (0.7...1.0, ...180):
            return .average
        default:
            return .needsImprovement
        }
    }
}

struct SpeedrunComparison {
    let timeDifference: TimeInterval
    let isImproving: Bool
    let percentageChange: Double
    let message: String
    
    var formattedTimeDifference: String {
        let sign = isImproving ? "-" : "+"
        return "\(sign)\(String(format: "%.2f", abs(timeDifference)))s"
    }
}

enum SpeedrunGrade: String, CaseIterable {
    case perfect = "Perfect"
    case excellent = "Excellent"
    case good = "Good"
    case average = "Average"
    case needsImprovement = "Needs Improvement"
    
    var color: String {
        switch self {
        case .perfect:
            return "gold"
        case .excellent:
            return "green"
        case .good:
            return "blue"
        case .average:
            return "orange"
        case .needsImprovement:
            return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .perfect:
            return "crown.fill"
        case .excellent:
            return "star.fill"
        case .good:
            return "checkmark.circle.fill"
        case .average:
            return "minus.circle.fill"
        case .needsImprovement:
            return "arrow.up.circle.fill"
        }
    }
}
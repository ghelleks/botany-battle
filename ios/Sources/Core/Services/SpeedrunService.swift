import Foundation
import Dependencies

protocol SpeedrunServiceProtocol {
    func startSpeedrunGame(difficulty: Game.Difficulty) -> SingleUserGameSession
    func calculateScore(session: SingleUserGameSession) -> SpeedrunScore
    func getBestScore(for difficulty: Game.Difficulty) -> SpeedrunScore?
    func getLeaderboard(for difficulty: Game.Difficulty) -> [SpeedrunScore]
    func validateScore(session: SingleUserGameSession) -> SpeedrunValidation
    func calculateSpeedrunRating(score: SpeedrunScore) -> SpeedrunRating
}

struct SpeedrunScore: Codable, Equatable, Identifiable {
    let id: String
    let difficulty: Game.Difficulty
    let completionTime: TimeInterval
    let correctAnswers: Int
    let totalAnswers: Int
    let accuracy: Double
    let averageTimePerQuestion: TimeInterval
    let speedrunRating: Int // 0-1000 rating system
    let achievedAt: Date
    let isNewRecord: Bool
    let isCompleted: Bool // All 25 questions answered correctly
    
    var displayTime: String {
        let minutes = Int(completionTime) / 60
        let seconds = Int(completionTime) % 60
        let milliseconds = Int((completionTime.truncatingRemainder(dividingBy: 1)) * 100)
        
        if minutes > 0 {
            return String(format: "%d:%02d.%02d", minutes, seconds, milliseconds)
        } else {
            return String(format: "%d.%02ds", seconds, milliseconds)
        }
    }
    
    var displayAccuracy: String {
        return String(format: "%.1f%%", accuracy * 100)
    }
    
    var displayAverageTime: String {
        return String(format: "%.2fs", averageTimePerQuestion)
    }
    
    var displayRating: String {
        return "\(speedrunRating)"
    }
    
    var ratingTier: SpeedrunRating {
        return SpeedrunRating.fromScore(speedrunRating)
    }
}

enum SpeedrunRating: String, CaseIterable {
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"
    case platinum = "Platinum"
    case diamond = "Diamond"
    case master = "Master"
    case grandmaster = "Grandmaster"
    
    var minScore: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 200
        case .gold: return 400
        case .platinum: return 600
        case .diamond: return 750
        case .master: return 850
        case .grandmaster: return 950
        }
    }
    
    var color: String {
        switch self {
        case .bronze: return "#CD7F32"
        case .silver: return "#C0C0C0"
        case .gold: return "#FFD700"
        case .platinum: return "#E5E4E2"
        case .diamond: return "#B9F2FF"
        case .master: return "#9966CC"
        case .grandmaster: return "#FF6B35"
        }
    }
    
    static func fromScore(_ score: Int) -> SpeedrunRating {
        for tier in SpeedrunRating.allCases.reversed() {
            if score >= tier.minScore {
                return tier
            }
        }
        return .bronze
    }
}

struct SpeedrunValidation {
    let isValid: Bool
    let suspiciousActivityDetected: Bool
    let warnings: [String]
    let adjustedTime: TimeInterval?
    let adjustedRating: Int?
}

final class SpeedrunService: SpeedrunServiceProtocol {
    @Dependency(\.singleUserGameService) var singleUserGameService
    @Dependency(\.personalBestService) var personalBestService
    @Dependency(\.persistenceService) var persistenceService
    
    private let maxLeaderboardEntries = 25
    
    func startSpeedrunGame(difficulty: Game.Difficulty) -> SingleUserGameSession {
        return singleUserGameService.startGame(mode: .speedrun, difficulty: difficulty)
    }
    
    func calculateScore(session: SingleUserGameSession) -> SpeedrunScore {
        guard session.mode == .speedrun else {
            fatalError("SpeedrunService can only calculate scores for Speedrun games")
        }
        
        let completionTime = session.totalGameTime
        let accuracy = session.accuracy
        let averageTime = completionTime / Double(max(session.questionsAnswered, 1))
        let isCompleted = session.questionsAnswered >= 25 && session.correctAnswers >= 25
        
        // Calculate speedrun rating (0-1000)
        let rating = calculateSpeedrunRating(
            completionTime: completionTime,
            accuracy: accuracy,
            difficulty: session.difficulty,
            isCompleted: isCompleted
        )
        
        // Check if this is a new record
        let existingBest = persistenceService.getBestSpeedrunScore(difficulty: session.difficulty)
        let isNewRecord = existingBest?.speedrunRating ?? 0 < rating
        
        return SpeedrunScore(
            id: UUID().uuidString,
            difficulty: session.difficulty,
            completionTime: completionTime,
            correctAnswers: session.correctAnswers,
            totalAnswers: session.questionsAnswered,
            accuracy: accuracy,
            averageTimePerQuestion: averageTime,
            speedrunRating: rating,
            achievedAt: Date(),
            isNewRecord: isNewRecord,
            isCompleted: isCompleted
        )
    }
    
    func getBestScore(for difficulty: Game.Difficulty) -> SpeedrunScore? {
        return persistenceService.getBestSpeedrunScore(difficulty: difficulty)
    }
    
    func getLeaderboard(for difficulty: Game.Difficulty) -> [SpeedrunScore] {
        return persistenceService.getSpeedrunScores(difficulty: difficulty, limit: maxLeaderboardEntries)
    }
    
    func validateScore(session: SingleUserGameSession) -> SpeedrunValidation {
        var warnings: [String] = []
        var suspiciousActivity = false
        var adjustedTime: TimeInterval?
        var adjustedRating: Int?
        
        // Check for impossibly fast completion
        let minReasonableTime = Double(session.questionsAnswered) * 1.0 // Minimum 1s per question
        if session.totalGameTime < minReasonableTime {
            warnings.append("Completion time (\(String(format: "%.2f", session.totalGameTime))s) is impossibly fast")
            adjustedTime = minReasonableTime
            suspiciousActivity = true
        }
        
        // Check for suspicious perfect accuracy with very fast time
        if session.accuracy == 1.0 && session.questionsAnswered >= 10 {
            let averageTime = session.totalGameTime / Double(session.questionsAnswered)
            if averageTime < 2.0 {
                warnings.append("Perfect accuracy with average time of \(String(format: "%.2f", averageTime))s per question is suspicious")
                suspiciousActivity = true
            }
        }
        
        // Check for incomplete speedrun
        if session.questionsAnswered < 25 {
            warnings.append("Speedrun incomplete: only \(session.questionsAnswered)/25 questions answered")
        }
        
        // Check for time manipulation based on pause patterns
        if session.totalPausedTime > session.totalGameTime * 0.5 {
            warnings.append("Excessive pause time detected: \(String(format: "%.2f", session.totalPausedTime))s")
            suspiciousActivity = true
        }
        
        // Adjust rating if suspicious activity detected
        if suspiciousActivity {
            let originalScore = calculateScore(session: session)
            adjustedRating = max(0, originalScore.speedrunRating - 200) // Penalty for suspicious activity
        }
        
        return SpeedrunValidation(
            isValid: !suspiciousActivity,
            suspiciousActivityDetected: suspiciousActivity,
            warnings: warnings,
            adjustedTime: adjustedTime,
            adjustedRating: adjustedRating
        )
    }
    
    func calculateSpeedrunRating(score: SpeedrunScore) -> SpeedrunRating {
        return SpeedrunRating.fromScore(score.speedrunRating)
    }
    
    // MARK: - Private Methods
    
    private func calculateSpeedrunRating(
        completionTime: TimeInterval,
        accuracy: Double,
        difficulty: Game.Difficulty,
        isCompleted: Bool
    ) -> Int {
        // Base rating calculation
        var rating = 0
        
        // Completion bonus (major factor)
        if isCompleted {
            rating += 400 // Base completion bonus
            
            // Time-based bonus (faster = higher rating)
            let timeBonus = calculateTimeBonus(completionTime: completionTime, difficulty: difficulty)
            rating += timeBonus
            
            // Accuracy bonus
            let accuracyBonus = Int(accuracy * 200) // 0-200 bonus for accuracy
            rating += accuracyBonus
            
            // Difficulty multiplier
            let difficultyMultiplier = getDifficultyMultiplier(difficulty)
            rating = Int(Double(rating) * difficultyMultiplier)
        } else {
            // Partial completion rating
            rating = Int(accuracy * 100) // Maximum 100 for incomplete runs
        }
        
        return min(1000, max(0, rating)) // Clamp to 0-1000 range
    }
    
    private func calculateTimeBonus(completionTime: TimeInterval, difficulty: Game.Difficulty) -> Int {
        // Define target times for each difficulty (in seconds)
        let targetTimes: [Game.Difficulty: TimeInterval] = [
            .easy: 100.0,    // 4s per question
            .medium: 125.0,  // 5s per question
            .hard: 150.0,    // 6s per question
            .expert: 200.0   // 8s per question
        ]
        
        guard let targetTime = targetTimes[difficulty] else { return 0 }
        
        if completionTime <= targetTime {
            // Bonus for beating target time
            let timeRatio = targetTime / completionTime
            return min(300, Int(timeRatio * 150)) // Max 300 bonus
        } else {
            // Penalty for exceeding target time
            let penaltyRatio = completionTime / targetTime
            return max(0, 150 - Int(penaltyRatio * 75)) // Reduced bonus
        }
    }
    
    private func getDifficultyMultiplier(_ difficulty: Game.Difficulty) -> Double {
        switch difficulty {
        case .easy: return 0.8
        case .medium: return 1.0
        case .hard: return 1.2
        case .expert: return 1.5
        }
    }
    
    func saveScore(_ score: SpeedrunScore) {
        do {
            try persistenceService.saveSpeedrunScore(score)
        } catch {
            print("Failed to save Speedrun score: \(error)")
        }
    }
}

extension DependencyValues {
    var speedrunService: SpeedrunServiceProtocol {
        get { self[SpeedrunServiceKey.self] }
        set { self[SpeedrunServiceKey.self] = newValue }
    }
}

private enum SpeedrunServiceKey: DependencyKey {
    static let liveValue: SpeedrunServiceProtocol = SpeedrunService()
    static let testValue: SpeedrunServiceProtocol = MockSpeedrunService()
}

// Mock service for testing
final class MockSpeedrunService: SpeedrunServiceProtocol {
    private var mockScores: [SpeedrunScore] = []
    
    func startSpeedrunGame(difficulty: Game.Difficulty) -> SingleUserGameSession {
        return SingleUserGameSession(mode: .speedrun, difficulty: difficulty)
    }
    
    func calculateScore(session: SingleUserGameSession) -> SpeedrunScore {
        let isCompleted = session.questionsAnswered >= 25
        return SpeedrunScore(
            id: UUID().uuidString,
            difficulty: session.difficulty,
            completionTime: session.totalGameTime,
            correctAnswers: session.correctAnswers,
            totalAnswers: session.questionsAnswered,
            accuracy: session.accuracy,
            averageTimePerQuestion: session.totalGameTime / Double(max(session.questionsAnswered, 1)),
            speedrunRating: isCompleted ? 500 : 100,
            achievedAt: Date(),
            isNewRecord: true,
            isCompleted: isCompleted
        )
    }
    
    func getBestScore(for difficulty: Game.Difficulty) -> SpeedrunScore? {
        return mockScores.filter { $0.difficulty == difficulty }.max { $0.speedrunRating < $1.speedrunRating }
    }
    
    func getLeaderboard(for difficulty: Game.Difficulty) -> [SpeedrunScore] {
        return mockScores.filter { $0.difficulty == difficulty }.sorted { $0.speedrunRating > $1.speedrunRating }
    }
    
    func validateScore(session: SingleUserGameSession) -> SpeedrunValidation {
        return SpeedrunValidation(
            isValid: true,
            suspiciousActivityDetected: false,
            warnings: [],
            adjustedTime: nil,
            adjustedRating: nil
        )
    }
    
    func calculateSpeedrunRating(score: SpeedrunScore) -> SpeedrunRating {
        return SpeedrunRating.fromScore(score.speedrunRating)
    }
    
    func addMockScore(_ score: SpeedrunScore) {
        mockScores.append(score)
    }
}
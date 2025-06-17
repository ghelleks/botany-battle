import Foundation
import Dependencies

protocol BeatTheClockServiceProtocol {
    func startBeatTheClockGame(difficulty: Game.Difficulty) -> SingleUserGameSession
    func calculateScore(session: SingleUserGameSession) -> BeatTheClockScore
    func getBestScore(for difficulty: Game.Difficulty) -> BeatTheClockScore?
    func getLeaderboard(for difficulty: Game.Difficulty) -> [BeatTheClockScore]
    func validateScore(session: SingleUserGameSession) -> BeatTheClockValidation
}

struct BeatTheClockScore: Codable, Equatable, Identifiable {
    let id: String
    let difficulty: Game.Difficulty
    let correctAnswers: Int
    let totalAnswers: Int
    let timeUsed: TimeInterval
    let accuracy: Double
    let pointsPerSecond: Double
    let achievedAt: Date
    let isNewRecord: Bool
    
    var displayScore: String {
        return "\(correctAnswers) correct"
    }
    
    var displayAccuracy: String {
        return String(format: "%.1f%%", accuracy * 100)
    }
    
    var displayTimeUsed: String {
        return String(format: "%.1fs", timeUsed)
    }
    
    var displayPointsPerSecond: String {
        return String(format: "%.2f pts/sec", pointsPerSecond)
    }
}

struct BeatTheClockValidation {
    let isValid: Bool
    let suspiciousActivityDetected: Bool
    let warnings: [String]
    let adjustedScore: Int?
}

final class BeatTheClockService: BeatTheClockServiceProtocol {
    @Dependency(\.singleUserGameService) var singleUserGameService
    @Dependency(\.personalBestService) var personalBestService
    @Dependency(\.persistenceService) var persistenceService
    
    private let maxLeaderboardEntries = 10
    
    func startBeatTheClockGame(difficulty: Game.Difficulty) -> SingleUserGameSession {
        return singleUserGameService.startGame(mode: .beatTheClock, difficulty: difficulty)
    }
    
    func calculateScore(session: SingleUserGameSession) -> BeatTheClockScore {
        guard session.mode == .beatTheClock else {
            fatalError("BeatTheClockService can only calculate scores for Beat the Clock games")
        }
        
        let timeUsed = min(session.totalGameTime, 60.0) // Cap at 60 seconds
        let accuracy = session.accuracy
        let pointsPerSecond = timeUsed > 0 ? Double(session.correctAnswers) / timeUsed : 0
        
        // Check if this is a new record
        let existingBest = persistenceService.getBestBeatTheClockScore(difficulty: session.difficulty)
        let isNewRecord = existingBest?.correctAnswers ?? 0 < session.correctAnswers
        
        return BeatTheClockScore(
            id: UUID().uuidString,
            difficulty: session.difficulty,
            correctAnswers: session.correctAnswers,
            totalAnswers: session.questionsAnswered,
            timeUsed: timeUsed,
            accuracy: accuracy,
            pointsPerSecond: pointsPerSecond,
            achievedAt: Date(),
            isNewRecord: isNewRecord
        )
    }
    
    func getBestScore(for difficulty: Game.Difficulty) -> BeatTheClockScore? {
        return persistenceService.getBestBeatTheClockScore(difficulty: difficulty)
    }
    
    func getLeaderboard(for difficulty: Game.Difficulty) -> [BeatTheClockScore] {
        return persistenceService.getBeatTheClockScores(difficulty: difficulty, limit: maxLeaderboardEntries)
    }
    
    func validateScore(session: SingleUserGameSession) -> BeatTheClockValidation {
        var warnings: [String] = []
        var suspiciousActivity = false
        var adjustedScore: Int?
        
        // Check for impossibly fast answers
        let averageTimePerAnswer = session.totalGameTime / Double(max(session.questionsAnswered, 1))
        if averageTimePerAnswer < 1.0 {
            warnings.append("Average time per answer is unusually fast: \(String(format: "%.2f", averageTimePerAnswer))s")
            suspiciousActivity = true
        }
        
        // Check for perfect accuracy with high speed
        if session.accuracy == 1.0 && session.questionsAnswered > 10 && averageTimePerAnswer < 2.0 {
            warnings.append("Perfect accuracy with very fast answers is suspicious")
            suspiciousActivity = true
        }
        
        // Check for unrealistic number of questions in 60 seconds
        let maxReasonableQuestions = Int(60.0 / 1.5) // Assuming minimum 1.5s per question
        if session.questionsAnswered > maxReasonableQuestions {
            warnings.append("Number of questions (\(session.questionsAnswered)) exceeds reasonable limit")
            adjustedScore = min(session.correctAnswers, maxReasonableQuestions)
            suspiciousActivity = true
        }
        
        // Check for time manipulation
        if session.totalGameTime < Double(session.questionsAnswered) * 0.8 {
            warnings.append("Total time seems too short for number of questions answered")
            suspiciousActivity = true
        }
        
        return BeatTheClockValidation(
            isValid: !suspiciousActivity,
            suspiciousActivityDetected: suspiciousActivity,
            warnings: warnings,
            adjustedScore: adjustedScore
        )
    }
    
    func saveScore(_ score: BeatTheClockScore) {
        do {
            try persistenceService.saveBeatTheClockScore(score)
        } catch {
            print("Failed to save Beat the Clock score: \(error)")
        }
    }
}

extension DependencyValues {
    var beatTheClockService: BeatTheClockServiceProtocol {
        get { self[BeatTheClockServiceKey.self] }
        set { self[BeatTheClockServiceKey.self] = newValue }
    }
}

private enum BeatTheClockServiceKey: DependencyKey {
    static let liveValue: BeatTheClockServiceProtocol = BeatTheClockService()
    static let testValue: BeatTheClockServiceProtocol = MockBeatTheClockService()
}

// Mock service for testing
final class MockBeatTheClockService: BeatTheClockServiceProtocol {
    private var mockScores: [BeatTheClockScore] = []
    
    func startBeatTheClockGame(difficulty: Game.Difficulty) -> SingleUserGameSession {
        return SingleUserGameSession(mode: .beatTheClock, difficulty: difficulty)
    }
    
    func calculateScore(session: SingleUserGameSession) -> BeatTheClockScore {
        return BeatTheClockScore(
            id: UUID().uuidString,
            difficulty: session.difficulty,
            correctAnswers: session.correctAnswers,
            totalAnswers: session.questionsAnswered,
            timeUsed: session.totalGameTime,
            accuracy: session.accuracy,
            pointsPerSecond: session.totalGameTime > 0 ? Double(session.correctAnswers) / session.totalGameTime : 0,
            achievedAt: Date(),
            isNewRecord: true
        )
    }
    
    func getBestScore(for difficulty: Game.Difficulty) -> BeatTheClockScore? {
        return mockScores.filter { $0.difficulty == difficulty }.max { $0.correctAnswers < $1.correctAnswers }
    }
    
    func getLeaderboard(for difficulty: Game.Difficulty) -> [BeatTheClockScore] {
        return mockScores.filter { $0.difficulty == difficulty }.sorted { $0.correctAnswers > $1.correctAnswers }
    }
    
    func validateScore(session: SingleUserGameSession) -> BeatTheClockValidation {
        return BeatTheClockValidation(
            isValid: true,
            suspiciousActivityDetected: false,
            warnings: [],
            adjustedScore: nil
        )
    }
    
    func addMockScore(_ score: BeatTheClockScore) {
        mockScores.append(score)
    }
}
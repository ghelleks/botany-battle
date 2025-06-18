import Foundation
import Dependencies

protocol TrophyServiceProtocol {
    func calculateTrophiesEarned(session: SingleUserGameSession) -> TrophyReward
    func getTotalTrophies() -> Int
    func addTrophies(_ amount: Int)
    func getTrophyHistory() -> [TrophyTransaction]
    func clearTrophyHistory()
}

struct TrophyReward {
    let totalTrophies: Int
    let breakdown: TrophyBreakdown
}

struct TrophyBreakdown {
    let baseTrophies: Int
    let accuracyBonus: Int
    let streakBonus: Int
    let speedBonus: Int
    let completionBonus: Int
    let difficultyMultiplier: Double
    let finalAmount: Int
    
    var components: [TrophyComponent] {
        var components: [TrophyComponent] = []
        
        if baseTrophies > 0 {
            components.append(TrophyComponent(
                type: .base,
                description: "Base Score",
                amount: baseTrophies
            ))
        }
        
        if accuracyBonus > 0 {
            components.append(TrophyComponent(
                type: .accuracy,
                description: "Accuracy Bonus",
                amount: accuracyBonus
            ))
        }
        
        if streakBonus > 0 {
            components.append(TrophyComponent(
                type: .streak,
                description: "Streak Bonus",
                amount: streakBonus
            ))
        }
        
        if speedBonus > 0 {
            components.append(TrophyComponent(
                type: .speed,
                description: "Speed Bonus",
                amount: speedBonus
            ))
        }
        
        if completionBonus > 0 {
            components.append(TrophyComponent(
                type: .completion,
                description: "Completion Bonus",
                amount: completionBonus
            ))
        }
        
        if difficultyMultiplier != 1.0 {
            let multiplierBonus = Int(Double(baseTrophies + accuracyBonus + streakBonus + speedBonus + completionBonus) * (difficultyMultiplier - 1.0))
            if multiplierBonus > 0 {
                components.append(TrophyComponent(
                    type: .difficulty,
                    description: "Difficulty Multiplier",
                    amount: multiplierBonus
                ))
            }
        }
        
        return components
    }
}

struct TrophyComponent {
    let type: TrophyType
    let description: String
    let amount: Int
}

enum TrophyType {
    case base
    case accuracy
    case streak
    case speed
    case completion
    case difficulty
    case achievement
    case dailyBonus
}

struct TrophyTransaction: Codable, Identifiable {
    let id: String
    let amount: Int
    let reason: String
    let gameMode: GameMode?
    let difficulty: Game.Difficulty?
    let timestamp: Date
    let breakdown: [String: Int]? // For detailed breakdown
}

final class TrophyService: TrophyServiceProtocol {
    @Dependency(\.userDefaults) var userDefaults
    
    private let totalTrophiesKey = "total_trophies"
    private let trophyHistoryKey = "trophy_history"
    private let maxHistoryEntries = 100
    
    func calculateTrophiesEarned(session: SingleUserGameSession) -> TrophyReward {
        let breakdown = calculateTrophyBreakdown(session: session)
        return TrophyReward(
            totalTrophies: breakdown.finalAmount,
            breakdown: breakdown
        )
    }
    
    func getTotalTrophies() -> Int {
        return userDefaults.integer(forKey: totalTrophiesKey)
    }
    
    func addTrophies(_ amount: Int) {
        let currentTotal = getTotalTrophies()
        userDefaults.set(currentTotal + amount, forKey: totalTrophiesKey)
    }
    
    func getTrophyHistory() -> [TrophyTransaction] {
        guard let data = userDefaults.data(forKey: trophyHistoryKey) else {
            return []
        }
        
        do {
            let transactions = try JSONDecoder().decode([TrophyTransaction].self, from: data)
            return transactions.sorted { $0.timestamp > $1.timestamp }
        } catch {
            print("Failed to decode trophy history: \(error)")
            return []
        }
    }
    
    func clearTrophyHistory() {
        userDefaults.removeObject(forKey: trophyHistoryKey)
    }
    
    // MARK: - Private Methods
    
    private func calculateTrophyBreakdown(session: SingleUserGameSession) -> TrophyBreakdown {
        let baseTrophies = calculateBaseTrophies(session: session)
        let accuracyBonus = calculateAccuracyBonus(session: session)
        let streakBonus = calculateStreakBonus(session: session)
        let speedBonus = calculateSpeedBonus(session: session)
        let completionBonus = calculateCompletionBonus(session: session)
        let difficultyMultiplier = getDifficultyMultiplier(session.difficulty)
        
        let subtotal = baseTrophies + accuracyBonus + streakBonus + speedBonus + completionBonus
        let finalAmount = Int(Double(subtotal) * difficultyMultiplier)
        
        return TrophyBreakdown(
            baseTrophies: baseTrophies,
            accuracyBonus: accuracyBonus,
            streakBonus: streakBonus,
            speedBonus: speedBonus,
            completionBonus: completionBonus,
            difficultyMultiplier: difficultyMultiplier,
            finalAmount: finalAmount
        )
    }
    
    private func calculateBaseTrophies(session: SingleUserGameSession) -> Int {
        switch session.mode {
        case .multiplayer:
            return session.score / 10 // 1 trophy per 10 points
        case .beatTheClock:
            return session.correctAnswers * 5 // 5 trophies per correct answer
        case .speedrun:
            return session.correctAnswers * 8 // 8 trophies per correct answer (higher value)
        }
    }
    
    private func calculateAccuracyBonus(session: SingleUserGameSession) -> Int {
        let accuracy = session.accuracy
        
        if accuracy >= 0.95 {
            return 100 // Perfect or near-perfect
        } else if accuracy >= 0.9 {
            return 75 // Excellent
        } else if accuracy >= 0.8 {
            return 50 // Very good
        } else if accuracy >= 0.7 {
            return 25 // Good
        } else {
            return 0 // No bonus
        }
    }
    
    private func calculateStreakBonus(session: SingleUserGameSession) -> Int {
        let maxStreak = calculateMaxStreak(session: session)
        
        if maxStreak >= 15 {
            return 80
        } else if maxStreak >= 10 {
            return 50
        } else if maxStreak >= 5 {
            return 25
        } else if maxStreak >= 3 {
            return 10
        } else {
            return 0
        }
    }
    
    private func calculateSpeedBonus(session: SingleUserGameSession) -> Int {
        guard session.mode == .speedrun && session.questionsAnswered > 0 else {
            return 0
        }
        
        let averageTime = session.totalGameTime / Double(session.questionsAnswered)
        let targetTime = getTargetTimeForDifficulty(session.difficulty)
        
        if averageTime <= targetTime * 0.7 {
            return 60 // Exceptional speed
        } else if averageTime <= targetTime * 0.8 {
            return 40 // Great speed
        } else if averageTime <= targetTime * 0.9 {
            return 20 // Good speed
        } else {
            return 0 // No bonus
        }
    }
    
    private func calculateCompletionBonus(session: SingleUserGameSession) -> Int {
        switch session.mode {
        case .multiplayer:
            return 0 // No completion bonus for multiplayer
        case .beatTheClock:
            // Bonus based on number of questions answered in 60 seconds
            if session.correctAnswers >= 25 {
                return 150 // Exceptional
            } else if session.correctAnswers >= 20 {
                return 100 // Excellent
            } else if session.correctAnswers >= 15 {
                return 75 // Very good
            } else if session.correctAnswers >= 10 {
                return 50 // Good
            } else {
                return 0
            }
        case .speedrun:
            // Bonus for completing all 25 questions
            if session.questionsAnswered >= 25 {
                let completionTime = session.totalGameTime
                if completionTime <= 60 {
                    return 200 // Under 1 minute
                } else if completionTime <= 90 {
                    return 150 // Under 1.5 minutes
                } else if completionTime <= 120 {
                    return 100 // Under 2 minutes
                } else {
                    return 75 // Completed
                }
            } else {
                return 0
            }
        }
    }
    
    private func getDifficultyMultiplier(_ difficulty: Game.Difficulty) -> Double {
        switch difficulty {
        case .easy: return 0.8
        case .medium: return 1.0
        case .hard: return 1.3
        case .expert: return 1.6
        }
    }
    
    private func getTargetTimeForDifficulty(_ difficulty: Game.Difficulty) -> Double {
        switch difficulty {
        case .easy: return 4.0
        case .medium: return 5.0
        case .hard: return 6.0
        case .expert: return 8.0
        }
    }
    
    private func calculateMaxStreak(session: SingleUserGameSession) -> Int {
        var maxStreak = 0
        var currentStreak = 0
        
        for answer in session.answers {
            if answer.isCorrect {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }
        
        return maxStreak
    }
    
    func recordTrophyTransaction(
        amount: Int,
        reason: String,
        gameMode: GameMode?,
        difficulty: Game.Difficulty?,
        breakdown: TrophyBreakdown?
    ) {
        let transaction = TrophyTransaction(
            id: UUID().uuidString,
            amount: amount,
            reason: reason,
            gameMode: gameMode,
            difficulty: difficulty,
            timestamp: Date(),
            breakdown: breakdown?.components.reduce(into: [String: Int]()) { result, component in
                result[component.description] = component.amount
            }
        )
        
        var history = getTrophyHistory()
        history.insert(transaction, at: 0)
        
        // Keep only the most recent entries
        if history.count > maxHistoryEntries {
            history = Array(history.prefix(maxHistoryEntries))
        }
        
        saveTrophyHistory(history)
    }
    
    private func saveTrophyHistory(_ history: [TrophyTransaction]) {
        do {
            let data = try JSONEncoder().encode(history)
            userDefaults.set(data, forKey: trophyHistoryKey)
        } catch {
            print("Failed to save trophy history: \(error)")
        }
    }
    
    func awardTrophiesForSession(_ session: SingleUserGameSession) -> TrophyReward {
        let reward = calculateTrophiesEarned(session: session)
        
        // Add trophies to total
        addTrophies(reward.totalTrophies)
        
        // Record transaction
        recordTrophyTransaction(
            amount: reward.totalTrophies,
            reason: "\(session.mode.displayName) - \(session.difficulty.displayName)",
            gameMode: session.mode,
            difficulty: session.difficulty,
            breakdown: reward.breakdown
        )
        
        return reward
    }
}

extension DependencyValues {
    var trophyService: TrophyServiceProtocol {
        get { self[TrophyServiceKey.self] }
        set { self[TrophyServiceKey.self] = newValue }
    }
}

private enum TrophyServiceKey: DependencyKey {
    static let liveValue: TrophyServiceProtocol = TrophyService()
    static let testValue: TrophyServiceProtocol = MockTrophyService()
}

// MARK: - Mock Service for Testing

final class MockTrophyService: TrophyServiceProtocol {
    private var totalTrophies: Int = 1000
    private var trophyHistory: [TrophyTransaction] = []
    
    func calculateTrophiesEarned(session: SingleUserGameSession) -> TrophyReward {
        let breakdown = TrophyBreakdown(
            baseTrophies: session.correctAnswers * 5,
            accuracyBonus: session.accuracy >= 0.9 ? 50 : 0,
            streakBonus: 25,
            speedBonus: 0,
            completionBonus: session.mode == .speedrun ? 100 : 75,
            difficultyMultiplier: 1.0,
            finalAmount: 200
        )
        
        return TrophyReward(
            totalTrophies: 200,
            breakdown: breakdown
        )
    }
    
    func getTotalTrophies() -> Int {
        return totalTrophies
    }
    
    func addTrophies(_ amount: Int) {
        totalTrophies += amount
    }
    
    func getTrophyHistory() -> [TrophyTransaction] {
        return trophyHistory
    }
    
    func clearTrophyHistory() {
        trophyHistory.removeAll()
    }
}
import Foundation
import CoreData
import Dependencies

protocol PersistenceServiceProtocol {
    // Personal Bests
    func savePersonalBest(_ personalBest: PersonalBest) throws
    func getPersonalBest(mode: GameMode, difficulty: Game.Difficulty) -> PersonalBest?
    func getAllPersonalBests() -> [PersonalBest]
    func deletePersonalBest(mode: GameMode, difficulty: Game.Difficulty) throws
    
    // Game History
    func saveGameHistory(_ gameSession: SingleUserGameSession, isNewPersonalBest: Bool) throws
    func getGameHistory(limit: Int?) -> [GameHistoryItem]
    func getGameHistory(mode: GameMode, limit: Int?) -> [GameHistoryItem]
    func deleteGameHistory(olderThan date: Date) throws
    
    // Beat the Clock Scores
    func saveBeatTheClockScore(_ score: BeatTheClockScore) throws
    func getBeatTheClockScores(difficulty: Game.Difficulty, limit: Int?) -> [BeatTheClockScore]
    func getBestBeatTheClockScore(difficulty: Game.Difficulty) -> BeatTheClockScore?
    func deleteBeatTheClockScores(difficulty: Game.Difficulty) throws
    
    // Speedrun Scores
    func saveSpeedrunScore(_ score: SpeedrunScore) throws
    func getSpeedrunScores(difficulty: Game.Difficulty, limit: Int?) -> [SpeedrunScore]
    func getBestSpeedrunScore(difficulty: Game.Difficulty) -> SpeedrunScore?
    func deleteSpeedrunScores(difficulty: Game.Difficulty) throws
    
    // Maintenance
    func performMaintenance() throws
    func exportData() throws -> Data
    func importData(_ data: Data) throws
}

struct GameHistoryItem: Identifiable, Equatable {
    let id: String
    let gameMode: GameMode
    let difficulty: Game.Difficulty
    let score: Int
    let correctAnswers: Int
    let questionsAnswered: Int
    let totalGameTime: TimeInterval
    let completedAt: Date
    let isNewPersonalBest: Bool
    
    var displayScore: String {
        switch gameMode {
        case .beatTheClock:
            return "\(correctAnswers) correct"
        case .speedrun:
            let minutes = Int(totalGameTime) / 60
            let seconds = Int(totalGameTime) % 60
            return String(format: "%d:%02d", minutes, seconds)
        case .multiplayer:
            return "\(score) points"
        }
    }
    
    var displayAccuracy: String {
        guard questionsAnswered > 0 else { return "0%" }
        let accuracy = Double(correctAnswers) / Double(questionsAnswered)
        return String(format: "%.1f%%", accuracy * 100)
    }
}

final class PersistenceService: PersistenceServiceProtocol {
    private let coreDataStack: CoreDataStack
    
    init(coreDataStack: CoreDataStack = .shared) {
        self.coreDataStack = coreDataStack
    }
    
    // MARK: - Personal Bests
    
    func savePersonalBest(_ personalBest: PersonalBest) throws {
        let context = coreDataStack.context
        
        // Check if personal best already exists
        let fetchRequest: NSFetchRequest<PersonalBestEntity> = PersonalBestEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "gameMode == %@ AND difficulty == %@",
            personalBest.gameMode.rawValue,
            personalBest.difficulty.rawValue
        )
        
        let existingBests = try context.fetch(fetchRequest)
        
        // Delete existing personal best if it exists
        existingBests.forEach { context.delete($0) }
        
        // Create new personal best entity
        let entity = PersonalBestEntity(context: context)
        entity.bestId = personalBest.id
        entity.gameMode = personalBest.gameMode.rawValue
        entity.difficulty = personalBest.difficulty.rawValue
        entity.score = Int32(personalBest.score)
        entity.correctAnswers = Int32(personalBest.correctAnswers)
        entity.questionsAnswered = Int32(personalBest.questionsAnswered)
        entity.totalGameTime = personalBest.totalGameTime
        entity.achievedAt = personalBest.achievedAt
        
        try context.save()
    }
    
    func getPersonalBest(mode: GameMode, difficulty: Game.Difficulty) -> PersonalBest? {
        let context = coreDataStack.context
        
        let fetchRequest: NSFetchRequest<PersonalBestEntity> = PersonalBestEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "gameMode == %@ AND difficulty == %@",
            mode.rawValue,
            difficulty.rawValue
        )
        fetchRequest.fetchLimit = 1
        
        do {
            let entities = try context.fetch(fetchRequest)
            return entities.first?.toPersonalBest()
        } catch {
            print("Failed to fetch personal best: \(error)")
            return nil
        }
    }
    
    func getAllPersonalBests() -> [PersonalBest] {
        let context = coreDataStack.context
        
        let fetchRequest: NSFetchRequest<PersonalBestEntity> = PersonalBestEntity.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \PersonalBestEntity.achievedAt, ascending: false)
        ]
        
        do {
            let entities = try context.fetch(fetchRequest)
            return entities.compactMap { $0.toPersonalBest() }
        } catch {
            print("Failed to fetch personal bests: \(error)")
            return []
        }
    }
    
    func deletePersonalBest(mode: GameMode, difficulty: Game.Difficulty) throws {
        let context = coreDataStack.context
        
        let fetchRequest: NSFetchRequest<PersonalBestEntity> = PersonalBestEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "gameMode == %@ AND difficulty == %@",
            mode.rawValue,
            difficulty.rawValue
        )
        
        let entities = try context.fetch(fetchRequest)
        entities.forEach { context.delete($0) }
        
        try context.save()
    }
    
    // MARK: - Game History
    
    func saveGameHistory(_ gameSession: SingleUserGameSession, isNewPersonalBest: Bool) throws {
        let context = coreDataStack.context
        
        let entity = GameHistoryEntity(context: context)
        entity.gameId = gameSession.id
        entity.gameMode = gameSession.mode.rawValue
        entity.difficulty = gameSession.difficulty.rawValue
        entity.score = Int32(gameSession.score)
        entity.correctAnswers = Int32(gameSession.correctAnswers)
        entity.questionsAnswered = Int32(gameSession.questionsAnswered)
        entity.totalGameTime = gameSession.totalGameTime
        entity.completedAt = gameSession.completedAt ?? Date()
        entity.isNewPersonalBest = isNewPersonalBest
        
        try context.save()
    }
    
    func getGameHistory(limit: Int? = nil) -> [GameHistoryItem] {
        let context = coreDataStack.context
        
        let fetchRequest: NSFetchRequest<GameHistoryEntity> = GameHistoryEntity.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \GameHistoryEntity.completedAt, ascending: false)
        ]
        
        if let limit = limit {
            fetchRequest.fetchLimit = limit
        }
        
        do {
            let entities = try context.fetch(fetchRequest)
            return entities.compactMap { $0.toGameHistoryItem() }
        } catch {
            print("Failed to fetch game history: \(error)")
            return []
        }
    }
    
    func getGameHistory(mode: GameMode, limit: Int? = nil) -> [GameHistoryItem] {
        let context = coreDataStack.context
        
        let fetchRequest: NSFetchRequest<GameHistoryEntity> = GameHistoryEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "gameMode == %@", mode.rawValue)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \GameHistoryEntity.completedAt, ascending: false)
        ]
        
        if let limit = limit {
            fetchRequest.fetchLimit = limit
        }
        
        do {
            let entities = try context.fetch(fetchRequest)
            return entities.compactMap { $0.toGameHistoryItem() }
        } catch {
            print("Failed to fetch game history for mode \(mode): \(error)")
            return []
        }
    }
    
    func deleteGameHistory(olderThan date: Date) throws {
        let context = coreDataStack.context
        
        let fetchRequest: NSFetchRequest<GameHistoryEntity> = GameHistoryEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "completedAt < %@", date as NSDate)
        
        let entities = try context.fetch(fetchRequest)
        entities.forEach { context.delete($0) }
        
        try context.save()
    }
    
    // MARK: - Beat the Clock Scores
    
    func saveBeatTheClockScore(_ score: BeatTheClockScore) throws {
        let context = coreDataStack.context
        
        let entity = BeatTheClockScoreEntity(context: context)
        entity.scoreId = score.id
        entity.difficulty = score.difficulty.rawValue
        entity.correctAnswers = Int32(score.correctAnswers)
        entity.totalAnswers = Int32(score.totalAnswers)
        entity.timeUsed = score.timeUsed
        entity.accuracy = score.accuracy
        entity.pointsPerSecond = score.pointsPerSecond
        entity.achievedAt = score.achievedAt
        entity.isNewRecord = score.isNewRecord
        
        try context.save()
    }
    
    func getBeatTheClockScores(difficulty: Game.Difficulty, limit: Int? = nil) -> [BeatTheClockScore] {
        let context = coreDataStack.context
        
        let fetchRequest: NSFetchRequest<BeatTheClockScoreEntity> = BeatTheClockScoreEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "difficulty == %@", difficulty.rawValue)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \BeatTheClockScoreEntity.correctAnswers, ascending: false),
            NSSortDescriptor(keyPath: \BeatTheClockScoreEntity.accuracy, ascending: false),
            NSSortDescriptor(keyPath: \BeatTheClockScoreEntity.timeUsed, ascending: true)
        ]
        
        if let limit = limit {
            fetchRequest.fetchLimit = limit
        }
        
        do {
            let entities = try context.fetch(fetchRequest)
            return entities.compactMap { $0.toBeatTheClockScore() }
        } catch {
            print("Failed to fetch Beat the Clock scores: \(error)")
            return []
        }
    }
    
    func getBestBeatTheClockScore(difficulty: Game.Difficulty) -> BeatTheClockScore? {
        let scores = getBeatTheClockScores(difficulty: difficulty, limit: 1)
        return scores.first
    }
    
    func deleteBeatTheClockScores(difficulty: Game.Difficulty) throws {
        let context = coreDataStack.context
        
        let fetchRequest: NSFetchRequest<BeatTheClockScoreEntity> = BeatTheClockScoreEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "difficulty == %@", difficulty.rawValue)
        
        let entities = try context.fetch(fetchRequest)
        entities.forEach { context.delete($0) }
        
        try context.save()
    }
    
    // MARK: - Speedrun Scores
    
    func saveSpeedrunScore(_ score: SpeedrunScore) throws {
        let context = coreDataStack.context
        
        let entity = SpeedrunScoreEntity(context: context)
        entity.scoreId = score.id
        entity.difficulty = score.difficulty.rawValue
        entity.completionTime = score.completionTime
        entity.correctAnswers = Int32(score.correctAnswers)
        entity.totalAnswers = Int32(score.totalAnswers)
        entity.accuracy = score.accuracy
        entity.averageTimePerQuestion = score.averageTimePerQuestion
        entity.speedrunRating = Int32(score.speedrunRating)
        entity.achievedAt = score.achievedAt
        entity.isNewRecord = score.isNewRecord
        entity.isCompleted = score.isCompleted
        
        try context.save()
    }
    
    func getSpeedrunScores(difficulty: Game.Difficulty, limit: Int? = nil) -> [SpeedrunScore] {
        let context = coreDataStack.context
        
        let fetchRequest: NSFetchRequest<SpeedrunScoreEntity> = SpeedrunScoreEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "difficulty == %@", difficulty.rawValue)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \SpeedrunScoreEntity.speedrunRating, ascending: false),
            NSSortDescriptor(keyPath: \SpeedrunScoreEntity.isCompleted, ascending: false),
            NSSortDescriptor(keyPath: \SpeedrunScoreEntity.completionTime, ascending: true)
        ]
        
        if let limit = limit {
            fetchRequest.fetchLimit = limit
        }
        
        do {
            let entities = try context.fetch(fetchRequest)
            return entities.compactMap { $0.toSpeedrunScore() }
        } catch {
            print("Failed to fetch Speedrun scores: \(error)")
            return []
        }
    }
    
    func getBestSpeedrunScore(difficulty: Game.Difficulty) -> SpeedrunScore? {
        let scores = getSpeedrunScores(difficulty: difficulty, limit: 1)
        return scores.first
    }
    
    func deleteSpeedrunScores(difficulty: Game.Difficulty) throws {
        let context = coreDataStack.context
        
        let fetchRequest: NSFetchRequest<SpeedrunScoreEntity> = SpeedrunScoreEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "difficulty == %@", difficulty.rawValue)
        
        let entities = try context.fetch(fetchRequest)
        entities.forEach { context.delete($0) }
        
        try context.save()
    }
    
    // MARK: - Maintenance
    
    func performMaintenance() throws {
        // Clean up old game history (keep last 100 entries)
        let context = coreDataStack.context
        
        let fetchRequest: NSFetchRequest<GameHistoryEntity> = GameHistoryEntity.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \GameHistoryEntity.completedAt, ascending: false)
        ]
        
        let allHistory = try context.fetch(fetchRequest)
        
        if allHistory.count > 100 {
            let toDelete = Array(allHistory.dropFirst(100))
            toDelete.forEach { context.delete($0) }
        }
        
        // Clean up old scores (keep top 25 per difficulty per mode)
        try cleanupBeatTheClockScores()
        try cleanupSpeedrunScores()
        
        try context.save()
    }
    
    private func cleanupBeatTheClockScores() throws {
        let context = coreDataStack.context
        
        for difficulty in Game.Difficulty.allCases {
            let fetchRequest: NSFetchRequest<BeatTheClockScoreEntity> = BeatTheClockScoreEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "difficulty == %@", difficulty.rawValue)
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \BeatTheClockScoreEntity.correctAnswers, ascending: false),
                NSSortDescriptor(keyPath: \BeatTheClockScoreEntity.accuracy, ascending: false),
                NSSortDescriptor(keyPath: \BeatTheClockScoreEntity.timeUsed, ascending: true)
            ]
            
            let scores = try context.fetch(fetchRequest)
            
            if scores.count > 25 {
                let toDelete = Array(scores.dropFirst(25))
                toDelete.forEach { context.delete($0) }
            }
        }
    }
    
    private func cleanupSpeedrunScores() throws {
        let context = coreDataStack.context
        
        for difficulty in Game.Difficulty.allCases {
            let fetchRequest: NSFetchRequest<SpeedrunScoreEntity> = SpeedrunScoreEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "difficulty == %@", difficulty.rawValue)
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \SpeedrunScoreEntity.speedrunRating, ascending: false),
                NSSortDescriptor(keyPath: \SpeedrunScoreEntity.isCompleted, ascending: false),
                NSSortDescriptor(keyPath: \SpeedrunScoreEntity.completionTime, ascending: true)
            ]
            
            let scores = try context.fetch(fetchRequest)
            
            if scores.count > 25 {
                let toDelete = Array(scores.dropFirst(25))
                toDelete.forEach { context.delete($0) }
            }
        }
    }
    
    func exportData() throws -> Data {
        let context = coreDataStack.context
        
        let personalBests = getAllPersonalBests()
        let gameHistory = getGameHistory()
        
        var beatTheClockScores: [BeatTheClockScore] = []
        var speedrunScores: [SpeedrunScore] = []
        
        for difficulty in Game.Difficulty.allCases {
            beatTheClockScores.append(contentsOf: getBeatTheClockScores(difficulty: difficulty))
            speedrunScores.append(contentsOf: getSpeedrunScores(difficulty: difficulty))
        }
        
        let exportData = ExportData(
            personalBests: personalBests,
            gameHistory: gameHistory,
            beatTheClockScores: beatTheClockScores,
            speedrunScores: speedrunScores,
            exportedAt: Date()
        )
        
        return try JSONEncoder().encode(exportData)
    }
    
    func importData(_ data: Data) throws {
        let exportData = try JSONDecoder().decode(ExportData.self, from: data)
        
        // Import personal bests
        for personalBest in exportData.personalBests {
            try savePersonalBest(personalBest)
        }
        
        // Import Beat the Clock scores
        for score in exportData.beatTheClockScores {
            try saveBeatTheClockScore(score)
        }
        
        // Import Speedrun scores
        for score in exportData.speedrunScores {
            try saveSpeedrunScore(score)
        }
        
        // Note: Game history is not imported to avoid duplicates
    }
}

// MARK: - Export Data Structure

private struct ExportData: Codable {
    let personalBests: [PersonalBest]
    let gameHistory: [GameHistoryItem]
    let beatTheClockScores: [BeatTheClockScore]
    let speedrunScores: [SpeedrunScore]
    let exportedAt: Date
}

// MARK: - Core Data Extensions

extension PersonalBestEntity {
    func toPersonalBest() -> PersonalBest? {
        guard let gameMode = GameMode(rawValue: gameMode ?? ""),
              let difficulty = Game.Difficulty(rawValue: difficulty ?? "") else {
            return nil
        }
        
        return PersonalBest(
            id: bestId ?? UUID().uuidString,
            gameMode: gameMode,
            difficulty: difficulty,
            score: Int(score),
            correctAnswers: Int(correctAnswers),
            questionsAnswered: Int(questionsAnswered),
            totalGameTime: totalGameTime,
            achievedAt: achievedAt ?? Date()
        )
    }
}

extension GameHistoryEntity {
    func toGameHistoryItem() -> GameHistoryItem? {
        guard let gameMode = GameMode(rawValue: gameMode ?? ""),
              let difficulty = Game.Difficulty(rawValue: difficulty ?? "") else {
            return nil
        }
        
        return GameHistoryItem(
            id: gameId ?? UUID().uuidString,
            gameMode: gameMode,
            difficulty: difficulty,
            score: Int(score),
            correctAnswers: Int(correctAnswers),
            questionsAnswered: Int(questionsAnswered),
            totalGameTime: totalGameTime,
            completedAt: completedAt ?? Date(),
            isNewPersonalBest: isNewPersonalBest
        )
    }
}

extension BeatTheClockScoreEntity {
    func toBeatTheClockScore() -> BeatTheClockScore? {
        guard let difficulty = Game.Difficulty(rawValue: difficulty ?? "") else {
            return nil
        }
        
        return BeatTheClockScore(
            id: scoreId ?? UUID().uuidString,
            difficulty: difficulty,
            correctAnswers: Int(correctAnswers),
            totalAnswers: Int(totalAnswers),
            timeUsed: timeUsed,
            accuracy: accuracy,
            pointsPerSecond: pointsPerSecond,
            achievedAt: achievedAt ?? Date(),
            isNewRecord: isNewRecord
        )
    }
}

extension SpeedrunScoreEntity {
    func toSpeedrunScore() -> SpeedrunScore? {
        guard let difficulty = Game.Difficulty(rawValue: difficulty ?? "") else {
            return nil
        }
        
        return SpeedrunScore(
            id: scoreId ?? UUID().uuidString,
            difficulty: difficulty,
            completionTime: completionTime,
            correctAnswers: Int(correctAnswers),
            totalAnswers: Int(totalAnswers),
            accuracy: accuracy,
            averageTimePerQuestion: averageTimePerQuestion,
            speedrunRating: Int(speedrunRating),
            achievedAt: achievedAt ?? Date(),
            isNewRecord: isNewRecord,
            isCompleted: isCompleted
        )
    }
}

// MARK: - Dependency Registration

extension DependencyValues {
    var persistenceService: PersistenceServiceProtocol {
        get { self[PersistenceServiceKey.self] }
        set { self[PersistenceServiceKey.self] = newValue }
    }
}

private enum PersistenceServiceKey: DependencyKey {
    static let liveValue: PersistenceServiceProtocol = PersistenceService()
    static let testValue: PersistenceServiceProtocol = MockPersistenceService()
}

// MARK: - Mock Service for Testing

final class MockPersistenceService: PersistenceServiceProtocol {
    private var personalBests: [PersonalBest] = []
    private var gameHistory: [GameHistoryItem] = []
    private var beatTheClockScores: [BeatTheClockScore] = []
    private var speedrunScores: [SpeedrunScore] = []
    
    func savePersonalBest(_ personalBest: PersonalBest) throws {
        personalBests.removeAll { $0.gameMode == personalBest.gameMode && $0.difficulty == personalBest.difficulty }
        personalBests.append(personalBest)
    }
    
    func getPersonalBest(mode: GameMode, difficulty: Game.Difficulty) -> PersonalBest? {
        return personalBests.first { $0.gameMode == mode && $0.difficulty == difficulty }
    }
    
    func getAllPersonalBests() -> [PersonalBest] {
        return personalBests.sorted { $0.achievedAt > $1.achievedAt }
    }
    
    func deletePersonalBest(mode: GameMode, difficulty: Game.Difficulty) throws {
        personalBests.removeAll { $0.gameMode == mode && $0.difficulty == difficulty }
    }
    
    func saveGameHistory(_ gameSession: SingleUserGameSession, isNewPersonalBest: Bool) throws {
        let historyItem = GameHistoryItem(
            id: gameSession.id,
            gameMode: gameSession.mode,
            difficulty: gameSession.difficulty,
            score: gameSession.score,
            correctAnswers: gameSession.correctAnswers,
            questionsAnswered: gameSession.questionsAnswered,
            totalGameTime: gameSession.totalGameTime,
            completedAt: gameSession.completedAt ?? Date(),
            isNewPersonalBest: isNewPersonalBest
        )
        gameHistory.append(historyItem)
    }
    
    func getGameHistory(limit: Int?) -> [GameHistoryItem] {
        let sorted = gameHistory.sorted { $0.completedAt > $1.completedAt }
        if let limit = limit {
            return Array(sorted.prefix(limit))
        }
        return sorted
    }
    
    func getGameHistory(mode: GameMode, limit: Int?) -> [GameHistoryItem] {
        let filtered = gameHistory.filter { $0.gameMode == mode }.sorted { $0.completedAt > $1.completedAt }
        if let limit = limit {
            return Array(filtered.prefix(limit))
        }
        return filtered
    }
    
    func deleteGameHistory(olderThan date: Date) throws {
        gameHistory.removeAll { $0.completedAt < date }
    }
    
    func saveBeatTheClockScore(_ score: BeatTheClockScore) throws {
        beatTheClockScores.append(score)
    }
    
    func getBeatTheClockScores(difficulty: Game.Difficulty, limit: Int?) -> [BeatTheClockScore] {
        let filtered = beatTheClockScores.filter { $0.difficulty == difficulty }
            .sorted { lhs, rhs in
                if lhs.correctAnswers != rhs.correctAnswers {
                    return lhs.correctAnswers > rhs.correctAnswers
                }
                if abs(lhs.accuracy - rhs.accuracy) > 0.001 {
                    return lhs.accuracy > rhs.accuracy
                }
                return lhs.timeUsed < rhs.timeUsed
            }
        
        if let limit = limit {
            return Array(filtered.prefix(limit))
        }
        return filtered
    }
    
    func getBestBeatTheClockScore(difficulty: Game.Difficulty) -> BeatTheClockScore? {
        return getBeatTheClockScores(difficulty: difficulty, limit: 1).first
    }
    
    func deleteBeatTheClockScores(difficulty: Game.Difficulty) throws {
        beatTheClockScores.removeAll { $0.difficulty == difficulty }
    }
    
    func saveSpeedrunScore(_ score: SpeedrunScore) throws {
        speedrunScores.append(score)
    }
    
    func getSpeedrunScores(difficulty: Game.Difficulty, limit: Int?) -> [SpeedrunScore] {
        let filtered = speedrunScores.filter { $0.difficulty == difficulty }
            .sorted { lhs, rhs in
                if lhs.speedrunRating != rhs.speedrunRating {
                    return lhs.speedrunRating > rhs.speedrunRating
                }
                if lhs.isCompleted != rhs.isCompleted {
                    return lhs.isCompleted && !rhs.isCompleted
                }
                return lhs.completionTime < rhs.completionTime
            }
        
        if let limit = limit {
            return Array(filtered.prefix(limit))
        }
        return filtered
    }
    
    func getBestSpeedrunScore(difficulty: Game.Difficulty) -> SpeedrunScore? {
        return getSpeedrunScores(difficulty: difficulty, limit: 1).first
    }
    
    func deleteSpeedrunScores(difficulty: Game.Difficulty) throws {
        speedrunScores.removeAll { $0.difficulty == difficulty }
    }
    
    func performMaintenance() throws {
        // Mock implementation - no-op
    }
    
    func exportData() throws -> Data {
        let exportData = ExportData(
            personalBests: personalBests,
            gameHistory: gameHistory,
            beatTheClockScores: beatTheClockScores,
            speedrunScores: speedrunScores,
            exportedAt: Date()
        )
        return try JSONEncoder().encode(exportData)
    }
    
    func importData(_ data: Data) throws {
        let exportData = try JSONDecoder().decode(ExportData.self, from: data)
        personalBests = exportData.personalBests
        beatTheClockScores = exportData.beatTheClockScores
        speedrunScores = exportData.speedrunScores
    }
}
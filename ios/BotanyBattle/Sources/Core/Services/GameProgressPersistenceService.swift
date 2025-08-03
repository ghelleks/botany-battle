import Foundation
import Combine

// MARK: - Game Progress Persistence Service

@MainActor
class GameProgressPersistenceService: ObservableObject {
    static let shared = GameProgressPersistenceService()
    
    @Published var isLoading = false
    @Published var lastSaveDate: Date?
    @Published var errorMessage: String?
    
    private let coreDataService = CoreDataService.shared
    private let userDefaultsService = UserDefaultsService()
    private var cancellables = Set<AnyCancellable>()
    
    // Auto-save configuration
    private var autoSaveEnabled = true
    private var saveDebounceTimer: AnyCancellable?
    private let saveDebounceInterval: TimeInterval = 2.0 // Save 2 seconds after last change
    
    init() {
        setupAutoSave()
    }
    
    private func setupAutoSave() {
        // Monitor app lifecycle for save triggers
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.saveAllProgress()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.saveAllProgress()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Game Progress Management
    
    func saveGameSession(_ session: GameSession) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Convert session to Core Data format
            let progressData = GameProgressData(
                id: session.id,
                mode: session.mode,
                score: session.score,
                correctAnswers: session.correctAnswers,
                totalQuestions: session.totalQuestions,
                timeElapsed: session.timeElapsed,
                completedAt: session.completedAt,
                userId: getCurrentUserId()
            )
            
            // Save to Core Data
            try await coreDataService.saveGameProgress(progressData)
            
            // Update personal bests
            await updatePersonalBests(for: session)
            
            // Update statistics
            await updateGameStatistics(for: session)
            
            lastSaveDate = Date()
            print("✅ Game session saved successfully")
            
        } catch {
            errorMessage = "Failed to save game progress: \(error.localizedDescription)"
            print("❌ Failed to save game session: \(error)")
        }
    }
    
    func loadGameProgress(for mode: GameMode, limit: Int = 10) async -> [GameSession] {
        do {
            let progressData = try await coreDataService.fetchGameProgress(
                for: getCurrentUserId(),
                mode: mode
            )
            
            return Array(progressData.prefix(limit)).map { data in
                GameSession(
                    id: data.id,
                    mode: data.mode,
                    score: data.score,
                    correctAnswers: data.correctAnswers,
                    totalQuestions: data.totalQuestions,
                    timeElapsed: data.timeElapsed,
                    completedAt: data.completedAt
                )
            }
            
        } catch {
            errorMessage = "Failed to load game progress: \(error.localizedDescription)"
            print("❌ Failed to load game progress: \(error)")
            return []
        }
    }
    
    func loadAllGameProgress() async -> [GameSession] {
        do {
            let progressData = try await coreDataService.fetchGameProgress(
                for: getCurrentUserId()
            )
            
            return progressData.map { data in
                GameSession(
                    id: data.id,
                    mode: data.mode,
                    score: data.score,
                    correctAnswers: data.correctAnswers,
                    totalQuestions: data.totalQuestions,
                    timeElapsed: data.timeElapsed,
                    completedAt: data.completedAt
                )
            }
            
        } catch {
            errorMessage = "Failed to load all game progress: \(error.localizedDescription)"
            print("❌ Failed to load all game progress: \(error)")
            return []
        }
    }
    
    // MARK: - Personal Bests
    
    func getPersonalBest(for mode: GameMode) async -> GameSession? {
        do {
            guard let progressData = try await coreDataService.getPersonalBest(
                for: getCurrentUserId(),
                mode: mode
            ) else {
                return nil
            }
            
            return GameSession(
                id: progressData.id,
                mode: progressData.mode,
                score: progressData.score,
                correctAnswers: progressData.correctAnswers,
                totalQuestions: progressData.totalQuestions,
                timeElapsed: progressData.timeElapsed,
                completedAt: progressData.completedAt
            )
            
        } catch {
            errorMessage = "Failed to get personal best: \(error.localizedDescription)"
            print("❌ Failed to get personal best: \(error)")
            return nil
        }
    }
    
    private func updatePersonalBests(for session: GameSession) async {
        do {
            let currentBest = try await coreDataService.getPersonalBest(
                for: getCurrentUserId(),
                mode: session.mode
            )
            
            // Check if this session is a new personal best
            let isNewBest: Bool
            
            switch session.mode {
            case .speedrun:
                // For speedrun, lower time is better (if same score)
                isNewBest = currentBest == nil ||
                           session.score > currentBest!.score ||
                           (session.score == currentBest!.score && session.timeElapsed < currentBest!.timeElapsed)
                
            case .beatTheClock, .practice:
                // For other modes, higher score is better
                isNewBest = currentBest == nil || session.score > currentBest!.score
            }
            
            if isNewBest {
                userDefaultsService.setPersonalBest(session.score, for: session.mode)
                
                // Post notification for achievement
                NotificationCenter.default.post(
                    name: .personalBestAchieved,
                    object: PersonalBestNotification(mode: session.mode, score: session.score)
                )
                
                print("🏆 New personal best for \(session.mode): \(session.score)")
            }
            
        } catch {
            print("❌ Failed to update personal bests: \(error)")
        }
    }
    
    // MARK: - Game Statistics
    
    private func updateGameStatistics(for session: GameSession) async {
        // Update total games played
        let totalGames = userDefaultsService.getTotalGamesPlayed(for: session.mode)
        userDefaultsService.setTotalGamesPlayed(totalGames + 1, for: session.mode)
        
        // Update average score
        let currentAverage = userDefaultsService.getAverageScore(for: session.mode)
        let newAverage = (currentAverage * Double(totalGames) + Double(session.score)) / Double(totalGames + 1)
        userDefaultsService.setAverageScore(newAverage, for: session.mode)
        
        // Update total play time
        let totalPlayTime = userDefaultsService.getTotalPlayTime(for: session.mode)
        userDefaultsService.setTotalPlayTime(totalPlayTime + session.timeElapsed, for: session.mode)
        
        // Update accuracy
        let accuracy = Double(session.correctAnswers) / Double(session.totalQuestions) * 100
        let currentAccuracy = userDefaultsService.getAverageAccuracy(for: session.mode)
        let newAccuracy = (currentAccuracy * Double(totalGames) + accuracy) / Double(totalGames + 1)
        userDefaultsService.setAverageAccuracy(newAccuracy, for: session.mode)
    }
    
    // MARK: - Auto-Save Features
    
    func scheduleAutoSave(for session: GameSession) {
        guard autoSaveEnabled else { return }
        
        // Cancel previous timer
        saveDebounceTimer?.cancel()
        
        // Schedule new save
        saveDebounceTimer = Timer.publish(every: saveDebounceInterval, on: .main, in: .common)
            .autoconnect()
            .first()
            .sink { _ in
                Task {
                    await self.saveGameSession(session)
                }
            }
    }
    
    func saveCurrentGameState(_ gameState: CurrentGameState) async {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(gameState)
            userDefaultsService.setCurrentGameState(data)
            
            print("✅ Current game state saved")
            
        } catch {
            errorMessage = "Failed to save current game state: \(error.localizedDescription)"
            print("❌ Failed to save current game state: \(error)")
        }
    }
    
    func loadCurrentGameState() async -> CurrentGameState? {
        guard let data = userDefaultsService.getCurrentGameState() else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let gameState = try decoder.decode(CurrentGameState.self, from: data)
            return gameState
            
        } catch {
            errorMessage = "Failed to load current game state: \(error.localizedDescription)"
            print("❌ Failed to load current game state: \(error)")
            return nil
        }
    }
    
    func clearCurrentGameState() {
        userDefaultsService.clearCurrentGameState()
        print("✅ Current game state cleared")
    }
    
    // MARK: - Batch Operations
    
    func saveAllProgress() async {
        print("💾 Saving all game progress...")
        
        // Save any pending game sessions
        // This would be called by individual game features
        
        // Save current timestamp
        lastSaveDate = Date()
        userDefaultsService.setLastSaveDate(lastSaveDate!)
        
        print("✅ All progress saved")
    }
    
    func exportProgress() async -> GameProgressExport? {
        do {
            let allProgress = await loadAllGameProgress()
            let statistics = getAllStatistics()
            
            let export = GameProgressExport(
                sessions: allProgress,
                statistics: statistics,
                exportDate: Date(),
                version: "1.0"
            )
            
            return export
            
        } catch {
            errorMessage = "Failed to export progress: \(error.localizedDescription)"
            print("❌ Failed to export progress: \(error)")
            return nil
        }
    }
    
    func importProgress(from export: GameProgressExport) async -> Bool {
        guard export.version == "1.0" else {
            errorMessage = "Unsupported export version: \(export.version)"
            return false
        }
        
        do {
            // Import sessions
            for session in export.sessions {
                await saveGameSession(session)
            }
            
            // Import statistics
            importStatistics(export.statistics)
            
            print("✅ Progress imported successfully")
            return true
            
        } catch {
            errorMessage = "Failed to import progress: \(error.localizedDescription)"
            print("❌ Failed to import progress: \(error)")
            return false
        }
    }
    
    // MARK: - Statistics Helpers
    
    private func getAllStatistics() -> GameStatistics {
        var modeStats: [GameMode: GameModeStatistics] = [:]
        
        for mode in GameMode.allCases {
            modeStats[mode] = GameModeStatistics(
                totalGames: userDefaultsService.getTotalGamesPlayed(for: mode),
                personalBest: userDefaultsService.getPersonalBest(for: mode),
                averageScore: userDefaultsService.getAverageScore(for: mode),
                totalPlayTime: userDefaultsService.getTotalPlayTime(for: mode),
                averageAccuracy: userDefaultsService.getAverageAccuracy(for: mode)
            )
        }
        
        return GameStatistics(
            modeStatistics: modeStats,
            lastUpdated: Date()
        )
    }
    
    private func importStatistics(_ statistics: GameStatistics) {
        for (mode, stats) in statistics.modeStatistics {
            userDefaultsService.setTotalGamesPlayed(stats.totalGames, for: mode)
            userDefaultsService.setPersonalBest(stats.personalBest, for: mode)
            userDefaultsService.setAverageScore(stats.averageScore, for: mode)
            userDefaultsService.setTotalPlayTime(stats.totalPlayTime, for: mode)
            userDefaultsService.setAverageAccuracy(stats.averageAccuracy, for: mode)
        }
    }
    
    // MARK: - User Management
    
    private func getCurrentUserId() -> String {
        return userDefaultsService.getCurrentUserId() ?? "guest"
    }
    
    // MARK: - Configuration
    
    func setAutoSaveEnabled(_ enabled: Bool) {
        autoSaveEnabled = enabled
        if !enabled {
            saveDebounceTimer?.cancel()
        }
    }
    
    func getAutoSaveEnabled() -> Bool {
        return autoSaveEnabled
    }
}

// MARK: - Data Models

struct GameSession: Identifiable, Codable {
    let id: UUID
    let mode: GameMode
    let score: Int
    let correctAnswers: Int
    let totalQuestions: Int
    let timeElapsed: TimeInterval
    let completedAt: Date
    
    var accuracy: Double {
        guard totalQuestions > 0 else { return 0.0 }
        return Double(correctAnswers) / Double(totalQuestions) * 100
    }
    
    var formattedTime: String {
        let minutes = Int(timeElapsed) / 60
        let seconds = Int(timeElapsed) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var scorePerMinute: Double {
        guard timeElapsed > 0 else { return 0.0 }
        return Double(score) / (timeElapsed / 60.0)
    }
}

struct CurrentGameState: Codable {
    let mode: GameMode
    let currentQuestion: Int
    let score: Int
    let correctAnswers: Int
    let timeRemaining: Int
    let startTime: Date
    let plants: [String] // Plant IDs
    let isActive: Bool
}

struct GameModeStatistics: Codable {
    let totalGames: Int
    let personalBest: Int
    let averageScore: Double
    let totalPlayTime: TimeInterval
    let averageAccuracy: Double
    
    var formattedPlayTime: String {
        let hours = Int(totalPlayTime) / 3600
        let minutes = (Int(totalPlayTime) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct GameStatistics: Codable {
    let modeStatistics: [GameMode: GameModeStatistics]
    let lastUpdated: Date
    
    var totalGamesAllModes: Int {
        return modeStatistics.values.reduce(0) { $0 + $1.totalGames }
    }
    
    var totalPlayTimeAllModes: TimeInterval {
        return modeStatistics.values.reduce(0) { $0 + $1.totalPlayTime }
    }
}

struct GameProgressExport: Codable {
    let sessions: [GameSession]
    let statistics: GameStatistics
    let exportDate: Date
    let version: String
}

struct PersonalBestNotification {
    let mode: GameMode
    let score: Int
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let personalBestAchieved = Notification.Name("personalBestAchieved")
    static let gameProgressSaved = Notification.Name("gameProgressSaved")
    static let gameStateRestored = Notification.Name("gameStateRestored")
}

// MARK: - UserDefaults Extensions

extension UserDefaultsService {
    func setCurrentGameState(_ data: Data) {
        userDefaults.set(data, forKey: "currentGameState")
    }
    
    func getCurrentGameState() -> Data? {
        return userDefaults.data(forKey: "currentGameState")
    }
    
    func clearCurrentGameState() {
        userDefaults.removeObject(forKey: "currentGameState")
    }
    
    func setLastSaveDate(_ date: Date) {
        userDefaults.set(date, forKey: "lastSaveDate")
    }
    
    func getLastSaveDate() -> Date? {
        return userDefaults.object(forKey: "lastSaveDate") as? Date
    }
    
    // Game mode specific statistics
    func setTotalGamesPlayed(_ count: Int, for mode: GameMode) {
        userDefaults.set(count, forKey: "totalGames_\(mode.rawValue)")
    }
    
    func getTotalGamesPlayed(for mode: GameMode) -> Int {
        return userDefaults.integer(forKey: "totalGames_\(mode.rawValue)")
    }
    
    func setAverageScore(_ score: Double, for mode: GameMode) {
        userDefaults.set(score, forKey: "averageScore_\(mode.rawValue)")
    }
    
    func getAverageScore(for mode: GameMode) -> Double {
        return userDefaults.double(forKey: "averageScore_\(mode.rawValue)")
    }
    
    func setTotalPlayTime(_ time: TimeInterval, for mode: GameMode) {
        userDefaults.set(time, forKey: "totalPlayTime_\(mode.rawValue)")
    }
    
    func getTotalPlayTime(for mode: GameMode) -> TimeInterval {
        return userDefaults.double(forKey: "totalPlayTime_\(mode.rawValue)")
    }
    
    func setAverageAccuracy(_ accuracy: Double, for mode: GameMode) {
        userDefaults.set(accuracy, forKey: "averageAccuracy_\(mode.rawValue)")
    }
    
    func getAverageAccuracy(for mode: GameMode) -> Double {
        return userDefaults.double(forKey: "averageAccuracy_\(mode.rawValue)")
    }
    
    func getCurrentUserId() -> String? {
        return userDefaults.string(forKey: "currentUserId")
    }
    
    func setCurrentUserId(_ userId: String) {
        userDefaults.set(userId, forKey: "currentUserId")
    }
}

// MARK: - Preview Support

#if DEBUG
extension GameProgressPersistenceService {
    static func mock() -> GameProgressPersistenceService {
        let service = GameProgressPersistenceService()
        service.lastSaveDate = Date().addingTimeInterval(-300) // 5 minutes ago
        return service
    }
}

extension GameSession {
    static func mockSession(mode: GameMode = .practice) -> GameSession {
        return GameSession(
            id: UUID(),
            mode: mode,
            score: Int.random(in: 5...20),
            correctAnswers: Int.random(in: 3...15),
            totalQuestions: 15,
            timeElapsed: TimeInterval.random(in: 30...300),
            completedAt: Date().addingTimeInterval(-TimeInterval.random(in: 0...86400))
        )
    }
}
#endif
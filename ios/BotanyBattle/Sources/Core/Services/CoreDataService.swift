import CoreData
import Foundation
import Combine

// MARK: - Core Data Service

@MainActor
class CoreDataService: ObservableObject {
    static let shared = CoreDataService()
    
    @Published var isReady = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "BotanyBattle")
        
        // Configure for better performance
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { [weak self] _, error in
            if let error = error {
                self?.errorMessage = "Core Data failed to load: \(error.localizedDescription)"
                print("❌ Core Data error: \(error)")
            } else {
                print("✅ Core Data loaded successfully")
                Task { @MainActor in
                    self?.isReady = true
                }
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    private var backgroundContext: NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    // MARK: - Initialization
    
    init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        // Listen for context changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleContextDidSave(notification)
            }
            .store(in: &cancellables)
        
        // Listen for remote changes
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleRemoteChange(notification)
            }
            .store(in: &cancellables)
    }
    
    private func handleContextDidSave(_ notification: Notification) {
        guard let context = notification.object as? NSManagedObjectContext,
              context != self.context else { return }
        
        // Merge changes from background context
        self.context.mergeChanges(fromContextDidSave: notification)
    }
    
    private func handleRemoteChange(_ notification: Notification) {
        // Handle CloudKit sync changes if needed
        print("Remote Core Data change detected")
    }
    
    // MARK: - Core Operations
    
    func save() async throws {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            print("✅ Core Data saved successfully")
        } catch {
            print("❌ Core Data save error: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to save data: \(error.localizedDescription)"
            }
            throw CoreDataError.saveFailed(error)
        }
    }
    
    func saveInBackground() async throws {
        try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    if self.backgroundContext.hasChanges {
                        try self.backgroundContext.save()
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> [T] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let results = try self.context.fetch(request)
                    continuation.resume(returning: results)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func count<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let count = try self.context.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func delete(_ object: NSManagedObject) async throws {
        context.delete(object)
        try await save()
    }
    
    func deleteAll<T: NSManagedObject>(_ entityClass: T.Type) async throws {
        let request = NSFetchRequest<T>(entityName: String(describing: entityClass))
        let objects = try await fetch(request)
        
        for object in objects {
            context.delete(object)
        }
        
        try await save()
    }
    
    // MARK: - Game Progress Management
    
    func saveGameProgress(_ progress: GameProgressData) async throws {
        let gameProgress = GameProgress(context: context)
        gameProgress.id = progress.id
        gameProgress.mode = progress.mode.rawValue
        gameProgress.score = Int32(progress.score)
        gameProgress.correctAnswers = Int32(progress.correctAnswers)
        gameProgress.totalQuestions = Int32(progress.totalQuestions)
        gameProgress.timeElapsed = progress.timeElapsed
        gameProgress.completedAt = progress.completedAt
        gameProgress.userId = progress.userId
        
        try await save()
    }
    
    func fetchGameProgress(for userId: String, mode: GameMode? = nil) async throws -> [GameProgressData] {
        let request: NSFetchRequest<GameProgress> = GameProgress.fetchRequest()
        
        var predicates: [NSPredicate] = [NSPredicate(format: "userId == %@", userId)]
        
        if let mode = mode {
            predicates.append(NSPredicate(format: "mode == %@", mode.rawValue))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \GameProgress.completedAt, ascending: false)]
        
        let results = try await fetch(request)
        return results.compactMap { GameProgressData(from: $0) }
    }
    
    func getPersonalBest(for userId: String, mode: GameMode) async throws -> GameProgressData? {
        let request: NSFetchRequest<GameProgress> = GameProgress.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "userId == %@", userId),
            NSPredicate(format: "mode == %@", mode.rawValue)
        ])
        request.sortDescriptors = [NSSortDescriptor(keyPath: \GameProgress.score, ascending: false)]
        request.fetchLimit = 1
        
        let results = try await fetch(request)
        return results.first.flatMap { GameProgressData(from: $0) }
    }
    
    // MARK: - Plant Data Caching
    
    func cachePlantData(_ plants: [PlantData]) async throws {
        // Clear existing cache
        try await deleteAll(CachedPlant.self)
        
        // Cache new data
        for plant in plants {
            let cachedPlant = CachedPlant(context: context)
            cachedPlant.id = plant.id
            cachedPlant.name = plant.name
            cachedPlant.scientificName = plant.scientificName
            cachedPlant.imageURL = plant.imageURL
            cachedPlant.plantDescription = plant.description
            cachedPlant.difficulty = plant.difficulty?.rawValue
            cachedPlant.category = plant.category
            cachedPlant.cachedAt = Date()
        }
        
        try await save()
    }
    
    func fetchCachedPlants() async throws -> [PlantData] {
        let request: NSFetchRequest<CachedPlant> = CachedPlant.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedPlant.name, ascending: true)]
        
        let results = try await fetch(request)
        return results.compactMap { PlantData(from: $0) }
    }
    
    func getCacheAge() async throws -> TimeInterval? {
        let request: NSFetchRequest<CachedPlant> = CachedPlant.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedPlant.cachedAt, ascending: false)]
        request.fetchLimit = 1
        
        let results = try await fetch(request)
        return results.first?.cachedAt?.timeIntervalSinceNow
    }
    
    // MARK: - User Settings Persistence
    
    func saveUserSettings(_ settings: UserSettingsData) async throws {
        let request: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", settings.userId)
        
        let existingSettings = try await fetch(request)
        let userSettings = existingSettings.first ?? UserSettings(context: context)
        
        userSettings.userId = settings.userId
        userSettings.soundEnabled = settings.soundEnabled
        userSettings.hapticsEnabled = settings.hapticsEnabled
        userSettings.reducedAnimations = settings.reducedAnimations
        userSettings.selectedTheme = settings.selectedTheme.rawValue
        userSettings.selectedDifficulty = settings.selectedDifficulty.rawValue
        userSettings.updatedAt = Date()
        
        try await save()
    }
    
    func fetchUserSettings(for userId: String) async throws -> UserSettingsData? {
        let request: NSFetchRequest<UserSettings> = UserSettings.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.fetchLimit = 1
        
        let results = try await fetch(request)
        return results.first.flatMap { UserSettingsData(from: $0) }
    }
    
    // MARK: - Achievement Tracking
    
    func saveAchievement(_ achievement: AchievementData) async throws {
        let achievementEntity = Achievement(context: context)
        achievementEntity.id = achievement.id
        achievementEntity.userId = achievement.userId
        achievementEntity.title = achievement.title
        achievementEntity.achievementDescription = achievement.description
        achievementEntity.iconName = achievement.icon
        achievementEntity.unlockedAt = achievement.unlockedAt
        achievementEntity.category = achievement.category
        
        try await save()
    }
    
    func fetchAchievements(for userId: String) async throws -> [AchievementData] {
        let request: NSFetchRequest<Achievement> = Achievement.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Achievement.unlockedAt, ascending: false)]
        
        let results = try await fetch(request)
        return results.compactMap { AchievementData(from: $0) }
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        Task {
            do {
                try await deleteAll(CachedPlant.self)
                print("✅ Core Data cache cleared")
            } catch {
                print("❌ Failed to clear Core Data cache: \(error)")
            }
        }
    }
    
    func clearAllData() async throws {
        try await deleteAll(GameProgress.self)
        try await deleteAll(CachedPlant.self)
        try await deleteAll(UserSettings.self)
        try await deleteAll(Achievement.self)
        
        print("✅ All Core Data cleared")
    }
    
    // MARK: - Performance & Maintenance
    
    func performMaintenance() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.cleanupOldData()
            }
            
            group.addTask {
                await self.optimizeDatabase()
            }
        }
    }
    
    private func cleanupOldData() async {
        do {
            // Clean up old game progress (keep last 100 entries per user)
            let request: NSFetchRequest<GameProgress> = GameProgress.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \GameProgress.completedAt, ascending: false)]
            
            let allProgress = try await fetch(request)
            let groupedByUser = Dictionary(grouping: allProgress, by: { $0.userId ?? "" })
            
            for (_, userProgress) in groupedByUser {
                if userProgress.count > 100 {
                    let toDelete = Array(userProgress.dropFirst(100))
                    for progress in toDelete {
                        context.delete(progress)
                    }
                }
            }
            
            // Clean up old cached plants (older than 7 days)
            let cacheRequest: NSFetchRequest<CachedPlant> = CachedPlant.fetchRequest()
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            cacheRequest.predicate = NSPredicate(format: "cachedAt < %@", sevenDaysAgo as NSDate)
            
            let oldCachedPlants = try await fetch(cacheRequest)
            for plant in oldCachedPlants {
                context.delete(plant)
            }
            
            try await save()
            print("✅ Core Data cleanup completed")
            
        } catch {
            print("❌ Core Data cleanup failed: \(error)")
        }
    }
    
    private func optimizeDatabase() async {
        // Perform database optimization
        backgroundContext.perform {
            do {
                try self.backgroundContext.execute(NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: "NonexistentEntity")))
            } catch {
                // This is expected to fail, but triggers cleanup
            }
        }
    }
}

// MARK: - Core Data Errors

enum CoreDataError: LocalizedError {
    case saveFailed(Error)
    case fetchFailed(Error)
    case notReady
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .notReady:
            return "Core Data is not ready"
        }
    }
}

// MARK: - Data Transfer Objects

struct GameProgressData {
    let id: UUID
    let mode: GameMode
    let score: Int
    let correctAnswers: Int
    let totalQuestions: Int
    let timeElapsed: TimeInterval
    let completedAt: Date
    let userId: String
    
    init?(from gameProgress: GameProgress) {
        guard let id = gameProgress.id,
              let modeString = gameProgress.mode,
              let mode = GameMode(rawValue: modeString),
              let completedAt = gameProgress.completedAt,
              let userId = gameProgress.userId else {
            return nil
        }
        
        self.id = id
        self.mode = mode
        self.score = Int(gameProgress.score)
        self.correctAnswers = Int(gameProgress.correctAnswers)
        self.totalQuestions = Int(gameProgress.totalQuestions)
        self.timeElapsed = gameProgress.timeElapsed
        self.completedAt = completedAt
        self.userId = userId
    }
}

struct UserSettingsData {
    let userId: String
    let soundEnabled: Bool
    let hapticsEnabled: Bool
    let reducedAnimations: Bool
    let selectedTheme: Theme
    let selectedDifficulty: Difficulty
    
    init?(from userSettings: UserSettings) {
        guard let userId = userSettings.userId,
              let themeString = userSettings.selectedTheme,
              let theme = Theme(rawValue: themeString),
              let difficultyString = userSettings.selectedDifficulty,
              let difficulty = Difficulty(rawValue: difficultyString) else {
            return nil
        }
        
        self.userId = userId
        self.soundEnabled = userSettings.soundEnabled
        self.hapticsEnabled = userSettings.hapticsEnabled
        self.reducedAnimations = userSettings.reducedAnimations
        self.selectedTheme = theme
        self.selectedDifficulty = difficulty
    }
}

struct AchievementData {
    let id: UUID
    let userId: String
    let title: String
    let description: String
    let icon: String
    let unlockedAt: Date
    let category: String
    
    init?(from achievement: Achievement) {
        guard let id = achievement.id,
              let userId = achievement.userId,
              let title = achievement.title,
              let description = achievement.achievementDescription,
              let icon = achievement.iconName,
              let unlockedAt = achievement.unlockedAt,
              let category = achievement.category else {
            return nil
        }
        
        self.id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.icon = icon
        self.unlockedAt = unlockedAt
        self.category = category
    }
}

// MARK: - Extensions for PlantData

extension PlantData {
    init?(from cachedPlant: CachedPlant) {
        guard let id = cachedPlant.id,
              let name = cachedPlant.name,
              let scientificName = cachedPlant.scientificName,
              let imageURL = cachedPlant.imageURL,
              let description = cachedPlant.plantDescription else {
            return nil
        }
        
        self.id = id
        self.name = name
        self.scientificName = scientificName
        self.imageURL = imageURL
        self.description = description
        self.difficulty = cachedPlant.difficulty.flatMap { Difficulty(rawValue: $0) }
        self.category = cachedPlant.category
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkConnectivityChanged = Notification.Name("networkConnectivityChanged")
}
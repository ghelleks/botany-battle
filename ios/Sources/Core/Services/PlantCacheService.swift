import Foundation
import CoreData
import Dependencies

// MARK: - Plant Cache Service Protocol

protocol PlantCacheServiceProtocol {
    func cachePlants(_ plants: [Plant]) async throws
    func getCachedPlants(forDifficulty difficulty: Game.Difficulty?, limit: Int?) async throws -> [Plant]
    func getCachedPlant(id: String) async throws -> Plant?
    func getCachedPlantsForFamily(_ family: String, limit: Int) async throws -> [Plant]
    func clearOldCache(olderThan days: Int) async throws
    func recordPlantUsage(_ plantId: String) async throws
    func getCacheStatistics() async throws -> CacheStatistics
    func preloadInitialPlants() async throws
}

// MARK: - Cache Statistics

struct CacheStatistics {
    let totalCachedPlants: Int
    let cacheSize: Int64 // in bytes
    let oldestCacheDate: Date?
    let newestCacheDate: Date?
    let averageUseCount: Double
    let lastCleanupDate: Date?
    
    var formattedCacheSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: cacheSize)
    }
}

// MARK: - Plant Cache Service Implementation

final class PlantCacheService: PlantCacheServiceProtocol {
    private let context: NSManagedObjectContext
    private let maxCacheSize = 500 // Maximum number of plants to keep cached
    private let cacheExpiryDays = 30 // Days after which cache is considered old
    
    @Dependency(\.plantAPIService) var plantAPIService
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Public Methods
    
    func cachePlants(_ plants: [Plant]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for plant in plants {
                group.addTask {
                    try await self.cacheSinglePlant(plant)
                }
            }
            try await group.waitForAll()
        }
        
        try await cleanupCacheIfNeeded()
    }
    
    func getCachedPlants(forDifficulty difficulty: Game.Difficulty?, limit: Int?) async throws -> [Plant] {
        return try await context.perform {
            let request: NSFetchRequest<CachedPlantEntity> = CachedPlantEntity.fetchRequest()
            
            var predicates: [NSPredicate] = []
            
            if let difficulty = difficulty {
                let range = self.getDifficultyRange(difficulty)
                predicates.append(NSPredicate(format: "difficulty >= %d AND difficulty <= %d", range.min, range.max))
            }
            
            if !predicates.isEmpty {
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }
            
            // Sort by last used date and use count for better game experience
            request.sortDescriptors = [
                NSSortDescriptor(key: "useCount", ascending: true),
                NSSortDescriptor(key: "lastUsed", ascending: true)
            ]
            
            if let limit = limit {
                request.fetchLimit = limit
            }
            
            let entities = try self.context.fetch(request)
            return entities.compactMap { $0.toPlant() }
        }
    }
    
    func getCachedPlant(id: String) async throws -> Plant? {
        return try await context.perform {
            let request: NSFetchRequest<CachedPlantEntity> = CachedPlantEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id)
            request.fetchLimit = 1
            
            guard let entity = try self.context.fetch(request).first else {
                return nil
            }
            
            return entity.toPlant()
        }
    }
    
    func getCachedPlantsForFamily(_ family: String, limit: Int) async throws -> [Plant] {
        return try await context.perform {
            let request: NSFetchRequest<CachedPlantEntity> = CachedPlantEntity.fetchRequest()
            request.predicate = NSPredicate(format: "family == %@", family)
            request.sortDescriptors = [
                NSSortDescriptor(key: "useCount", ascending: true),
                NSSortDescriptor(key: "lastUsed", ascending: true)
            ]
            request.fetchLimit = limit
            
            let entities = try self.context.fetch(request)
            return entities.compactMap { $0.toPlant() }
        }
    }
    
    func clearOldCache(olderThan days: Int) async throws {
        try await context.perform {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            
            let request: NSFetchRequest<CachedPlantEntity> = CachedPlantEntity.fetchRequest()
            request.predicate = NSPredicate(format: "cachedAt < %@", cutoffDate as NSDate)
            
            let oldEntities = try self.context.fetch(request)
            
            for entity in oldEntities {
                self.context.delete(entity)
            }
            
            if self.context.hasChanges {
                try self.context.save()
            }
        }
    }
    
    func recordPlantUsage(_ plantId: String) async throws {
        try await context.perform {
            let request: NSFetchRequest<CachedPlantEntity> = CachedPlantEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", plantId)
            request.fetchLimit = 1
            
            guard let entity = try self.context.fetch(request).first else {
                return
            }
            
            entity.useCount += 1
            entity.lastUsed = Date()
            
            if self.context.hasChanges {
                try self.context.save()
            }
        }
    }
    
    func getCacheStatistics() async throws -> CacheStatistics {
        return try await context.perform {
            let request: NSFetchRequest<CachedPlantEntity> = CachedPlantEntity.fetchRequest()
            
            let entities = try self.context.fetch(request)
            let totalCount = entities.count
            
            // Calculate cache size (rough estimate)
            let averageEntitySize: Int64 = 2048 // Rough estimate per plant entity
            let cacheSize = Int64(totalCount) * averageEntitySize
            
            let dates = entities.map { $0.cachedAt }
            let useCounts = entities.map { $0.useCount }
            
            return CacheStatistics(
                totalCachedPlants: totalCount,
                cacheSize: cacheSize,
                oldestCacheDate: dates.min(),
                newestCacheDate: dates.max(),
                averageUseCount: useCounts.isEmpty ? 0 : Double(useCounts.reduce(0, +)) / Double(useCounts.count),
                lastCleanupDate: UserDefaults.standard.object(forKey: "lastCacheCleanup") as? Date
            )
        }
    }
    
    func preloadInitialPlants() async throws {
        let currentCacheCount = try await getCurrentCacheCount()
        
        // Only preload if we have less than 100 plants cached
        guard currentCacheCount < 100 else {
            return
        }
        
        let plantsToFetch = 200 - currentCacheCount
        
        // Fetch plants across different difficulties
        let difficulties: [Game.Difficulty] = [.easy, .medium, .hard, .expert]
        let plantsPerDifficulty = plantsToFetch / difficulties.count
        
        var allPlants: [Plant] = []
        
        for difficulty in difficulties {
            do {
                let plants = try await plantAPIService.fetchPopularPlants(
                    difficulty: difficulty,
                    limit: plantsPerDifficulty
                )
                allPlants.append(contentsOf: plants)
            } catch {
                // Continue with other difficulties if one fails
                print("Failed to preload plants for difficulty \(difficulty): \(error)")
                continue
            }
        }
        
        if !allPlants.isEmpty {
            try await cachePlants(allPlants)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func cacheSinglePlant(_ plant: Plant) async throws {
        try await context.perform {
            // Check if plant already exists
            let request: NSFetchRequest<CachedPlantEntity> = CachedPlantEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", plant.id)
            request.fetchLimit = 1
            
            let existingEntity = try self.context.fetch(request).first
            let entity = existingEntity ?? CachedPlantEntity(context: self.context)
            
            // Update entity with plant data
            entity.updateFromPlant(plant)
            
            if self.context.hasChanges {
                try self.context.save()
            }
        }
    }
    
    private func cleanupCacheIfNeeded() async throws {
        let currentCount = try await getCurrentCacheCount()
        
        guard currentCount > maxCacheSize else {
            return
        }
        
        // Remove least used plants that haven't been used recently
        try await context.perform {
            let request: NSFetchRequest<CachedPlantEntity> = CachedPlantEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "useCount", ascending: true),
                NSSortDescriptor(key: "lastUsed", ascending: true)
            ]
            
            let entitiesToRemove = currentCount - self.maxCacheSize
            request.fetchLimit = entitiesToRemove
            
            let entities = try self.context.fetch(request)
            
            for entity in entities {
                self.context.delete(entity)
            }
            
            if self.context.hasChanges {
                try self.context.save()
            }
            
            // Record cleanup date
            UserDefaults.standard.set(Date(), forKey: "lastCacheCleanup")
        }
    }
    
    private func getCurrentCacheCount() async throws -> Int {
        return try await context.perform {
            let request: NSFetchRequest<CachedPlantEntity> = CachedPlantEntity.fetchRequest()
            return try self.context.count(for: request)
        }
    }
    
    private func getDifficultyRange(_ difficulty: Game.Difficulty) -> (min: Int, max: Int) {
        switch difficulty {
        case .easy:
            return (min: 1, max: 25)
        case .medium:
            return (min: 26, max: 50)
        case .hard:
            return (min: 51, max: 75)
        case .expert:
            return (min: 76, max: 100)
        }
    }
}

// MARK: - CachedPlantEntity Extensions

extension CachedPlantEntity {
    func updateFromPlant(_ plant: Plant) {
        self.id = plant.id
        self.scientificName = plant.scientificName
        self.commonNames = plant.commonNames.joined(separator: ",")
        self.family = plant.family
        self.genus = plant.genus
        self.species = plant.species
        self.imageURL = plant.imageURL
        self.thumbnailURL = plant.thumbnailURL
        self.description_ = plant.description
        self.difficulty = Int32(plant.difficulty)
        self.rarity = plant.rarity.rawValue
        self.habitat = plant.habitat.joined(separator: ",")
        self.regions = plant.regions.joined(separator: ",")
        self.iNaturalistId = Int32(plant.iNaturalistId ?? 0)
        
        // Update cache metadata
        if self.cachedAt == Date.distantPast || self.cachedAt == nil {
            self.cachedAt = Date()
        }
        if self.lastUsed == Date.distantPast || self.lastUsed == nil {
            self.lastUsed = Date()
        }
    }
    
    func toPlant() -> Plant? {
        guard let id = id,
              let scientificName = scientificName,
              let commonNames = commonNames,
              let family = family,
              let genus = genus,
              let species = species,
              let imageURL = imageURL,
              let rarityString = rarity,
              let rarity = Plant.Rarity(rawValue: rarityString),
              let habitat = habitat,
              let regions = regions else {
            return nil
        }
        
        let commonNamesArray = commonNames.components(separatedBy: ",").filter { !$0.isEmpty }
        let habitatArray = habitat.components(separatedBy: ",").filter { !$0.isEmpty }
        let regionsArray = regions.components(separatedBy: ",").filter { !$0.isEmpty }
        
        // Create basic characteristics - could be enhanced with more detailed cached data
        let characteristics = Plant.Characteristics(
            leafType: nil,
            flowerColor: [],
            bloomTime: [],
            height: nil,
            sunRequirement: nil,
            waterRequirement: nil,
            soilType: []
        )
        
        return Plant(
            id: id,
            scientificName: scientificName,
            commonNames: commonNamesArray,
            family: family,
            genus: genus,
            species: species,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            description: description_,
            difficulty: Int(difficulty),
            rarity: rarity,
            habitat: habitatArray,
            regions: regionsArray,
            characteristics: characteristics,
            iNaturalistId: iNaturalistId > 0 ? Int(iNaturalistId) : nil
        )
    }
}

// MARK: - Mock Implementation

final class MockPlantCacheService: PlantCacheServiceProtocol {
    private var cachedPlants: [Plant] = []
    private var usageCounts: [String: Int] = [:]
    
    func cachePlants(_ plants: [Plant]) async throws {
        cachedPlants.append(contentsOf: plants)
        // Remove duplicates
        cachedPlants = Array(Set(cachedPlants.map { $0.id })).compactMap { id in
            cachedPlants.first { $0.id == id }
        }
    }
    
    func getCachedPlants(forDifficulty difficulty: Game.Difficulty?, limit: Int?) async throws -> [Plant] {
        var filtered = cachedPlants
        
        if let difficulty = difficulty {
            filtered = filtered.filter { $0.difficultyLevel == difficulty }
        }
        
        if let limit = limit {
            filtered = Array(filtered.prefix(limit))
        }
        
        return filtered
    }
    
    func getCachedPlant(id: String) async throws -> Plant? {
        return cachedPlants.first { $0.id == id }
    }
    
    func getCachedPlantsForFamily(_ family: String, limit: Int) async throws -> [Plant] {
        let filtered = cachedPlants.filter { $0.family == family }
        return Array(filtered.prefix(limit))
    }
    
    func clearOldCache(olderThan days: Int) async throws {
        // In mock, just clear half the cache
        cachedPlants = Array(cachedPlants.suffix(cachedPlants.count / 2))
    }
    
    func recordPlantUsage(_ plantId: String) async throws {
        usageCounts[plantId] = (usageCounts[plantId] ?? 0) + 1
    }
    
    func getCacheStatistics() async throws -> CacheStatistics {
        return CacheStatistics(
            totalCachedPlants: cachedPlants.count,
            cacheSize: Int64(cachedPlants.count * 2048),
            oldestCacheDate: Date().addingTimeInterval(-86400 * 7), // 7 days ago
            newestCacheDate: Date(),
            averageUseCount: usageCounts.values.isEmpty ? 0 : Double(usageCounts.values.reduce(0, +)) / Double(usageCounts.values.count),
            lastCleanupDate: Date().addingTimeInterval(-86400) // 1 day ago
        )
    }
    
    func preloadInitialPlants() async throws {
        // In mock, just add some initial plants
        let mockPlants = [
            Plant(
                id: "mock_preload_1",
                scientificName: "Quercus robur",
                commonNames: ["English Oak"],
                family: "Fagaceae",
                genus: "Quercus",
                species: "robur",
                imageURL: "https://picsum.photos/400/300?random=1",
                thumbnailURL: "https://picsum.photos/100/100?random=1",
                description: "A large deciduous tree",
                difficulty: 25,
                rarity: .common,
                habitat: ["Forest"],
                regions: ["Europe"],
                characteristics: Plant.Characteristics(
                    leafType: "Broadleaf",
                    flowerColor: [],
                    bloomTime: [],
                    height: nil,
                    sunRequirement: nil,
                    waterRequirement: nil,
                    soilType: []
                ),
                iNaturalistId: 123456
            )
        ]
        
        try await cachePlants(mockPlants)
    }
}

// MARK: - Dependency Registration

extension DependencyValues {
    var plantCacheService: PlantCacheServiceProtocol {
        get { self[PlantCacheServiceKey.self] }
        set { self[PlantCacheServiceKey.self] = newValue }
    }
}

private enum PlantCacheServiceKey: DependencyKey {
    static let liveValue: PlantCacheServiceProtocol = PlantCacheService(
        context: CoreDataStack.shared.context
    )
    static let testValue: PlantCacheServiceProtocol = MockPlantCacheService()
}
import XCTest
import Dependencies
@testable import BotanyBattle

final class PlantCacheServiceTests: XCTestCase {
    
    func testCachePlantsBasicFunctionality() async throws {
        // Given
        let mockCacheService = MockPlantCacheService()
        let testPlants = createTestPlants(count: 3)
        
        // When
        try await mockCacheService.cachePlants(testPlants)
        
        // Then
        let cachedPlants = try await mockCacheService.getCachedPlants(forDifficulty: nil, limit: nil)
        XCTAssertEqual(cachedPlants.count, 3)
        
        // Verify plant IDs match
        let cachedIds = Set(cachedPlants.map { $0.id })
        let originalIds = Set(testPlants.map { $0.id })
        XCTAssertEqual(cachedIds, originalIds)
    }
    
    func testGetCachedPlantsByDifficulty() async throws {
        // Given
        let mockCacheService = MockPlantCacheService()
        let easyPlants = createTestPlants(count: 2, difficulty: .easy)
        let hardPlants = createTestPlants(count: 2, difficulty: .hard, startIndex: 2)
        
        try await mockCacheService.cachePlants(easyPlants + hardPlants)
        
        // When
        let retrievedEasyPlants = try await mockCacheService.getCachedPlants(forDifficulty: .easy, limit: nil)
        let retrievedHardPlants = try await mockCacheService.getCachedPlants(forDifficulty: .hard, limit: nil)
        
        // Then
        XCTAssertEqual(retrievedEasyPlants.count, 2)
        XCTAssertEqual(retrievedHardPlants.count, 2)
        
        // Verify difficulty filtering
        for plant in retrievedEasyPlants {
            XCTAssertEqual(plant.difficultyLevel, .easy)
        }
        
        for plant in retrievedHardPlants {
            XCTAssertEqual(plant.difficultyLevel, .hard)
        }
    }
    
    func testGetCachedPlantsByDifficultyWithLimit() async throws {
        // Given
        let mockCacheService = MockPlantCacheService()
        let testPlants = createTestPlants(count: 5, difficulty: .medium)
        
        try await mockCacheService.cachePlants(testPlants)
        
        // When
        let limitedPlants = try await mockCacheService.getCachedPlants(forDifficulty: .medium, limit: 3)
        
        // Then
        XCTAssertEqual(limitedPlants.count, 3)
    }
    
    func testGetCachedPlantById() async throws {
        // Given
        let mockCacheService = MockPlantCacheService()
        let testPlants = createTestPlants(count: 3)
        let targetPlant = testPlants[1]
        
        try await mockCacheService.cachePlants(testPlants)
        
        // When
        let retrievedPlant = try await mockCacheService.getCachedPlant(id: targetPlant.id)
        
        // Then
        XCTAssertNotNil(retrievedPlant)
        XCTAssertEqual(retrievedPlant!.id, targetPlant.id)
        XCTAssertEqual(retrievedPlant!.scientificName, targetPlant.scientificName)
    }
    
    func testGetCachedPlantByIdNotFound() async throws {
        // Given
        let mockCacheService = MockPlantCacheService()
        let testPlants = createTestPlants(count: 2)
        
        try await mockCacheService.cachePlants(testPlants)
        
        // When
        let retrievedPlant = try await mockCacheService.getCachedPlant(id: "nonexistent_id")
        
        // Then
        XCTAssertNil(retrievedPlant)
    }
    
    func testGetCachedPlantsForFamily() async throws {
        // Given
        let mockCacheService = MockPlantCacheService()
        let rosaceaePlants = createTestPlantsWithFamily(count: 3, family: "Rosaceae")
        let asteraceaePlants = createTestPlantsWithFamily(count: 2, family: "Asteraceae", startIndex: 3)
        
        try await mockCacheService.cachePlants(rosaceaePlants + asteraceaePlants)
        
        // When
        let rosaceaeResults = try await mockCacheService.getCachedPlantsForFamily("Rosaceae", limit: 10)
        let asteraceaeResults = try await mockCacheService.getCachedPlantsForFamily("Asteraceae", limit: 10)
        
        // Then
        XCTAssertEqual(rosaceaeResults.count, 3)
        XCTAssertEqual(asteraceaeResults.count, 2)
        
        // Verify family filtering
        for plant in rosaceaeResults {
            XCTAssertEqual(plant.family, "Rosaceae")
        }
        
        for plant in asteraceaeResults {
            XCTAssertEqual(plant.family, "Asteraceae")
        }
    }
    
    func testRecordPlantUsage() async throws {
        // Given
        let mockCacheService = MockPlantCacheService()
        let testPlants = createTestPlants(count: 1)
        let plantId = testPlants[0].id
        
        try await mockCacheService.cachePlants(testPlants)
        
        // When
        try await mockCacheService.recordPlantUsage(plantId)
        try await mockCacheService.recordPlantUsage(plantId)
        try await mockCacheService.recordPlantUsage(plantId)
        
        // Then
        let stats = try await mockCacheService.getCacheStatistics()
        XCTAssertGreaterThan(stats.averageUseCount, 0)
    }
    
    func testClearOldCache() async throws {
        // Given
        let mockCacheService = MockPlantCacheService()
        let testPlants = createTestPlants(count: 4)
        
        try await mockCacheService.cachePlants(testPlants)
        
        // When
        try await mockCacheService.clearOldCache(olderThan: 7)
        
        // Then
        let remainingPlants = try await mockCacheService.getCachedPlants(forDifficulty: nil, limit: nil)
        // Mock implementation should clear half the cache
        XCTAssertEqual(remainingPlants.count, 2)
    }
    
    func testGetCacheStatistics() async throws {
        // Given
        let mockCacheService = MockPlantCacheService()
        let testPlants = createTestPlants(count: 5)
        
        try await mockCacheService.cachePlants(testPlants)
        
        // Record some usage
        try await mockCacheService.recordPlantUsage(testPlants[0].id)
        try await mockCacheService.recordPlantUsage(testPlants[1].id)
        
        // When
        let stats = try await mockCacheService.getCacheStatistics()
        
        // Then
        XCTAssertEqual(stats.totalCachedPlants, 5)
        XCTAssertGreaterThan(stats.cacheSize, 0)
        XCTAssertNotNil(stats.oldestCacheDate)
        XCTAssertNotNil(stats.newestCacheDate)
        XCTAssertNotNil(stats.lastCleanupDate)
        
        // Test formatted cache size
        XCTAssertFalse(stats.formattedCacheSize.isEmpty)
    }
    
    func testPreloadInitialPlants() async throws {
        // Given
        let mockCacheService = MockPlantCacheService()
        
        // When
        try await mockCacheService.preloadInitialPlants()
        
        // Then
        let cachedPlants = try await mockCacheService.getCachedPlants(forDifficulty: nil, limit: nil)
        XCTAssertGreaterThan(cachedPlants.count, 0, "Should have preloaded some plants")
    }
    
    func testCacheDuplicatePlants() async throws {
        // Given
        let mockCacheService = MockPlantCacheService()
        let testPlants = createTestPlants(count: 2)
        
        // When - Cache the same plants twice
        try await mockCacheService.cachePlants(testPlants)
        try await mockCacheService.cachePlants(testPlants)
        
        // Then - Should not create duplicates
        let cachedPlants = try await mockCacheService.getCachedPlants(forDifficulty: nil, limit: nil)
        XCTAssertEqual(cachedPlants.count, 2, "Should not create duplicate entries")
    }
    
    func testCachePerformanceWithLargePlantSet() async throws {
        // Given
        let mockCacheService = MockPlantCacheService()
        let largePlantSet = createTestPlants(count: 100)
        
        // When/Then - Measure caching performance
        measure {
            let expectation = XCTestExpectation(description: "Cache large plant set")
            
            Task {
                do {
                    try await mockCacheService.cachePlants(largePlantSet)
                    expectation.fulfill()
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testCacheRetrievalPerformance() async throws {
        // Given
        let mockCacheService = MockPlantCacheService()
        let testPlants = createTestPlants(count: 50)
        
        try await mockCacheService.cachePlants(testPlants)
        
        // When/Then - Measure retrieval performance
        measure {
            let expectation = XCTestExpectation(description: "Retrieve cached plants")
            
            Task {
                do {
                    _ = try await mockCacheService.getCachedPlants(forDifficulty: .medium, limit: 20)
                    expectation.fulfill()
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 2.0)
        }
    }
    
    func testOfflineGameplayScenario() async throws {
        // Given - Simulate offline gameplay scenario
        let mockCacheService = MockPlantCacheService()
        let initialPlants = createTestPlants(count: 20, difficulty: .medium)
        
        // Pre-populate cache (simulating previous online session)
        try await mockCacheService.cachePlants(initialPlants)
        
        // When - Simulate multiple offline game sessions
        for sessionIndex in 0..<5 {
            let sessionPlants = try await mockCacheService.getCachedPlants(
                forDifficulty: .medium,
                limit: 4
            )
            
            XCTAssertGreaterThanOrEqual(sessionPlants.count, 4, "Should have enough cached plants for session \(sessionIndex)")
            
            // Record usage for each plant in the session
            for plant in sessionPlants {
                try await mockCacheService.recordPlantUsage(plant.id)
            }
        }
        
        // Then - Verify cache statistics reflect usage
        let finalStats = try await mockCacheService.getCacheStatistics()
        XCTAssertGreaterThan(finalStats.averageUseCount, 0, "Should have recorded plant usage")
    }
    
    func testIntegrationWithSingleUserGameService() async throws {
        // Given
        let mockCacheService = MockPlantCacheService()
        let mockAPIService = MockPlantAPIService()
        
        // Pre-populate cache
        let cachedPlants = createTestPlants(count: 10, difficulty: .medium)
        try await mockCacheService.cachePlants(cachedPlants)
        
        // When
        let gameService = withDependencies {
            $0.plantCacheService = mockCacheService
            $0.plantAPIService = mockAPIService
        } operation: {
            MockSingleUserGameService()
        }
        
        let session = gameService.startGame(mode: .beatTheClock, difficulty: .medium)
        let question = try await gameService.getCurrentQuestion(for: session)
        
        // Then
        XCTAssertNotNil(question.plant)
        XCTAssertEqual(question.options.count, 4)
        XCTAssertTrue(question.options.contains(question.plant.primaryCommonName))
    }
}

// MARK: - Test Helpers

extension PlantCacheServiceTests {
    
    func createTestPlants(count: Int, difficulty: Game.Difficulty = .medium, startIndex: Int = 0) -> [Plant] {
        return (startIndex..<(startIndex + count)).map { index in
            Plant(
                id: "test_plant_\(index)",
                scientificName: "Testus planticus \(index)",
                commonNames: ["Test Plant \(index)"],
                family: "Testaceae",
                genus: "Testus",
                species: "planticus",
                imageURL: "https://example.com/plant_\(index).jpg",
                thumbnailURL: "https://example.com/plant_\(index)_thumb.jpg",
                description: "A test plant #\(index) for caching tests",
                difficulty: difficulty.rawValue.hashValue % 100,
                rarity: .common,
                habitat: ["Test habitat \(index)"],
                regions: ["Test region \(index)"],
                characteristics: Plant.Characteristics(
                    leafType: nil,
                    flowerColor: ["Green"],
                    bloomTime: ["Spring"],
                    height: nil,
                    sunRequirement: nil,
                    waterRequirement: nil,
                    soilType: []
                ),
                iNaturalistId: 100000 + index
            )
        }
    }
    
    func createTestPlantsWithFamily(count: Int, family: String, startIndex: Int = 0) -> [Plant] {
        return (startIndex..<(startIndex + count)).map { index in
            Plant(
                id: "test_\(family.lowercased())_\(index)",
                scientificName: "\(family) testicus \(index)",
                commonNames: ["\(family) Test Plant \(index)"],
                family: family,
                genus: family,
                species: "testicus",
                imageURL: "https://example.com/\(family.lowercased())_\(index).jpg",
                thumbnailURL: "https://example.com/\(family.lowercased())_\(index)_thumb.jpg",
                description: "A test plant from \(family) family",
                difficulty: 50,
                rarity: .common,
                habitat: ["Test habitat"],
                regions: ["Test region"],
                characteristics: Plant.Characteristics(
                    leafType: nil,
                    flowerColor: ["Green"],
                    bloomTime: ["Spring"],
                    height: nil,
                    sunRequirement: nil,
                    waterRequirement: nil,
                    soilType: []
                ),
                iNaturalistId: 200000 + index
            )
        }
    }
}
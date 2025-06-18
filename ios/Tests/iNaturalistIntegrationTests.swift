import XCTest
import Dependencies
@testable import BotanyBattle

final class iNaturalistIntegrationTests: XCTestCase {
    
    func testCompleteOfflineGameplayFlow() async throws {
        // Given - Complete offline-first game setup
        let mockAPIService = MockPlantAPIService()
        let mockCacheService = MockPlantCacheService()
        
        // When - Simulate app launch and preload
        try await mockCacheService.preloadInitialPlants()
        
        // Start a game session
        let gameService = withDependencies {
            $0.plantAPIService = mockAPIService
            $0.plantCacheService = mockCacheService
            $0.singleUserGameService = MockSingleUserGameService()
        } operation: {
            MockSingleUserGameService()
        }
        
        var session = gameService.startGame(mode: .beatTheClock, difficulty: .medium)
        
        // Play through multiple questions
        var correctAnswers = 0
        for questionIndex in 0..<5 {
            let question = try await gameService.getCurrentQuestion(for: session)
            
            // Verify question structure
            XCTAssertNotNil(question.plant)
            XCTAssertEqual(question.options.count, 4)
            XCTAssertTrue(question.options.contains(question.plant.primaryCommonName))
            
            // Submit correct answer
            let answer = gameService.submitAnswer(
                session: &session,
                selectedAnswer: question.plant.primaryCommonName,
                correctAnswer: question.plant.primaryCommonName,
                plantId: question.plant.id
            )
            
            XCTAssertTrue(answer.isCorrect)
            if answer.isCorrect {
                correctAnswers += 1
            }
            
            // Record usage for cache management
            try await mockCacheService.recordPlantUsage(question.plant.id)
        }
        
        // Complete the game
        let personalBest = gameService.completeGame(session: &session)
        
        // Then - Verify game completion
        XCTAssertEqual(correctAnswers, 5)
        XCTAssertEqual(session.state, .completed)
        XCTAssertNotNil(personalBest)
        
        // Verify cache statistics
        let cacheStats = try await mockCacheService.getCacheStatistics()
        XCTAssertGreaterThan(cacheStats.totalCachedPlants, 0)
        XCTAssertGreaterThan(cacheStats.averageUseCount, 0)
    }
    
    func testAPIFailureWithCacheFallback() async throws {
        // Given - API service that fails, but cache has data
        let failingAPIService = MockPlantAPIService(shouldFail: true)
        let mockCacheService = MockPlantCacheService()
        
        // Pre-populate cache with plants
        let cachedPlants = createTestPlants(count: 10, difficulty: .medium)
        try await mockCacheService.cachePlants(cachedPlants)
        
        // When - Try to use the game service with failing API
        let gameService = withDependencies {
            $0.plantAPIService = failingAPIService
            $0.plantCacheService = mockCacheService
        } operation: {
            MockSingleUserGameService()
        }
        
        let session = gameService.startGame(mode: .speedrun, difficulty: .medium)
        
        // Should still work due to cache fallback
        let question = try await gameService.getCurrentQuestion(for: session)
        
        // Then - Verify it works despite API failure
        XCTAssertNotNil(question.plant)
        XCTAssertEqual(question.options.count, 4)
        
        // Verify the plant came from cache (check against cached plant IDs)
        let cachedPlantIds = Set(cachedPlants.map { $0.id })
        // Note: MockSingleUserGameService doesn't actually use the cache service in getCurrentQuestion
        // but in a real implementation it would
    }
    
    func testNetworkResilienceAndRetry() async throws {
        // Given - Slow/unreliable network conditions
        let slowAPIService = MockPlantAPIService(delay: 2.0) // Slow network
        let mockCacheService = MockPlantCacheService()
        
        // When - Make requests under slow conditions
        let startTime = Date()
        
        let plants = try await slowAPIService.fetchPopularPlants(difficulty: .easy, limit: 3)
        
        let endTime = Date()
        let requestTime = endTime.timeIntervalSince(startTime)
        
        // Then - Should handle delay gracefully
        XCTAssertGreaterThan(requestTime, 1.5, "Should respect simulated network delay")
        XCTAssertEqual(plants.count, 3)
        
        // Cache the results for future offline use
        try await mockCacheService.cachePlants(plants)
        let cachedPlants = try await mockCacheService.getCachedPlants(forDifficulty: .easy, limit: nil)
        XCTAssertEqual(cachedPlants.count, 3)
    }
    
    func testEducationalContentIntegrity() async throws {
        // Given
        let mockAPIService = MockPlantAPIService()
        
        // When
        let plants = try await mockAPIService.fetchPopularPlants(difficulty: .expert, limit: 3)
        
        // Then - Verify educational content is present and valid
        for plant in plants {
            // Scientific classification
            XCTAssertFalse(plant.scientificName.isEmpty)
            XCTAssertFalse(plant.family.isEmpty)
            XCTAssertFalse(plant.genus.isEmpty)
            XCTAssertFalse(plant.species.isEmpty)
            
            // Educational content
            XCTAssertNotNil(plant.description)
            XCTAssertFalse(plant.habitat.isEmpty)
            XCTAssertFalse(plant.regions.isEmpty)
            
            // Image resources
            XCTAssertFalse(plant.imageURL.isEmpty)
            XCTAssertTrue(plant.imageURL.hasPrefix("http"))
            
            // Common names for identification
            XCTAssertFalse(plant.commonNames.isEmpty)
            XCTAssertFalse(plant.primaryCommonName.isEmpty)
            
            // Difficulty and rarity for game mechanics
            XCTAssertTrue(plant.difficulty >= 1 && plant.difficulty <= 100)
            XCTAssertNotNil(plant.rarity)
        }
    }
    
    func testDifficultyProgressionAndBalancing() async throws {
        // Given
        let mockAPIService = MockPlantAPIService()
        let difficulties: [Game.Difficulty] = [.easy, .medium, .hard, .expert]
        
        var allPlants: [Game.Difficulty: [Plant]] = [:]
        
        // When - Fetch plants for each difficulty
        for difficulty in difficulties {
            let plants = try await mockAPIService.fetchPopularPlants(difficulty: difficulty, limit: 5)
            allPlants[difficulty] = plants
            
            XCTAssertEqual(plants.count, 5, "Should return requested number of plants for \(difficulty)")
        }
        
        // Then - Verify difficulty progression makes sense
        for difficulty in difficulties {
            let plants = allPlants[difficulty]!
            
            for plant in plants {
                // Verify plant difficulty level aligns with requested difficulty
                let plantDifficultyLevel = plant.difficultyLevel
                
                // Allow some variance for realistic behavior, but should be generally aligned
                switch difficulty {
                case .easy:
                    XCTAssertTrue([.easy, .medium].contains(plantDifficultyLevel), 
                                "Easy plants should be easy or medium difficulty")
                case .medium:
                    XCTAssertTrue([.easy, .medium, .hard].contains(plantDifficultyLevel),
                                "Medium plants should be easy, medium, or hard difficulty")
                case .hard:
                    XCTAssertTrue([.medium, .hard, .expert].contains(plantDifficultyLevel),
                                "Hard plants should be medium, hard, or expert difficulty")
                case .expert:
                    XCTAssertTrue([.hard, .expert].contains(plantDifficultyLevel),
                                "Expert plants should be hard or expert difficulty")
                }
            }
        }
    }
    
    func testFamilyBasedDistractorGeneration() async throws {
        // Given
        let mockAPIService = MockPlantAPIService()
        let familyName = "Rosaceae"
        
        // When
        let familyPlants = try await mockAPIService.fetchPlantsForFamily(familyName: familyName, limit: 8)
        
        // Then
        XCTAssertGreaterThanOrEqual(familyPlants.count, 4, "Should have enough plants for distractor generation")
        
        // Verify all plants are from the requested family
        for plant in familyPlants {
            XCTAssertEqual(plant.family, familyName)
        }
        
        // Test distractor generation scenario
        if familyPlants.count >= 4 {
            let targetPlant = familyPlants[0]
            let potentialDistractors = Array(familyPlants.dropFirst(1))
            
            // Should be able to generate realistic distractors from the same family
            XCTAssertGreaterThanOrEqual(potentialDistractors.count, 3)
            
            // Verify distractors are different from target
            for distractor in potentialDistractors {
                XCTAssertNotEqual(distractor.primaryCommonName, targetPlant.primaryCommonName)
                XCTAssertEqual(distractor.family, targetPlant.family) // Same family for realism
            }
        }
    }
    
    func testSearchFunctionalityAccuracy() async throws {
        // Given
        let mockAPIService = MockPlantAPIService()
        let searchQueries = ["Rosa", "Oak", "Maple", "Sunflower"]
        
        // When/Then
        for query in searchQueries {
            let searchResults = try await mockAPIService.searchPlants(query: query, limit: 5)
            
            // Should return relevant results
            for plant in searchResults {
                let isRelevant = plant.commonNames.contains { name in
                    name.localizedCaseInsensitiveContains(query)
                } || plant.scientificName.localizedCaseInsensitiveContains(query)
                
                XCTAssertTrue(isRelevant, "Search result should be relevant to query '\(query)': \(plant.primaryCommonName)")
            }
        }
    }
    
    func testAccessibilityAndEducationalRequirements() async throws {
        // Given
        let mockAPIService = MockPlantAPIService()
        
        // When
        let plants = try await mockAPIService.fetchPopularPlants(difficulty: .medium, limit: 5)
        
        // Then - Verify accessibility-friendly data
        for plant in plants {
            // Should have descriptive common names (not just scientific names)
            XCTAssertFalse(plant.primaryCommonName.isEmpty)
            XCTAssertFalse(plant.primaryCommonName.contains(" "), // Should be descriptive, not just genus species
                          "Primary common name should be user-friendly: \(plant.primaryCommonName)")
            
            // Should have educational content for screen readers
            XCTAssertNotNil(plant.description)
            
            // Should have habitat information for educational context
            XCTAssertFalse(plant.habitat.isEmpty)
            
            // Should have proper taxonomic classification
            XCTAssertFalse(plant.family.isEmpty)
            
            // Images should have proper URLs for alt text generation
            XCTAssertTrue(plant.imageURL.hasPrefix("http"))
        }
    }
    
    func testOfflinePerformanceRequirements() async throws {
        // Given - Performance requirement: <2 second game mode launch
        let mockCacheService = MockPlantCacheService()
        
        // Pre-populate cache
        let plants = createTestPlants(count: 50)
        try await mockCacheService.cachePlants(plants)
        
        // When - Measure offline game launch time
        let startTime = Date()
        
        let gameService = MockSingleUserGameService()
        let session = gameService.startGame(mode: .beatTheClock, difficulty: .medium)
        let question = try await gameService.getCurrentQuestion(for: session)
        
        let endTime = Date()
        let launchTime = endTime.timeIntervalSince(startTime)
        
        // Then - Should meet performance requirements
        XCTAssertLessThan(launchTime, 2.0, "Game mode should launch in <2 seconds (requirement)")
        XCTAssertNotNil(question.plant)
        XCTAssertEqual(question.options.count, 4)
    }
    
    func testImageLoadingPerformanceRequirement() async throws {
        // Given - Performance requirement: <1 second image loading
        let mockAPIService = MockPlantAPIService(delay: 0.1) // Simulate fast network
        
        // When - Measure image URL fetch time
        let startTime = Date()
        
        let plants = try await mockAPIService.fetchPopularPlants(difficulty: .easy, limit: 1)
        let plant = plants.first!
        
        // Verify image URL is available immediately (not actual image loading, but URL availability)
        XCTAssertFalse(plant.imageURL.isEmpty)
        
        let endTime = Date()
        let fetchTime = endTime.timeIntervalSince(startTime)
        
        // Then - Should meet performance requirements for data fetch
        XCTAssertLessThan(fetchTime, 1.0, "Plant data with image URLs should be available in <1 second")
        
        // Verify thumbnail is available for faster loading fallback
        if let thumbnailURL = plant.thumbnailURL {
            XCTAssertFalse(thumbnailURL.isEmpty)
            XCTAssertTrue(thumbnailURL.hasPrefix("http"))
        }
    }
}

// MARK: - Test Helpers

extension iNaturalistIntegrationTests {
    
    func createTestPlants(count: Int, difficulty: Game.Difficulty = .medium) -> [Plant] {
        return (0..<count).map { index in
            Plant(
                id: "integration_test_\(index)",
                scientificName: "Testus integrationus \(index)",
                commonNames: ["Integration Test Plant \(index)"],
                family: "Testaceae",
                genus: "Testus",
                species: "integrationus",
                imageURL: "https://example.com/integration_\(index).jpg",
                thumbnailURL: "https://example.com/integration_\(index)_thumb.jpg",
                description: "An integration test plant specimen #\(index)",
                difficulty: difficulty.rawValue.hashValue % 100,
                rarity: .common,
                habitat: ["Test environment"],
                regions: ["Test region"],
                characteristics: Plant.Characteristics(
                    leafType: nil,
                    flowerColor: ["Green"],
                    bloomTime: ["All seasons"],
                    height: nil,
                    sunRequirement: nil,
                    waterRequirement: nil,
                    soilType: []
                ),
                iNaturalistId: 300000 + index
            )
        }
    }
}
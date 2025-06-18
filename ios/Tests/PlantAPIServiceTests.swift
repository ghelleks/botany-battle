import XCTest
import Dependencies
@testable import BotanyBattle

final class PlantAPIServiceTests: XCTestCase {
    
    func testFetchPopularPlantsWithMockService() async throws {
        // Given
        let mockService = MockPlantAPIService()
        
        // When
        let plants = try await withDependencies {
            $0.plantAPIService = mockService
        } operation: {
            try await mockService.fetchPopularPlants(difficulty: .medium, limit: 5)
        }
        
        // Then
        XCTAssertEqual(plants.count, 5)
        XCTAssertFalse(plants.isEmpty)
        
        // Verify plant structure
        let firstPlant = plants[0]
        XCTAssertFalse(firstPlant.id.isEmpty)
        XCTAssertFalse(firstPlant.scientificName.isEmpty)
        XCTAssertFalse(firstPlant.commonNames.isEmpty)
        XCTAssertFalse(firstPlant.family.isEmpty)
        XCTAssertFalse(firstPlant.imageURL.isEmpty)
    }
    
    func testSearchPlantsWithMockService() async throws {
        // Given
        let mockService = MockPlantAPIService()
        let searchQuery = "Rose"
        
        // When
        let plants = try await mockService.searchPlants(query: searchQuery, limit: 3)
        
        // Then
        XCTAssertLessThanOrEqual(plants.count, 3)
        
        // Verify search results contain the query term
        for plant in plants {
            let containsQuery = plant.commonNames.contains { name in
                name.localizedCaseInsensitiveContains(searchQuery)
            } || plant.scientificName.localizedCaseInsensitiveContains(searchQuery)
            
            XCTAssertTrue(containsQuery, "Plant should contain search query: \(plant.primaryCommonName)")
        }
    }
    
    func testFetchPlantDetailsWithMockService() async throws {
        // Given
        let mockService = MockPlantAPIService()
        let plantId = 123456
        
        // When
        let plant = try await mockService.fetchPlantDetails(iNaturalistId: plantId)
        
        // Then
        XCTAssertNotNil(plant)
        XCTAssertFalse(plant!.id.isEmpty)
        XCTAssertFalse(plant!.scientificName.isEmpty)
    }
    
    func testFetchPlantsForFamilyWithMockService() async throws {
        // Given
        let mockService = MockPlantAPIService()
        let familyName = "Rosaceae"
        
        // When
        let plants = try await mockService.fetchPlantsForFamily(familyName: familyName, limit: 4)
        
        // Then
        XCTAssertLessThanOrEqual(plants.count, 4)
        
        // Verify all plants belong to the requested family
        for plant in plants {
            XCTAssertEqual(plant.family, familyName)
        }
    }
    
    func testFetchRandomPlantsWithMockService() async throws {
        // Given
        let mockService = MockPlantAPIService()
        
        // When
        let plants = try await mockService.fetchRandomPlants(limit: 6)
        
        // Then
        XCTAssertEqual(plants.count, 6)
        XCTAssertFalse(plants.isEmpty)
    }
    
    func testMockServiceFailureHandling() async throws {
        // Given
        let mockService = MockPlantAPIService(shouldFail: true)
        
        // When/Then
        do {
            _ = try await mockService.fetchPopularPlants(difficulty: .easy, limit: 1)
            XCTFail("Expected service to fail")
        } catch {
            XCTAssertTrue(error is iNaturalistAPIError)
        }
    }
    
    func testDifficultyMappingConsistency() async throws {
        // Given
        let mockService = MockPlantAPIService()
        let difficulties: [Game.Difficulty] = [.easy, .medium, .hard, .expert]
        
        // When/Then
        for difficulty in difficulties {
            let plants = try await mockService.fetchPopularPlants(difficulty: difficulty, limit: 2)
            
            XCTAssertFalse(plants.isEmpty, "Should return plants for difficulty: \(difficulty)")
            
            // Verify plants have appropriate difficulty mapping
            for plant in plants {
                let plantDifficultyLevel = plant.difficultyLevel
                // Allow some variance in difficulty mapping for realistic behavior
                XCTAssertTrue(
                    abs(plantDifficultyLevel.rawValue.hashValue - difficulty.rawValue.hashValue) < 50,
                    "Plant difficulty should be roughly aligned with requested difficulty"
                )
            }
        }
    }
    
    func testPlantDataIntegrity() async throws {
        // Given
        let mockService = MockPlantAPIService()
        
        // When
        let plants = try await mockService.fetchPopularPlants(difficulty: .medium, limit: 3)
        
        // Then
        for plant in plants {
            // Test required fields
            XCTAssertFalse(plant.id.isEmpty)
            XCTAssertFalse(plant.scientificName.isEmpty)
            XCTAssertFalse(plant.commonNames.isEmpty)
            XCTAssertFalse(plant.family.isEmpty)
            XCTAssertFalse(plant.genus.isEmpty)
            XCTAssertFalse(plant.species.isEmpty)
            XCTAssertFalse(plant.imageURL.isEmpty)
            
            // Test data consistency
            XCTAssertTrue(plant.difficulty >= 1 && plant.difficulty <= 100)
            XCTAssertNotNil(plant.rarity)
            XCTAssertFalse(plant.habitat.isEmpty)
            XCTAssertFalse(plant.regions.isEmpty)
            
            // Test scientific name format (should contain at least genus and species)
            let nameParts = plant.scientificName.components(separatedBy: " ")
            XCTAssertGreaterThanOrEqual(nameParts.count, 2, "Scientific name should have at least genus and species")
            
            // Test primary common name
            XCTAssertFalse(plant.primaryCommonName.isEmpty)
            XCTAssertTrue(plant.commonNames.contains(plant.primaryCommonName))
        }
    }
    
    func testConcurrentAPIRequests() async throws {
        // Given
        let mockService = MockPlantAPIService(delay: 0.1) // Small delay to simulate network
        
        // When - Make multiple concurrent requests
        async let plants1 = mockService.fetchPopularPlants(difficulty: .easy, limit: 2)
        async let plants2 = mockService.fetchPopularPlants(difficulty: .medium, limit: 2)
        async let plants3 = mockService.fetchPopularPlants(difficulty: .hard, limit: 2)
        
        let results = try await [plants1, plants2, plants3]
        
        // Then
        XCTAssertEqual(results.count, 3)
        for plantList in results {
            XCTAssertEqual(plantList.count, 2)
        }
    }
    
    func testRateLimiterBasicFunctionality() async throws {
        // Given
        let rateLimiter = RateLimiter(maxRequestsPerSecond: 2.0, maxRequestsPerDay: 100)
        
        let startTime = Date()
        
        // When - Make requests that should be rate limited
        try await rateLimiter.waitIfNeeded()
        try await rateLimiter.waitIfNeeded()
        try await rateLimiter.waitIfNeeded()
        
        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        
        // Then - Should take at least 1 second due to rate limiting (2 requests per second)
        XCTAssertGreaterThan(totalTime, 0.9, "Rate limiter should introduce delay")
    }
    
    func testCircuitBreakerBasicFunctionality() async throws {
        // Given
        let circuitBreaker = CircuitBreaker(failureThreshold: 2, timeout: 1.0)
        var callCount = 0
        
        // When/Then - Test failure threshold
        for _ in 0..<3 {
            do {
                try await circuitBreaker.execute {
                    callCount += 1
                    throw NSError(domain: "TestError", code: 500)
                }
                XCTFail("Should have thrown an error")
            } catch {
                // Expected to fail
            }
        }
        
        // After failure threshold, circuit should be open
        do {
            try await circuitBreaker.execute {
                callCount += 1
                return "success"
            }
            XCTFail("Circuit should be open")
        } catch {
            // Expected - circuit is open
        }
        
        // Verify we stopped making calls after circuit opened
        XCTAssertEqual(callCount, 2, "Should stop calling after failure threshold")
    }
}

// MARK: - Test Helpers

extension PlantAPIServiceTests {
    
    func createMockPlant(id: String = "test", difficulty: Game.Difficulty = .medium) -> Plant {
        return Plant(
            id: id,
            scientificName: "Testus mockus",
            commonNames: ["Mock Plant"],
            family: "Testaceae",
            genus: "Testus",
            species: "mockus",
            imageURL: "https://example.com/mock.jpg",
            thumbnailURL: "https://example.com/mock-thumb.jpg",
            description: "A mock plant for testing",
            difficulty: difficulty.rawValue.hashValue % 100,
            rarity: .common,
            habitat: ["Test habitat"],
            regions: ["Test region"],
            characteristics: Plant.Characteristics(
                leafType: nil,
                flowerColor: [],
                bloomTime: [],
                height: nil,
                sunRequirement: nil,
                waterRequirement: nil,
                soilType: []
            ),
            iNaturalistId: 123456
        )
    }
}

// MARK: - Performance Tests

extension PlantAPIServiceTests {
    
    func testAPIServicePerformance() async throws {
        let mockService = MockPlantAPIService(delay: 0.01) // Very small delay
        
        measure {
            let expectation = XCTestExpectation(description: "API call completion")
            
            Task {
                do {
                    _ = try await mockService.fetchPopularPlants(difficulty: .medium, limit: 10)
                    expectation.fulfill()
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    func testCacheServicePerformance() async throws {
        let mockCacheService = MockPlantCacheService()
        let plants = Array(0..<100).map { createMockPlant(id: "plant_\($0)") }
        
        measure {
            let expectation = XCTestExpectation(description: "Cache operation completion")
            
            Task {
                do {
                    try await mockCacheService.cachePlants(plants)
                    expectation.fulfill()
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 2.0)
        }
    }
}
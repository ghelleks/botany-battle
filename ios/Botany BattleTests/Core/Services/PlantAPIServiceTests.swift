import XCTest
@testable import BotanyBattle

final class PlantAPIServiceTests: XCTestCase {
    
    var sut: PlantAPIService!
    var mockURLSession: MockURLSession!
    
    override func setUp() {
        super.setUp()
        mockURLSession = MockURLSession()
        sut = PlantAPIService(urlSession: mockURLSession)
    }
    
    override func tearDown() {
        sut = nil
        mockURLSession = nil
        super.tearDown()
    }
    
    // MARK: - Fetch Plants Tests
    
    func testFetchPlants_Success_ReturnsPlantData() async throws {
        // Given
        let mockResponse = iNaturalistResponse(
            results: [
                createMockTaxon(id: 1, name: "Quercus robur", commonName: "Oak Tree"),
                createMockTaxon(id: 2, name: "Rosa rubiginosa", commonName: "Rose")
            ]
        )
        let responseData = try JSONEncoder().encode(mockResponse)
        mockURLSession.data = responseData
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "https://api.inaturalist.org")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let plants = await sut.fetchPlants()
        
        // Then
        XCTAssertEqual(plants.count, 2)
        XCTAssertEqual(plants[0].name, "Oak Tree")
        XCTAssertEqual(plants[0].scientificName, "Quercus robur")
        XCTAssertEqual(plants[1].name, "Rose")
        XCTAssertEqual(plants[1].scientificName, "Rosa rubiginosa")
    }
    
    func testFetchPlants_NetworkError_ReturnsEmptyArray() async {
        // Given
        mockURLSession.error = URLError(.notConnectedToInternet)
        
        // When
        let plants = await sut.fetchPlants()
        
        // Then
        XCTAssertTrue(plants.isEmpty)
    }
    
    func testFetchPlants_InvalidJSON_ReturnsEmptyArray() async {
        // Given
        mockURLSession.data = "invalid json".data(using: .utf8)
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "https://api.inaturalist.org")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let plants = await sut.fetchPlants()
        
        // Then
        XCTAssertTrue(plants.isEmpty)
    }
    
    func testFetchPlants_HTTP500Error_ReturnsEmptyArray() async {
        // Given
        mockURLSession.data = Data()
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "https://api.inaturalist.org")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let plants = await sut.fetchPlants()
        
        // Then
        XCTAssertTrue(plants.isEmpty)
    }
    
    // MARK: - Generate Plant Fact Tests
    
    func testGenerateInterestingFact_WithKnownPlant_ReturnsSpecificFact() {
        // Given
        let plantName = "Oak Tree"
        let scientificName = "Quercus robur"
        
        // When
        let fact = sut.generateInterestingFact(for: plantName, scientificName: scientificName)
        
        // Then
        XCTAssertFalse(fact.isEmpty)
        XCTAssertTrue(fact.contains("Oak") || fact.contains("live for hundreds"))
    }
    
    func testGenerateInterestingFact_WithUnknownPlant_ReturnsGeneralFact() {
        // Given
        let plantName = "Unknown Plant Species"
        let scientificName = "Unknownus plantus"
        
        // When
        let fact = sut.generateInterestingFact(for: plantName, scientificName: scientificName)
        
        // Then
        XCTAssertFalse(fact.isEmpty)
        // Should return a general fact since this isn't a known plant
        XCTAssertTrue(fact.contains("photosynthesize") || 
                     fact.contains("oxygen") || 
                     fact.contains("chlorophyll"))
    }
    
    func testGenerateInterestingFact_WithEmptyName_ReturnsGeneralFact() {
        // Given
        let plantName = ""
        let scientificName = "Test species"
        
        // When
        let fact = sut.generateInterestingFact(for: plantName, scientificName: scientificName)
        
        // Then
        XCTAssertFalse(fact.isEmpty)
    }
    
    // MARK: - Cache Tests
    
    func testFetchPlants_WithCache_ReturnsFromCache() async {
        // Given - First call populates cache
        let mockResponse = iNaturalistResponse(
            results: [createMockTaxon(id: 1, name: "Cached Plant", commonName: "Cache Test")]
        )
        let responseData = try! JSONEncoder().encode(mockResponse)
        mockURLSession.data = responseData
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "https://api.inaturalist.org")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When - First call
        let firstResult = await sut.fetchPlants()
        
        // Simulate network failure
        mockURLSession.error = URLError(.notConnectedToInternet)
        
        // When - Second call should use cache
        let secondResult = await sut.fetchPlantsFromCache()
        
        // Then
        XCTAssertEqual(firstResult.count, 1)
        XCTAssertEqual(secondResult.count, 1)
        XCTAssertEqual(firstResult[0].name, secondResult[0].name)
    }
    
    func testClearCache_RemovesCachedData() async {
        // Given - Populate cache
        let mockResponse = iNaturalistResponse(
            results: [createMockTaxon(id: 1, name: "Test Plant", commonName: "Test")]
        )
        let responseData = try! JSONEncoder().encode(mockResponse)
        mockURLSession.data = responseData
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "https://api.inaturalist.org")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        _ = await sut.fetchPlants()
        
        // When
        sut.clearCache()
        
        // Then
        let cachedPlants = await sut.fetchPlantsFromCache()
        XCTAssertTrue(cachedPlants.isEmpty)
    }
    
    // MARK: - Retry Logic Tests
    
    func testFetchPlants_WithRetries_EventuallySucceeds() async {
        // Given
        mockURLSession.shouldFailFirstTwoAttempts = true
        let mockResponse = iNaturalistResponse(
            results: [createMockTaxon(id: 1, name: "Retry Test", commonName: "Retry")]
        )
        let responseData = try! JSONEncoder().encode(mockResponse)
        mockURLSession.eventualSuccessData = responseData
        
        // When
        let plants = await sut.fetchPlants()
        
        // Then
        XCTAssertEqual(plants.count, 1)
        XCTAssertEqual(plants[0].name, "Retry")
    }
    
    // MARK: - Performance Tests
    
    func testFetchPlants_Performance() {
        measure {
            let expectation = XCTestExpectation(description: "Fetch plants")
            
            Task {
                _ = await sut.fetchPlants()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Concurrent Access Tests
    
    func testFetchPlants_ConcurrentCalls_HandlesSafely() async {
        // Given
        let mockResponse = iNaturalistResponse(
            results: [createMockTaxon(id: 1, name: "Concurrent Test", commonName: "Concurrent")]
        )
        let responseData = try! JSONEncoder().encode(mockResponse)
        mockURLSession.data = responseData
        mockURLSession.response = HTTPURLResponse(
            url: URL(string: "https://api.inaturalist.org")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When - Multiple concurrent calls
        async let result1 = sut.fetchPlants()
        async let result2 = sut.fetchPlants()
        async let result3 = sut.fetchPlants()
        
        let results = await [result1, result2, result3]
        
        // Then
        for result in results {
            XCTAssertEqual(result.count, 1)
            XCTAssertEqual(result[0].name, "Concurrent Test")
        }
    }
}

// MARK: - Mock Objects

class MockURLSession: URLSessionProtocol {
    var data: Data?
    var response: URLResponse?
    var error: Error?
    var shouldFailFirstTwoAttempts = false
    var attemptCount = 0
    var eventualSuccessData: Data?
    
    func data(from url: URL) async throws -> (Data, URLResponse) {
        if shouldFailFirstTwoAttempts {
            attemptCount += 1
            if attemptCount <= 2 {
                throw URLError(.networkConnectionLost)
            } else if let successData = eventualSuccessData {
                return (successData, HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!)
            }
        }
        
        if let error = error {
            throw error
        }
        
        return (data ?? Data(), response ?? URLResponse())
    }
}

// MARK: - Helper Functions

private func createMockTaxon(id: Int, name: String, commonName: String) -> Taxon {
    return Taxon(
        id: id,
        name: name,
        preferredCommonName: commonName,
        observationsCount: 1000,
        defaultPhoto: Photo(
            id: id,
            mediumURL: "https://example.com/\(id).jpg",
            originalURL: "https://example.com/\(id)_original.jpg",
            squareURL: "https://example.com/\(id)_square.jpg",
            attribution: "Test attribution"
        ),
        rank: "species",
        iconicTaxonName: "Plantae"
    )
}
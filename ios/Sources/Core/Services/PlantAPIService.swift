import Foundation
import Dependencies

// MARK: - Plant API Service Protocol

protocol PlantAPIServiceProtocol {
    func fetchPopularPlants(difficulty: Game.Difficulty, limit: Int) async throws -> [Plant]
    func searchPlants(query: String, limit: Int) async throws -> [Plant]
    func fetchPlantDetails(iNaturalistId: Int) async throws -> Plant?
    func fetchPlantsForFamily(familyName: String, limit: Int) async throws -> [Plant]
    func fetchRandomPlants(limit: Int) async throws -> [Plant]
}

// MARK: - Rate Limiting

final class RateLimiter {
    private let maxRequestsPerSecond: Double
    private let maxRequestsPerDay: Int
    private var lastRequestTime: Date = Date.distantPast
    private var dailyRequestCount: Int = 0
    private var lastResetDate: Date = Date()
    
    init(maxRequestsPerSecond: Double = 1.0, maxRequestsPerDay: Int = 10000) {
        self.maxRequestsPerSecond = maxRequestsPerSecond
        self.maxRequestsPerDay = maxRequestsPerDay
    }
    
    func waitIfNeeded() async throws {
        await resetDailyCountIfNeeded()
        
        // Check daily limit
        if dailyRequestCount >= maxRequestsPerDay {
            throw iNaturalistAPIError.rateLimitExceeded
        }
        
        // Calculate wait time for per-second limit
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        let minInterval = 1.0 / maxRequestsPerSecond
        
        if timeSinceLastRequest < minInterval {
            let waitTime = minInterval - timeSinceLastRequest
            try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        lastRequestTime = Date()
        dailyRequestCount += 1
    }
    
    @MainActor
    private func resetDailyCountIfNeeded() {
        let calendar = Calendar.current
        if !calendar.isDate(lastResetDate, inSameDayAs: Date()) {
            dailyRequestCount = 0
            lastResetDate = Date()
        }
    }
}

// MARK: - Circuit Breaker

final class CircuitBreaker {
    enum State {
        case closed
        case open
        case halfOpen
    }
    
    private let failureThreshold: Int
    private let timeout: TimeInterval
    private var state: State = .closed
    private var failureCount: Int = 0
    private var lastFailureTime: Date?
    
    init(failureThreshold: Int = 5, timeout: TimeInterval = 60) {
        self.failureThreshold = failureThreshold
        self.timeout = timeout
    }
    
    func execute<T>(_ operation: () async throws -> T) async throws -> T {
        switch state {
        case .closed:
            do {
                let result = try await operation()
                reset()
                return result
            } catch {
                recordFailure()
                throw error
            }
            
        case .open:
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) > timeout {
                state = .halfOpen
                return try await execute(operation)
            }
            throw iNaturalistAPIError.apiError("Circuit breaker is open")
            
        case .halfOpen:
            do {
                let result = try await operation()
                reset()
                return result
            } catch {
                state = .open
                lastFailureTime = Date()
                throw error
            }
        }
    }
    
    private func recordFailure() {
        failureCount += 1
        if failureCount >= failureThreshold {
            state = .open
            lastFailureTime = Date()
        }
    }
    
    private func reset() {
        failureCount = 0
        state = .closed
        lastFailureTime = nil
    }
}

// MARK: - Plant API Service Implementation

final class PlantAPIService: PlantAPIServiceProtocol {
    private let session: URLSession
    private let rateLimiter: RateLimiter
    private let circuitBreaker: CircuitBreaker
    private let decoder: JSONDecoder
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.requestCachePolicy = .useProtocolCachePolicy
        
        self.session = URLSession(configuration: config)
        self.rateLimiter = RateLimiter(
            maxRequestsPerSecond: iNaturalistAPIConfig.maxRequestsPerSecond,
            maxRequestsPerDay: iNaturalistAPIConfig.maxRequestsPerDay
        )
        self.circuitBreaker = CircuitBreaker()
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Public API Methods
    
    func fetchPopularPlants(difficulty: Game.Difficulty, limit: Int) async throws -> [Plant] {
        let observationRange = getObservationRangeForDifficulty(difficulty)
        
        var components = URLComponents(string: "\(iNaturalistAPIConfig.baseURL)/taxa")!
        components.queryItems = [
            URLQueryItem(name: "taxon_id", value: "47126"), // Tracheophyta (vascular plants)
            URLQueryItem(name: "rank", value: "species"),
            URLQueryItem(name: "per_page", value: String(min(limit, iNaturalistAPIConfig.maxPerPage))),
            URLQueryItem(name: "order_by", value: "observations_count"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "photos", value: "true"),
            URLQueryItem(name: "min_observations", value: String(observationRange.min)),
            URLQueryItem(name: "max_observations", value: String(observationRange.max))
        ]
        
        return try await performRequest(url: components.url!)
    }
    
    func searchPlants(query: String, limit: Int) async throws -> [Plant] {
        var components = URLComponents(string: "\(iNaturalistAPIConfig.baseURL)/taxa")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "taxon_id", value: "47126"), // Tracheophyta
            URLQueryItem(name: "rank", value: "species"),
            URLQueryItem(name: "per_page", value: String(min(limit, iNaturalistAPIConfig.maxPerPage))),
            URLQueryItem(name: "order_by", value: "observations_count"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "photos", value: "true")
        ]
        
        return try await performRequest(url: components.url!)
    }
    
    func fetchPlantDetails(iNaturalistId: Int) async throws -> Plant? {
        let url = URL(string: "\(iNaturalistAPIConfig.baseURL)/taxa/\(iNaturalistId)")!
        
        return try await circuitBreaker.execute {
            try await rateLimiter.waitIfNeeded()
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw iNaturalistAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw iNaturalistAPIError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            let taxonResponse = try decoder.decode(iNaturalistTaxonResponse.self, from: data)
            return taxonResponse.results.first?.toPlant()
        }
    }
    
    func fetchPlantsForFamily(familyName: String, limit: Int) async throws -> [Plant] {
        var components = URLComponents(string: "\(iNaturalistAPIConfig.baseURL)/taxa")!
        components.queryItems = [
            URLQueryItem(name: "q", value: familyName),
            URLQueryItem(name: "rank", value: "family"),
            URLQueryItem(name: "per_page", value: "1")
        ]
        
        // First, get the family ID
        let familyResponse: iNaturalistTaxonResponse = try await circuitBreaker.execute {
            try await rateLimiter.waitIfNeeded()
            let (data, _) = try await session.data(from: components.url!)
            return try decoder.decode(iNaturalistTaxonResponse.self, from: data)
        }
        
        guard let family = familyResponse.results.first else {
            throw iNaturalistAPIError.invalidTaxonData
        }
        
        // Then fetch species in that family
        components = URLComponents(string: "\(iNaturalistAPIConfig.baseURL)/taxa")!
        components.queryItems = [
            URLQueryItem(name: "taxon_id", value: String(family.id)),
            URLQueryItem(name: "rank", value: "species"),
            URLQueryItem(name: "per_page", value: String(min(limit, iNaturalistAPIConfig.maxPerPage))),
            URLQueryItem(name: "order_by", value: "observations_count"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "photos", value: "true")
        ]
        
        return try await performRequest(url: components.url!)
    }
    
    func fetchRandomPlants(limit: Int) async throws -> [Plant] {
        // Get a larger set and randomize
        let fetchLimit = min(limit * 3, iNaturalistAPIConfig.maxPerPage)
        let plants = try await fetchPopularPlants(difficulty: .medium, limit: fetchLimit)
        return Array(plants.shuffled().prefix(limit))
    }
    
    // MARK: - Private Helper Methods
    
    private func performRequest(url: URL) async throws -> [Plant] {
        return try await circuitBreaker.execute {
            try await rateLimiter.waitIfNeeded()
            
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw iNaturalistAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 429 {
                    throw iNaturalistAPIError.rateLimitExceeded
                }
                throw iNaturalistAPIError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            let taxonResponse = try decoder.decode(iNaturalistTaxonResponse.self, from: data)
            
            return taxonResponse.results.compactMap { taxon in
                taxon.toPlant()
            }
        }
    }
    
    private func getObservationRangeForDifficulty(_ difficulty: Game.Difficulty) -> (min: Int, max: Int) {
        switch difficulty {
        case .easy:
            return (min: 10000, max: 1000000) // Very common plants
        case .medium:
            return (min: 1000, max: 50000)   // Moderately common
        case .hard:
            return (min: 100, max: 5000)     // Less common
        case .expert:
            return (min: 10, max: 1000)      // Rare plants
        }
    }
}

// MARK: - Mock Implementation

final class MockPlantAPIService: PlantAPIServiceProtocol {
    private let shouldFail: Bool
    private let delay: TimeInterval
    
    init(shouldFail: Bool = false, delay: TimeInterval = 0.5) {
        self.shouldFail = shouldFail
        self.delay = delay
    }
    
    func fetchPopularPlants(difficulty: Game.Difficulty, limit: Int) async throws -> [Plant] {
        try await simulateNetworkDelay()
        
        if shouldFail {
            throw iNaturalistAPIError.networkError(NSError(domain: "MockError", code: 0))
        }
        
        return generateMockPlants(count: limit, difficulty: difficulty)
    }
    
    func searchPlants(query: String, limit: Int) async throws -> [Plant] {
        try await simulateNetworkDelay()
        
        if shouldFail {
            throw iNaturalistAPIError.networkError(NSError(domain: "MockError", code: 0))
        }
        
        return generateMockPlants(count: limit, difficulty: .medium)
            .filter { plant in
                plant.commonNames.first?.localizedCaseInsensitiveContains(query) == true ||
                plant.scientificName.localizedCaseInsensitiveContains(query)
            }
    }
    
    func fetchPlantDetails(iNaturalistId: Int) async throws -> Plant? {
        try await simulateNetworkDelay()
        
        if shouldFail {
            throw iNaturalistAPIError.networkError(NSError(domain: "MockError", code: 0))
        }
        
        return generateMockPlants(count: 1, difficulty: .medium).first
    }
    
    func fetchPlantsForFamily(familyName: String, limit: Int) async throws -> [Plant] {
        try await simulateNetworkDelay()
        
        if shouldFail {
            throw iNaturalistAPIError.networkError(NSError(domain: "MockError", code: 0))
        }
        
        return generateMockPlants(count: limit, difficulty: .medium)
            .map { plant in
                var modifiedPlant = plant
                // Update family to match the requested family
                return Plant(
                    id: plant.id,
                    scientificName: plant.scientificName,
                    commonNames: plant.commonNames,
                    family: familyName,
                    genus: plant.genus,
                    species: plant.species,
                    imageURL: plant.imageURL,
                    thumbnailURL: plant.thumbnailURL,
                    description: plant.description,
                    difficulty: plant.difficulty,
                    rarity: plant.rarity,
                    habitat: plant.habitat,
                    regions: plant.regions,
                    characteristics: plant.characteristics,
                    iNaturalistId: plant.iNaturalistId
                )
            }
    }
    
    func fetchRandomPlants(limit: Int) async throws -> [Plant] {
        try await simulateNetworkDelay()
        
        if shouldFail {
            throw iNaturalistAPIError.networkError(NSError(domain: "MockError", code: 0))
        }
        
        return generateMockPlants(count: limit, difficulty: .medium).shuffled()
    }
    
    private func simulateNetworkDelay() async throws {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
    
    private func generateMockPlants(count: Int, difficulty: Game.Difficulty) -> [Plant] {
        let mockData = [
            ("Rosa rubiginosa", "Sweet Briar", "Rosaceae"),
            ("Quercus robur", "English Oak", "Fagaceae"),
            ("Digitalis purpurea", "Foxglove", "Plantaginaceae"),
            ("Orchis mascula", "Early Purple Orchid", "Orchidaceae"),
            ("Acer platanoides", "Norway Maple", "Sapindaceae"),
            ("Taraxacum officinale", "Common Dandelion", "Asteraceae"),
            ("Lavandula angustifolia", "English Lavender", "Lamiaceae"),
            ("Helianthus annuus", "Common Sunflower", "Asteraceae")
        ]
        
        return (0..<count).map { index in
            let data = mockData[index % mockData.count]
            let genus = data.0.components(separatedBy: " ").first ?? "Unknown"
            let species = data.0.components(separatedBy: " ").last ?? "sp."
            
            return Plant(
                id: "mock_\(index)",
                scientificName: data.0,
                commonNames: [data.1],
                family: data.2,
                genus: genus,
                species: species,
                imageURL: "https://picsum.photos/400/300?random=\(index)",
                thumbnailURL: "https://picsum.photos/100/100?random=\(index)",
                description: "A mock plant for testing: \(data.1)",
                difficulty: difficulty.rawValue.hashValue % 100,
                rarity: .common,
                habitat: ["Mock habitat"],
                regions: ["Mock region"],
                characteristics: Plant.Characteristics(
                    leafType: "Mock leaf",
                    flowerColor: ["Green"],
                    bloomTime: ["Spring"],
                    height: nil,
                    sunRequirement: "Full sun",
                    waterRequirement: "Moderate",
                    soilType: ["Well-drained"]
                ),
                iNaturalistId: 123456 + index
            )
        }
    }
}

// MARK: - Dependency Registration

extension DependencyValues {
    var plantAPIService: PlantAPIServiceProtocol {
        get { self[PlantAPIServiceKey.self] }
        set { self[PlantAPIServiceKey.self] = newValue }
    }
}

private enum PlantAPIServiceKey: DependencyKey {
    static let liveValue: PlantAPIServiceProtocol = PlantAPIService()
    static let testValue: PlantAPIServiceProtocol = MockPlantAPIService()
}
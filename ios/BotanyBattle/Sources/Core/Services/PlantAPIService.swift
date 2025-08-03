import Foundation
import Combine

protocol URLSessionProtocol {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

@MainActor
class PlantAPIService: ObservableObject {
    private let urlSession: URLSessionProtocol
    private let cache = NSCache<NSString, NSArray>()
    private let decoder = JSONDecoder()
    private var lastFetchDate: Date?
    
    // Offline support
    @Published var isOfflineMode = false
    @Published var lastSyncDate: Date?
    
    private let coreDataService = CoreDataService.shared
    private let networkService = NetworkConnectivityService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init(urlSession: URLSessionProtocol = URLSession.shared) {
        self.urlSession = urlSession
        setupCache()
        setupOfflineSupport()
    }
    
    private func setupCache() {
        cache.countLimit = 10
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    private func setupOfflineSupport() {
        // Monitor network connectivity
        networkService.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isOfflineMode = !isConnected
                if isConnected {
                    self?.syncWhenOnline()
                }
            }
            .store(in: &cancellables)
        
        // Listen for offline mode notifications
        NotificationCenter.default.publisher(for: .offlineModeActivated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleOfflineModeActivated()
            }
            .store(in: &cancellables)
    }
    
    private func syncWhenOnline() {
        guard !isOfflineMode else { return }
        
        Task {
            do {
                let freshPlants = try await fetchPlantsFromAPI()
                if !freshPlants.isEmpty {
                    try await coreDataService.cachePlantData(freshPlants)
                    lastSyncDate = Date()
                    print("✅ Plant data synced successfully")
                }
            } catch {
                print("❌ Failed to sync plant data: \(error)")
            }
        }
    }
    
    private func handleOfflineModeActivated() {
        print("📴 Plant API Service switched to offline mode")
    }
    
    // MARK: - Public API
    
    func fetchPlants(limit: Int = 50) async throws -> [PlantData] {
        // If offline, return cached data immediately
        if isOfflineMode {
            return try await fetchCachedPlants()
        }
        
        // Check memory cache first
        if let cachedPlants = getCachedPlants(), !shouldRefreshCache() {
            return Array(cachedPlants.prefix(limit))
        }
        
        // Try to fetch from API with retry logic
        for attempt in 1...GameConstants.maxAPIRetries {
            do {
                let plants = try await fetchPlantsFromAPI()
                if !plants.isEmpty {
                    cachePlants(plants)
                    lastFetchDate = Date()
                    
                    // Also cache in Core Data for offline use
                    try await coreDataService.cachePlantData(plants)
                    lastSyncDate = Date()
                    
                    return Array(plants.prefix(limit))
                }
            } catch {
                print("❌ Attempt \(attempt) failed: \(error.localizedDescription)")
                if attempt == GameConstants.maxAPIRetries {
                    // Return cached data if available
                    do {
                        let cachedPlants = try await fetchCachedPlants()
                        return Array(cachedPlants.prefix(limit))
                    } catch {
                        return getCachedPlants() ?? []
                    }
                }
                
                // Exponential backoff
                let delay = Double(attempt) * 0.5
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // Final fallback to any available cached data
        do {
            let cachedPlants = try await fetchCachedPlants()
            return Array(cachedPlants.prefix(limit))
        } catch {
            return getCachedPlants() ?? []
        }
    }
    
    func fetchPlants() async -> [PlantData] {
        do {
            return try await fetchPlants(limit: 50)
        } catch {
            print("❌ Failed to fetch plants: \(error)")
            return []
        }
    }
    
    private func fetchCachedPlants() async throws -> [PlantData] {
        return try await coreDataService.fetchCachedPlants()
    }
    
    func fetchPlantsFromCache() async -> [PlantData] {
        return getCachedPlants() ?? []
    }
    
    func refreshCache() async {
        guard !isOfflineMode else {
            print("📴 Cannot refresh cache in offline mode")
            return
        }
        
        lastFetchDate = nil // Force refresh
        _ = await fetchPlants()
    }
    
    func clearCache() {
        cache.removeAllObjects()
        lastFetchDate = nil
        lastSyncDate = nil
        
        // Also clear Core Data cache
        coreDataService.clearCache()
    }
    
    func getOfflineStatus() -> OfflineStatus {
        return OfflineStatus(
            isOffline: isOfflineMode,
            lastSyncDate: lastSyncDate,
            hasCachedData: !getCachedPlants()?.isEmpty ?? false,
            canPlayOffline: canPlayOffline()
        )
    }
    
    func canPlayOffline() -> Bool {
        Task {
            do {
                let cachedPlants = try await coreDataService.fetchCachedPlants()
                return !cachedPlants.isEmpty
            } catch {
                return false
            }
        }
        
        // Fallback to memory cache
        return !(getCachedPlants()?.isEmpty ?? true)
    }
    
    func prepareForOfflineUse() async throws {
        guard !isOfflineMode else { return }
        
        print("📦 Preparing plant data for offline use...")
        
        // Fetch fresh data and cache it
        let plants = try await fetchPlants(limit: 200) // Cache more for offline
        if !plants.isEmpty {
            try await coreDataService.cachePlantData(plants)
            lastSyncDate = Date()
            print("✅ Cached \(plants.count) plants for offline use")
        }
    }
    
    func generateInterestingFact(for plantName: String, scientificName: String) -> String {
        // Check for specific plant facts first
        if let specificFact = getSpecificFact(for: plantName) {
            return specificFact
        }
        
        // Return general fact
        return getGeneralFact()
    }
    
    // MARK: - Private Implementation
    
    private func fetchPlantsFromAPI() async throws -> [PlantData] {
        guard let url = buildAPIURL() else {
            throw PlantAPIError.invalidURL
        }
        
        let (data, response) = try await urlSession.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw PlantAPIError.invalidResponse
        }
        
        do {
            let apiResponse = try decoder.decode(iNaturalistResponse.self, from: data)
            let plants = apiResponse.results.compactMap { taxon in
                taxon.toPlantData(withDescription: generateInterestingFact(
                    for: taxon.displayName,
                    scientificName: taxon.name
                ))
            }
            
            print("✅ Successfully fetched \(plants.count) plants from iNaturalist API")
            return plants
            
        } catch {
            throw PlantAPIError.decodingFailed
        }
    }
    
    private func buildAPIURL() -> URL? {
        var components = URLComponents(string: "\(GameConstants.iNaturalistBaseURL)/taxa")
        components?.queryItems = [
            URLQueryItem(name: "taxon_id", value: "\(GameConstants.taxonID)"),
            URLQueryItem(name: "rank", value: "species"),
            URLQueryItem(name: "per_page", value: "\(GameConstants.plantsPerPage)"),
            URLQueryItem(name: "order_by", value: "observations_count"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "photos", value: "true"),
            URLQueryItem(name: "min_observations", value: "\(GameConstants.minimumObservations)")
        ]
        return components?.url
    }
    
    // MARK: - Caching
    
    private func getCachedPlants() -> [PlantData]? {
        let cacheKey = "plants_cache" as NSString
        guard let cachedArray = cache.object(forKey: cacheKey) as? [PlantData] else {
            return nil
        }
        return cachedArray
    }
    
    private func cachePlants(_ plants: [PlantData]) {
        let cacheKey = "plants_cache" as NSString
        cache.setObject(plants as NSArray, forKey: cacheKey)
    }
    
    private func shouldRefreshCache() -> Bool {
        guard let lastFetch = lastFetchDate else { return true }
        let cacheExpiration = TimeInterval(GameConstants.cacheExpirationHours * 3600)
        return Date().timeIntervalSince(lastFetch) > cacheExpiration
    }
    
    // MARK: - Plant Facts
    
    private func getSpecificFact(for plantName: String) -> String? {
        let lowerName = plantName.lowercased()
        let specificFacts: [String: String] = [
            "ivy": "Ivy plants are excellent climbers and can attach to surfaces using aerial rootlets.",
            "oak": "Oak trees can live for hundreds of years and support over 500 species of wildlife.",
            "maple": "Maple trees are famous for their brilliant fall colors and sweet sap used to make syrup.",
            "rose": "Roses have been cultivated for over 5,000 years and come in thousands of varieties.",
            "fern": "Ferns are among the oldest plant groups on Earth, reproducing through spores instead of seeds.",
            "moss": "Mosses are non-vascular plants that absorb water and nutrients directly through their leaves.",
            "grass": "Grasses are monocots with parallel leaf veins and can regrow from their base when cut.",
            "pine": "Pine trees are conifers that produce cones and keep their needle-like leaves year-round.",
            "willow": "Willow bark contains salicin, which was used historically as a pain reliever.",
            "mint": "Mint plants contain menthol oils that give them their characteristic cooling sensation.",
            "sage": "Sage has been used for centuries in both culinary and medicinal applications.",
            "lavender": "Lavender is known for its calming fragrance and is often used in aromatherapy.",
            "daisy": "Daisies are composite flowers, meaning what looks like one flower is actually many tiny flowers.",
            "sunflower": "Sunflowers can grow up to 12 feet tall and their heads follow the sun across the sky.",
            "violet": "Violets are edible flowers often used to decorate cakes and salads.",
            "thistle": "Thistles have spiny leaves as protection but produce nectar that attracts butterflies and bees.",
            "clover": "Clover plants fix nitrogen in the soil, making it more fertile for other plants.",
            "dandelion": "Every part of a dandelion is edible, from the flowers to the roots.",
            "mustard": "Mustard plants belong to the same family as broccoli, cabbage, and kale.",
            "plantain": "Plantain leaves have natural antibiotic properties and were called 'nature's bandage' by early settlers.",
            "yarrow": "Yarrow has been used medicinally for thousands of years to help heal wounds and reduce inflammation.",
            "nettle": "Stinging nettles are rich in vitamins and minerals and can be cooked like spinach when young."
        ]
        
        for (keyword, fact) in specificFacts {
            if lowerName.contains(keyword) {
                return fact
            }
        }
        
        return nil
    }
    
    private func getGeneralFact() -> String {
        let generalFacts = [
            "This plant can photosynthesize sunlight into energy through its leaves.",
            "Like all plants, this species produces oxygen as a byproduct of photosynthesis.",
            "This plant species has adapted to survive in various environmental conditions.",
            "The leaves of this plant contain chlorophyll, giving them their green color.",
            "This species can reproduce both sexually through seeds and asexually through vegetative propagation.",
            "Plants like this one play a crucial role in Earth's ecosystem by converting CO2 into oxygen.",
            "This plant has developed unique adaptations to thrive in its natural habitat.",
            "Many plants in this family have been used by humans for food, medicine, or materials.",
            "This species contributes to biodiversity and supports various forms of wildlife.",
            "Plants like this help prevent soil erosion and maintain environmental balance."
        ]
        
        return generalFacts.randomElement() ?? generalFacts[0]
    }
}

// MARK: - Error Types

enum PlantAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingFailed
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL configuration"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingFailed:
            return "Failed to decode plant data"
        case .networkUnavailable:
            return "Network connection unavailable"
        }
    }
}

// MARK: - Offline Status

struct OfflineStatus {
    let isOffline: Bool
    let lastSyncDate: Date?
    let hasCachedData: Bool
    let canPlayOffline: Bool
    
    var statusDescription: String {
        if isOffline {
            return canPlayOffline ? "Offline - cached data available" : "Offline - no cached data"
        } else {
            return "Online"
        }
    }
    
    var lastSyncDescription: String {
        guard let lastSync = lastSyncDate else {
            return "Never synced"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
    }
}
import Foundation

// MARK: - iNaturalist API Response Models

struct iNaturalistTaxonResponse: Codable {
    let results: [iNaturalistTaxon]
    let totalResults: Int
    let page: Int
    let perPage: Int
    
    enum CodingKeys: String, CodingKey {
        case results
        case totalResults = "total_results"
        case page
        case perPage = "per_page"
    }
}

struct iNaturalistTaxon: Codable {
    let id: Int
    let name: String
    let rank: String
    let rankLevel: Int
    let ancestors: [TaxonAncestor]
    let preferredCommonName: String?
    let englishCommonName: String?
    let wikipediaSummary: String?
    let observationsCount: Int
    let photos: [TaxonPhoto]
    let isActive: Bool
    let iconic: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, rank, ancestors, photos
        case rankLevel = "rank_level"
        case preferredCommonName = "preferred_common_name"
        case englishCommonName = "english_common_name"
        case wikipediaSummary = "wikipedia_summary"
        case observationsCount = "observations_count"
        case isActive = "is_active"
        case iconic
    }
}

struct TaxonAncestor: Codable {
    let id: Int
    let name: String
    let rank: String
    let rankLevel: Int
    let preferredCommonName: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, rank
        case rankLevel = "rank_level"
        case preferredCommonName = "preferred_common_name"
    }
}

struct TaxonPhoto: Codable {
    let id: Int
    let url: String?
    let squareUrl: String?
    let smallUrl: String?
    let mediumUrl: String?
    let largeUrl: String?
    let originalUrl: String?
    let attribution: String?
    let license: String?
    let licenseCode: String?
    
    enum CodingKeys: String, CodingKey {
        case id, url, attribution, license
        case squareUrl = "square_url"
        case smallUrl = "small_url"
        case mediumUrl = "medium_url"
        case largeUrl = "large_url"
        case originalUrl = "original_url"
        case licenseCode = "license_code"
    }
}

// MARK: - Search Response Models

struct iNaturalistSearchResponse: Codable {
    let results: [SearchResult]
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case results
        case totalResults = "total_results"
    }
}

struct SearchResult: Codable {
    let id: Int
    let name: String
    let displayName: String?
    let matchedTerm: String?
    let rank: String?
    let rankLevel: Int?
    let preferredCommonName: String?
    let observationsCount: Int?
    let photos: [TaxonPhoto]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, rank, photos
        case displayName = "display_name"
        case matchedTerm = "matched_term"
        case rankLevel = "rank_level"
        case preferredCommonName = "preferred_common_name"
        case observationsCount = "observations_count"
    }
}

// MARK: - Plant Conversion Extensions

extension iNaturalistTaxon {
    
    /// Converts iNaturalist taxon to our Plant model
    func toPlant() -> Plant? {
        // Only convert taxa that are at species level or lower
        guard rankLevel <= 10, !photos.isEmpty else { return nil }
        
        // Extract family and genus from ancestors
        let family = ancestors.first { $0.rank == "family" }?.name ?? "Unknown"
        let genus = ancestors.first { $0.rank == "genus" }?.name ?? name.components(separatedBy: " ").first ?? "Unknown"
        
        // Get species name (last part of binomial name)
        let speciesName = name.components(separatedBy: " ").last ?? "sp."
        
        // Extract common names
        var commonNames: [String] = []
        if let preferred = preferredCommonName {
            commonNames.append(preferred)
        }
        if let english = englishCommonName, english != preferredCommonName {
            commonNames.append(english)
        }
        if commonNames.isEmpty {
            commonNames = [name] // Fallback to scientific name
        }
        
        // Calculate difficulty based on observations count and rank
        let difficulty = calculateDifficulty()
        
        // Calculate rarity based on observations
        let rarity = calculateRarity()
        
        // Get best quality images
        let sortedPhotos = photos.sorted { ($0.mediumUrl != nil ? 1 : 0) > ($1.mediumUrl != nil ? 1 : 0) }
        guard let primaryPhoto = sortedPhotos.first else { return nil }
        
        let imageURL = primaryPhoto.mediumUrl ?? primaryPhoto.smallUrl ?? primaryPhoto.url ?? ""
        let thumbnailURL = primaryPhoto.squareUrl ?? primaryPhoto.smallUrl
        
        // Create description from Wikipedia summary if available
        let description = wikipediaSummary ?? "A species in the \(family) family."
        
        return Plant(
            id: "inaturalist_\(id)",
            scientificName: name,
            commonNames: commonNames,
            family: family,
            genus: genus,
            species: speciesName,
            imageURL: imageURL,
            thumbnailURL: thumbnailURL,
            description: description,
            difficulty: difficulty,
            rarity: rarity,
            habitat: extractHabitat(),
            regions: extractRegions(),
            characteristics: createCharacteristics(),
            iNaturalistId: id
        )
    }
    
    private func calculateDifficulty() -> Int {
        // Base difficulty on observations count and rank level
        let observationScore = min(observationsCount / 1000, 100) // Cap at 100
        let rankScore = max(0, 20 - rankLevel) * 5 // Lower rank level = higher difficulty
        
        // More observations = easier (well-known species)
        // Higher rank level = easier (broader categories)
        let difficulty = max(1, min(100, 100 - observationScore + rankScore))
        
        return difficulty
    }
    
    private func calculateRarity() -> Plant.Rarity {
        switch observationsCount {
        case 0..<100:
            return .legendary
        case 100..<1000:
            return .veryRare
        case 1000..<10000:
            return .rare
        case 10000..<50000:
            return .uncommon
        default:
            return .common
        }
    }
    
    private func extractHabitat() -> [String] {
        // Extract habitat information from description or use default
        var habitats: [String] = []
        
        // Look for common habitat keywords in name or description
        let text = (name + " " + (wikipediaSummary ?? "")).lowercased()
        
        if text.contains("forest") || text.contains("woodland") || text.contains("tree") {
            habitats.append("Forest")
        }
        if text.contains("meadow") || text.contains("grassland") || text.contains("prairie") {
            habitats.append("Grassland")
        }
        if text.contains("wetland") || text.contains("marsh") || text.contains("swamp") {
            habitats.append("Wetland")
        }
        if text.contains("desert") || text.contains("arid") {
            habitats.append("Desert")
        }
        if text.contains("mountain") || text.contains("alpine") {
            habitats.append("Mountain")
        }
        if text.contains("coastal") || text.contains("marine") || text.contains("beach") {
            habitats.append("Coastal")
        }
        
        return habitats.isEmpty ? ["Various"] : habitats
    }
    
    private func extractRegions() -> [String] {
        // For now, return general regions - could be enhanced with actual range data
        return ["Temperate regions"]
    }
    
    private func createCharacteristics() -> Plant.Characteristics {
        // Create basic characteristics - could be enhanced with more detailed data
        return Plant.Characteristics(
            leafType: extractLeafType(),
            flowerColor: extractFlowerColors(),
            bloomTime: extractBloomTime(),
            height: nil, // Would need additional data source
            sunRequirement: nil,
            waterRequirement: nil,
            soilType: []
        )
    }
    
    private func extractLeafType() -> String? {
        let text = (name + " " + (wikipediaSummary ?? "")).lowercased()
        
        if text.contains("needle") || text.contains("conifer") {
            return "Needle"
        } else if text.contains("broad") || text.contains("deciduous") {
            return "Broadleaf"
        } else if text.contains("compound") {
            return "Compound"
        } else if text.contains("simple") {
            return "Simple"
        }
        
        return nil
    }
    
    private func extractFlowerColors() -> [String] {
        let text = (name + " " + (wikipediaSummary ?? "")).lowercased()
        var colors: [String] = []
        
        let colorKeywords = [
            ("white", "White"),
            ("red", "Red"),
            ("blue", "Blue"),
            ("yellow", "Yellow"),
            ("purple", "Purple"),
            ("pink", "Pink"),
            ("orange", "Orange"),
            ("green", "Green")
        ]
        
        for (keyword, color) in colorKeywords {
            if text.contains(keyword) {
                colors.append(color)
            }
        }
        
        return colors.isEmpty ? ["Variable"] : colors
    }
    
    private func extractBloomTime() -> [String] {
        let text = (name + " " + (wikipediaSummary ?? "")).lowercased()
        var seasons: [String] = []
        
        let seasonKeywords = [
            ("spring", "Spring"),
            ("summer", "Summer"),
            ("fall", "Fall"),
            ("autumn", "Fall"),
            ("winter", "Winter")
        ]
        
        for (keyword, season) in seasonKeywords {
            if text.contains(keyword) && !seasons.contains(season) {
                seasons.append(season)
            }
        }
        
        return seasons.isEmpty ? ["Various"] : seasons
    }
}

// MARK: - API Configuration

struct iNaturalistAPIConfig {
    static let baseURL = "https://api.inaturalist.org/v1"
    static let maxRequestsPerSecond = 1.0
    static let maxRequestsPerDay = 10000
    static let defaultPerPage = 50
    static let maxPerPage = 200
    
    // Common parameters for plant searches
    static let plantTaxonIds = [
        211194, // Plantae (Plants)
        47126,  // Tracheophyta (Vascular plants)
        47125   // Spermatophyta (Seed plants)
    ]
    
    // Quality grades for reliable observations
    static let qualityGrades = ["research", "needs_id"]
    
    // Minimum photo requirements
    static let minPhotosRequired = 1
    static let photoSizes = ["square", "small", "medium", "large"]
}

// MARK: - Error Types

enum iNaturalistAPIError: Error, LocalizedError {
    case invalidURL
    case noData
    case invalidResponse
    case rateLimitExceeded
    case networkError(Error)
    case apiError(String)
    case noPhotosAvailable
    case invalidTaxonData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .noData:
            return "No data received from API"
        case .invalidResponse:
            return "Invalid response format"
        case .rateLimitExceeded:
            return "API rate limit exceeded"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .noPhotosAvailable:
            return "No photos available for this species"
        case .invalidTaxonData:
            return "Invalid or incomplete taxon data"
        }
    }
}
import Foundation

// MARK: - iNaturalist API Response Models
struct iNaturalistResponse: Codable {
    let results: [Taxon]
    let totalResults: Int?
    
    enum CodingKeys: String, CodingKey {
        case results
        case totalResults = "total_results"
    }
}

struct Taxon: Codable, Identifiable {
    let id: Int
    let name: String
    let preferredCommonName: String?
    let observationsCount: Int
    let defaultPhoto: Photo?
    let rank: String?
    let iconicTaxonName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case preferredCommonName = "preferred_common_name"
        case observationsCount = "observations_count"
        case defaultPhoto = "default_photo"
        case rank
        case iconicTaxonName = "iconic_taxon_name"
    }
}

struct Photo: Codable, Identifiable {
    let id: Int?
    let mediumURL: String
    let originalURL: String?
    let squareURL: String?
    let attribution: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case mediumURL = "medium_url"
        case originalURL = "original_url"
        case squareURL = "square_url"
        case attribution
    }
}

// MARK: - Convenience Extensions
extension Taxon {
    var displayName: String {
        return preferredCommonName ?? name.components(separatedBy: " ").last ?? name
    }
    
    var hasPhoto: Bool {
        return defaultPhoto != nil
    }
    
    var imageURL: String? {
        return defaultPhoto?.mediumURL
    }
}

extension Photo {
    var bestQualityURL: String {
        return originalURL ?? mediumURL
    }
}

// MARK: - Conversion Extensions
extension Taxon {
    func toPlantData(withDescription description: String? = nil) -> PlantData? {
        guard let imageURL = self.imageURL else { return nil }
        
        let plantDescription = description ?? "An interesting plant species with unique characteristics."
        
        return PlantData(
            name: displayName,
            scientificName: name,
            imageURL: imageURL,
            description: plantDescription
        )
    }
}
import Foundation

struct PlantData: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let name: String
    let scientificName: String
    let imageURL: String
    let description: String
    
    init(name: String, scientificName: String, imageURL: String, description: String) {
        self.id = UUID()
        self.name = name
        self.scientificName = scientificName
        self.imageURL = imageURL
        self.description = description
    }
    
    // Custom init for testing with fixed UUID
    init(id: UUID = UUID(), name: String, scientificName: String, imageURL: String, description: String) {
        self.id = id
        self.name = name
        self.scientificName = scientificName
        self.imageURL = imageURL
        self.description = description
    }
}

// MARK: - Convenience Extensions
extension PlantData {
    var hasValidImageURL: Bool {
        return URL(string: imageURL) != nil
    }
    
    var displayName: String {
        return name.isEmpty ? scientificName : name
    }
    
    static let empty = PlantData(
        name: "",
        scientificName: "",
        imageURL: "",
        description: ""
    )
}
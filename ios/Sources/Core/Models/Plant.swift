import Foundation

struct Plant: Codable, Equatable, Identifiable {
    let id: String
    let scientificName: String
    let commonNames: [String]
    let family: String
    let genus: String
    let species: String
    let imageURL: String
    let thumbnailURL: String?
    let description: String?
    let difficulty: Int
    let rarity: Rarity
    let habitat: [String]
    let regions: [String]
    let characteristics: Characteristics
    let iNaturalistId: Int?
    
    enum Rarity: String, Codable, CaseIterable {
        case common = "common"
        case uncommon = "uncommon"
        case rare = "rare"
        case veryRare = "very_rare"
        case legendary = "legendary"
        
        var displayName: String {
            switch self {
            case .common: return "Common"
            case .uncommon: return "Uncommon"
            case .rare: return "Rare"
            case .veryRare: return "Very Rare"
            case .legendary: return "Legendary"
            }
        }
        
        var color: String {
            switch self {
            case .common: return "#8B8B8B"
            case .uncommon: return "#1EDD88"
            case .rare: return "#0070DD"
            case .veryRare: return "#A335EE"
            case .legendary: return "#FF8000"
            }
        }
    }
    
    struct Characteristics: Codable, Equatable {
        let leafType: String?
        let flowerColor: [String]
        let bloomTime: [String]
        let height: HeightRange?
        let sunRequirement: String?
        let waterRequirement: String?
        let soilType: [String]
        
        struct HeightRange: Codable, Equatable {
            let min: Double
            let max: Double
            let unit: String
        }
    }
    
    var primaryCommonName: String {
        commonNames.first ?? scientificName
    }
    
    var difficultyLevel: Game.Difficulty {
        switch difficulty {
        case 1...25: return .easy
        case 26...50: return .medium
        case 51...75: return .hard
        default: return .expert
        }
    }
}
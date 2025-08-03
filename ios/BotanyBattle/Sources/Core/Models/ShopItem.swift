import Foundation

struct ShopItem: Identifiable, Codable, Equatable, Hashable {
    let id: Int
    let name: String
    let price: Int
    let icon: String
    let owned: Bool
    let category: ShopItemCategory
    let description: String
    let rarity: ShopItemRarity
    
    init(id: Int, name: String, price: Int, icon: String, owned: Bool = false, 
         category: ShopItemCategory = .cosmetic, description: String = "", 
         rarity: ShopItemRarity = .common) {
        self.id = id
        self.name = name
        self.price = price
        self.icon = icon
        self.owned = owned
        self.category = category
        self.description = description
        self.rarity = rarity
    }
}

enum ShopItemCategory: String, Codable, CaseIterable {
    case cosmetic = "cosmetic"
    case background = "background"
    case badge = "badge"
    case title = "title"
    case effect = "effect"
    
    var displayName: String {
        switch self {
        case .cosmetic:
            return "Cosmetics"
        case .background:
            return "Backgrounds"
        case .badge:
            return "Badges"
        case .title:
            return "Titles"
        case .effect:
            return "Effects"
        }
    }
}

enum ShopItemRarity: String, Codable, CaseIterable {
    case common = "common"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    
    var displayName: String {
        switch self {
        case .common:
            return "Common"
        case .rare:
            return "Rare"
        case .epic:
            return "Epic"
        case .legendary:
            return "Legendary"
        }
    }
    
    var color: String {
        switch self {
        case .common:
            return "gray"
        case .rare:
            return "blue"
        case .epic:
            return "purple"
        case .legendary:
            return "orange"
        }
    }
}

// MARK: - Convenience Extensions
extension ShopItem {
    var canAfford: Bool {
        return price >= 0 // Will be checked against user's trophy count in view model
    }
    
    var isAvailable: Bool {
        return !owned
    }
    
    static let mockItems: [ShopItem] = [
        ShopItem(id: 1, name: "Golden Frame", price: 100, icon: "star.fill", 
                category: .cosmetic, description: "Shine bright with this golden frame", 
                rarity: .rare),
        ShopItem(id: 2, name: "Forest Theme", price: 50, icon: "leaf.fill", 
                category: .background, description: "Immerse yourself in nature", 
                rarity: .common),
        ShopItem(id: 3, name: "Plant Expert", price: 200, icon: "brain.head.profile", 
                category: .badge, description: "Show off your botanical knowledge", 
                rarity: .epic),
        ShopItem(id: 4, name: "Speed Demon", price: 150, icon: "bolt.fill", 
                category: .title, description: "For the fastest plant identifiers", 
                rarity: .rare),
        ShopItem(id: 5, name: "Sparkle Effect", price: 300, icon: "sparkles", 
                category: .effect, description: "Add magical sparkles to your victories", 
                rarity: .legendary)
    ]
}
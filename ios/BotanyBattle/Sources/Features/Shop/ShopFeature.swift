import SwiftUI
import Combine

// MARK: - Shop Feature

@MainActor
class ShopFeature: ObservableObject {
    @Published var selectedCategory: ShopItemCategory = .theme
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var purchaseInProgress: Set<UUID> = []
    
    let userDefaultsService: UserDefaultsService
    private var cancellables = Set<AnyCancellable>()
    
    init(userDefaultsService: UserDefaultsService) {
        self.userDefaultsService = userDefaultsService
        setupBindings()
    }
    
    private func setupBindings() {
        // Listen for trophy changes to update affordability
        userDefaultsService.$totalTrophies
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Shop Items
    
    lazy var allItems: [ShopItem] = {
        createShopItems()
    }()
    
    var ownedItems: [ShopItem] {
        allItems.filter { $0.isOwned }
    }
    
    var availableItems: [ShopItem] {
        allItems.filter { !$0.isOwned }
    }
    
    func itemsForCategory(_ category: ShopItemCategory) -> [ShopItem] {
        allItems.filter { $0.category == category }
    }
    
    func filteredItems(category: ShopItemCategory, showOnlyAffordable: Bool = false) -> [ShopItem] {
        let categoryItems = itemsForCategory(category)
        
        if showOnlyAffordable {
            return categoryItems.filter { canAfford($0) }
        }
        
        return categoryItems
    }
    
    // MARK: - Purchase Logic
    
    func canAfford(_ item: ShopItem) -> Bool {
        return userDefaultsService.totalTrophies >= item.price && !item.isOwned
    }
    
    func isItemOwned(_ itemId: UUID) -> Bool {
        return UserDefaults.standard.bool(forKey: "shop_item_\(itemId)")
    }
    
    func markAsOwned(_ itemId: UUID) {
        UserDefaults.standard.set(true, forKey: "shop_item_\(itemId)")
        updateItemOwnership()
    }
    
    func purchaseItem(_ item: ShopItem) async {
        guard !item.isOwned else {
            errorMessage = "You already own this item."
            return
        }
        
        guard canAfford(item) else {
            errorMessage = "You have insufficient trophies to purchase this item."
            return
        }
        
        // Start purchase process
        purchaseInProgress.insert(item.id)
        errorMessage = nil
        
        // Simulate purchase delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Complete purchase
        userDefaultsService.totalTrophies -= item.price
        markAsOwned(item.id)
        purchaseInProgress.remove(item.id)
        
        // Success feedback
        await showPurchaseSuccess(for: item)
    }
    
    private func showPurchaseSuccess(for item: ShopItem) async {
        // In a real app, this might trigger haptic feedback or show a success animation
        print("Successfully purchased \(item.name)!")
    }
    
    func resetPurchases() {
        // For testing/development - reset all purchases
        for item in allItems {
            UserDefaults.standard.removeObject(forKey: "shop_item_\(item.id)")
        }
        updateItemOwnership()
    }
    
    private func updateItemOwnership() {
        // Force UI update by modifying a published property
        let currentCategory = selectedCategory
        selectedCategory = currentCategory
    }
    
    // MARK: - Shop Statistics
    
    var shopStatistics: ShopStatistics {
        let totalItems = allItems.count
        let owned = ownedItems.count
        let available = availableItems.count
        let totalValue = allItems.reduce(0) { $0 + $1.price }
        let ownedValue = ownedItems.reduce(0) { $0 + $1.price }
        
        return ShopStatistics(
            totalItems: totalItems,
            ownedItems: owned,
            availableItems: available,
            totalValue: totalValue,
            ownedValue: ownedValue
        )
    }
    
    // MARK: - Shop Items Creation
    
    private func createShopItems() -> [ShopItem] {
        var items: [ShopItem] = []
        
        // Themes
        items.append(contentsOf: [
            ShopItem(
                id: UUID(),
                name: "Forest Theme",
                description: "Transform your game with lush forest backgrounds and earthy tones",
                price: 150,
                category: .theme,
                icon: "tree.fill",
                isOwned: isItemOwned(UUID()),
                isPurchasing: false
            ),
            ShopItem(
                id: UUID(),
                name: "Desert Theme",
                description: "Experience the beauty of desert landscapes with warm, sandy colors",
                price: 200,
                category: .theme,
                icon: "sun.max.fill",
                isOwned: isItemOwned(UUID()),
                isPurchasing: false
            ),
            ShopItem(
                id: UUID(),
                name: "Ocean Theme",
                description: "Dive into aquatic vibes with deep blues and wave patterns",
                price: 250,
                category: .theme,
                icon: "water.waves",
                isOwned: isItemOwned(UUID()),
                isPurchasing: false
            ),
            ShopItem(
                id: UUID(),
                name: "Mountain Theme",
                description: "Reach new heights with majestic mountain backdrops",
                price: 300,
                category: .theme,
                icon: "mountain.2.fill",
                isOwned: isItemOwned(UUID()),
                isPurchasing: false
            )
        ])
        
        // Avatars
        items.append(contentsOf: [
            ShopItem(
                id: UUID(),
                name: "Rainbow Avatar",
                description: "Show your colorful personality with this vibrant avatar frame",
                price: 100,
                category: .avatar,
                icon: "rainbow",
                isOwned: isItemOwned(UUID()),
                isPurchasing: false
            ),
            ShopItem(
                id: UUID(),
                name: "Golden Frame",
                description: "Display your prestige with an elegant golden border",
                price: 300,
                category: .avatar,
                icon: "star.fill",
                isOwned: isItemOwned(UUID()),
                isPurchasing: false
            ),
            ShopItem(
                id: UUID(),
                name: "Plant Lover",
                description: "Decorated with botanical elements for true plant enthusiasts",
                price: 150,
                category: .avatar,
                icon: "leaf.fill",
                isOwned: isItemOwned(UUID()),
                isPurchasing: false
            ),
            ShopItem(
                id: UUID(),
                name: "Crystal Frame",
                description: "Sparkling crystal border that catches the light beautifully",
                price: 400,
                category: .avatar,
                icon: "diamond.fill",
                isOwned: isItemOwned(UUID()),
                isPurchasing: false
            )
        ])
        
        // Badges
        items.append(contentsOf: [
            ShopItem(
                id: UUID(),
                name: "Expert Badge",
                description: "Show off your botanical expertise with this prestigious badge",
                price: 500,
                category: .badge,
                icon: "crown.fill",
                isOwned: isItemOwned(UUID()),
                isPurchasing: false
            ),
            ShopItem(
                id: UUID(),
                name: "Speed Badge",
                description: "Demonstrate your quick thinking with this lightning-fast badge",
                price: 250,
                category: .badge,
                icon: "bolt.fill",
                isOwned: isItemOwned(UUID()),
                isPurchasing: false
            ),
            ShopItem(
                id: UUID(),
                name: "Streak Badge",
                description: "Celebrate your winning streaks with this fiery badge",
                price: 200,
                category: .badge,
                icon: "flame.fill",
                isOwned: isItemOwned(UUID()),
                isPurchasing: false
            ),
            ShopItem(
                id: UUID(),
                name: "Scholar Badge",
                description: "Perfect for those who love learning about plants",
                price: 300,
                category: .badge,
                icon: "graduationcap.fill",
                isOwned: isItemOwned(UUID()),
                isPurchasing: false
            )
        ])
        
        // Effects
        items.append(contentsOf: [
            ShopItem(
                id: UUID(),
                name: "Victory Dance",
                description: "Celebrate your wins with a special victory animation",
                price: 350,
                category: .effect,
                icon: "figure.dancing",
                isOwned: isItemOwned(UUID()),
                isPurchasing: false
            ),
            ShopItem(
                id: UUID(),
                name: "Sparkle Effect",
                description: "Add magical sparkles to your correct answers",
                price: 200,
                category: .effect,
                icon: "sparkles",
                isOwned: isItemOwned(UUID()),
                isPurchasing: false
            ),
            ShopItem(
                id: UUID(),
                name: "Confetti Burst",
                description: "Celebrate perfect games with colorful confetti explosions",
                price: 400,
                category: .effect,
                icon: "party.popper.fill",
                isOwned: isItemOwned(UUID()),
                isPurchasing: false
            ),
            ShopItem(
                id: UUID(),
                name: "Plant Growth",
                description: "Watch plants grow when you answer correctly",
                price: 300,
                category: .effect,
                icon: "seedling",
                isOwned: isItemOwned(UUID()),
                isPurchasing: false
            )
        ])
        
        // Update ownership status for all items
        return items.map { item in
            ShopItem(
                id: item.id,
                name: item.name,
                description: item.description,
                price: item.price,
                category: item.category,
                icon: item.icon,
                isOwned: isItemOwned(item.id),
                isPurchasing: purchaseInProgress.contains(item.id)
            )
        }
    }
}

// MARK: - Shop Item Model

struct ShopItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let description: String
    let price: Int
    let category: ShopItemCategory
    let icon: String
    let isOwned: Bool
    let isPurchasing: Bool
    
    static func == (lhs: ShopItem, rhs: ShopItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Shop Item Category

enum ShopItemCategory: String, CaseIterable {
    case theme = "theme"
    case avatar = "avatar"
    case badge = "badge"
    case effect = "effect"
    
    var displayName: String {
        switch self {
        case .theme: return "Themes"
        case .avatar: return "Avatars"
        case .badge: return "Badges"
        case .effect: return "Effects"
        }
    }
    
    var icon: String {
        switch self {
        case .theme: return "paintbrush.fill"
        case .avatar: return "person.circle.fill"
        case .badge: return "star.fill"
        case .effect: return "sparkles"
        }
    }
    
    var description: String {
        switch self {
        case .theme: return "Change your game's appearance"
        case .avatar: return "Customize your profile picture"
        case .badge: return "Show off your achievements"
        case .effect: return "Add special animations"
        }
    }
}

// MARK: - Shop Statistics

struct ShopStatistics {
    let totalItems: Int
    let ownedItems: Int
    let availableItems: Int
    let totalValue: Int
    let ownedValue: Int
    
    var completionPercentage: Double {
        guard totalItems > 0 else { return 0.0 }
        return Double(ownedItems) / Double(totalItems)
    }
    
    var formattedCompletionPercentage: String {
        return String(format: "%.1f%%", completionPercentage * 100)
    }
}
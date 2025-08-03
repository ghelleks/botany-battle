import XCTest
import SwiftUI
@testable import BotanyBattle

class ShopComponentsTests: XCTestCase {
    
    // MARK: - ShopItem Tests
    
    func testShopItemCreation() {
        // Given
        let shopItem = ShopItem(
            id: UUID(),
            name: "Forest Theme",
            description: "Transform your game with lush forest backgrounds",
            price: 100,
            category: .theme,
            icon: "tree.fill",
            isOwned: false,
            isPurchasing: false
        )
        
        // Then
        XCTAssertEqual(shopItem.name, "Forest Theme")
        XCTAssertEqual(shopItem.description, "Transform your game with lush forest backgrounds")
        XCTAssertEqual(shopItem.price, 100)
        XCTAssertEqual(shopItem.category, .theme)
        XCTAssertEqual(shopItem.icon, "tree.fill")
        XCTAssertFalse(shopItem.isOwned)
        XCTAssertFalse(shopItem.isPurchasing)
    }
    
    func testShopItemCategories() {
        // Given
        let categories = ShopItemCategory.allCases
        
        // Then
        XCTAssertTrue(categories.contains(.theme))
        XCTAssertTrue(categories.contains(.avatar))
        XCTAssertTrue(categories.contains(.badge))
        XCTAssertTrue(categories.contains(.effect))
        XCTAssertEqual(categories.count, 4)
    }
    
    func testShopItemCategoryProperties() {
        // Given & When & Then
        XCTAssertEqual(ShopItemCategory.theme.displayName, "Themes")
        XCTAssertEqual(ShopItemCategory.avatar.displayName, "Avatars")
        XCTAssertEqual(ShopItemCategory.badge.displayName, "Badges")
        XCTAssertEqual(ShopItemCategory.effect.displayName, "Effects")
        
        XCTAssertEqual(ShopItemCategory.theme.icon, "paintbrush.fill")
        XCTAssertEqual(ShopItemCategory.avatar.icon, "person.circle.fill")
        XCTAssertEqual(ShopItemCategory.badge.icon, "star.fill")
        XCTAssertEqual(ShopItemCategory.effect.icon, "sparkles")
    }
    
    // MARK: - ShopFeature Tests
    
    func testShopFeatureInitialization() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        
        // When
        let shopFeature = ShopFeature(userDefaultsService: mockUserDefaults)
        
        // Then
        XCTAssertNotNil(shopFeature.userDefaultsService)
        XCTAssertEqual(shopFeature.selectedCategory, .theme)
        XCTAssertFalse(shopFeature.isLoading)
        XCTAssertNil(shopFeature.errorMessage)
        XCTAssertTrue(shopFeature.allItems.count > 0)
    }
    
    func testShopItemsGrouping() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        let shopFeature = ShopFeature(userDefaultsService: mockUserDefaults)
        
        // When
        let themeItems = shopFeature.itemsForCategory(.theme)
        let avatarItems = shopFeature.itemsForCategory(.avatar)
        let badgeItems = shopFeature.itemsForCategory(.badge)
        let effectItems = shopFeature.itemsForCategory(.effect)
        
        // Then
        XCTAssertTrue(themeItems.count > 0)
        XCTAssertTrue(avatarItems.count > 0)
        XCTAssertTrue(badgeItems.count > 0)
        XCTAssertTrue(effectItems.count > 0)
        
        // Verify all items in category match
        XCTAssertTrue(themeItems.allSatisfy { $0.category == .theme })
        XCTAssertTrue(avatarItems.allSatisfy { $0.category == .avatar })
        XCTAssertTrue(badgeItems.allSatisfy { $0.category == .badge })
        XCTAssertTrue(effectItems.allSatisfy { $0.category == .effect })
    }
    
    func testCanAffordItem() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        mockUserDefaults.totalTrophies = 500
        let shopFeature = ShopFeature(userDefaultsService: mockUserDefaults)
        
        let affordableItem = ShopItem(
            id: UUID(),
            name: "Cheap Item",
            description: "Test item",
            price: 100,
            category: .theme,
            icon: "star",
            isOwned: false,
            isPurchasing: false
        )
        
        let expensiveItem = ShopItem(
            id: UUID(),
            name: "Expensive Item",
            description: "Test item",
            price: 1000,
            category: .theme,
            icon: "star",
            isOwned: false,
            isPurchasing: false
        )
        
        // When & Then
        XCTAssertTrue(shopFeature.canAfford(affordableItem))
        XCTAssertFalse(shopFeature.canAfford(expensiveItem))
    }
    
    func testPurchaseFlow() async {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        mockUserDefaults.totalTrophies = 500
        let shopFeature = ShopFeature(userDefaultsService: mockUserDefaults)
        
        let itemToPurchase = shopFeature.allItems.first { $0.price <= 500 && !$0.isOwned }!
        let initialTrophies = mockUserDefaults.totalTrophies
        
        // When
        await shopFeature.purchaseItem(itemToPurchase)
        
        // Then
        XCTAssertEqual(mockUserDefaults.totalTrophies, initialTrophies - itemToPurchase.price)
        XCTAssertTrue(shopFeature.isItemOwned(itemToPurchase.id))
    }
    
    func testPurchaseInsufficientFunds() async {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        mockUserDefaults.totalTrophies = 50
        let shopFeature = ShopFeature(userDefaultsService: mockUserDefaults)
        
        let expensiveItem = shopFeature.allItems.first { $0.price > 50 }!
        let initialTrophies = mockUserDefaults.totalTrophies
        
        // When
        await shopFeature.purchaseItem(expensiveItem)
        
        // Then
        XCTAssertEqual(mockUserDefaults.totalTrophies, initialTrophies) // No change
        XCTAssertFalse(shopFeature.isItemOwned(expensiveItem.id))
        XCTAssertNotNil(shopFeature.errorMessage)
        XCTAssertTrue(shopFeature.errorMessage!.contains("insufficient"))
    }
    
    func testPurchaseAlreadyOwned() async {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        mockUserDefaults.totalTrophies = 1000
        let shopFeature = ShopFeature(userDefaultsService: mockUserDefaults)
        
        let item = shopFeature.allItems.first!
        
        // First purchase
        await shopFeature.purchaseItem(item)
        let trophiesAfterFirst = mockUserDefaults.totalTrophies
        
        // When - try to purchase again
        await shopFeature.purchaseItem(item)
        
        // Then
        XCTAssertEqual(mockUserDefaults.totalTrophies, trophiesAfterFirst) // No change
        XCTAssertNotNil(shopFeature.errorMessage)
        XCTAssertTrue(shopFeature.errorMessage!.contains("already own"))
    }
    
    func testFilterItemsByOwnership() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        let shopFeature = ShopFeature(userDefaultsService: mockUserDefaults)
        
        // When
        let ownedItems = shopFeature.ownedItems
        let availableItems = shopFeature.availableItems
        
        // Then
        XCTAssertTrue(ownedItems.allSatisfy { $0.isOwned })
        XCTAssertTrue(availableItems.allSatisfy { !$0.isOwned })
        XCTAssertEqual(ownedItems.count + availableItems.count, shopFeature.allItems.count)
    }
    
    func testShopStatistics() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        let shopFeature = ShopFeature(userDefaultsService: mockUserDefaults)
        
        // When
        let stats = shopFeature.shopStatistics
        
        // Then
        XCTAssertEqual(stats.totalItems, shopFeature.allItems.count)
        XCTAssertEqual(stats.ownedItems, shopFeature.ownedItems.count)
        XCTAssertEqual(stats.availableItems, shopFeature.availableItems.count)
        XCTAssertEqual(stats.totalValue, shopFeature.allItems.reduce(0) { $0 + $1.price })
        XCTAssertEqual(stats.ownedValue, shopFeature.ownedItems.reduce(0) { $0 + $1.price })
    }
    
    // MARK: - ShopItemCard Tests
    
    func testShopItemCardProperties() {
        // Given
        let shopItem = ShopItem(
            id: UUID(),
            name: "Test Item",
            description: "Test description",
            price: 200,
            category: .theme,
            icon: "star.fill",
            isOwned: false,
            isPurchasing: false
        )
        
        let mockUserDefaults = MockUserDefaultsService()
        mockUserDefaults.totalTrophies = 500
        let shopFeature = ShopFeature(userDefaultsService: mockUserDefaults)
        
        // When
        let card = ShopItemCard(
            item: shopItem,
            shopFeature: shopFeature
        )
        
        // Then
        XCTAssertEqual(card.item.name, "Test Item")
        XCTAssertEqual(card.item.price, 200)
        XCTAssertFalse(card.item.isOwned)
    }
    
    // MARK: - ShopCategoryPicker Tests
    
    func testShopCategoryPickerSelection() {
        // Given
        @State var selectedCategory = ShopItemCategory.theme
        
        // When
        let picker = ShopCategoryPicker(selectedCategory: $selectedCategory)
        
        // Then
        XCTAssertEqual(selectedCategory, .theme)
    }
    
    // MARK: - Data Persistence Tests
    
    func testShopDataPersistence() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        let shopFeature = ShopFeature(userDefaultsService: mockUserDefaults)
        
        let itemId = UUID()
        
        // When
        shopFeature.markAsOwned(itemId)
        let isOwned = shopFeature.isItemOwned(itemId)
        
        // Then
        XCTAssertTrue(isOwned)
    }
    
    func testShopDataReset() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        let shopFeature = ShopFeature(userDefaultsService: mockUserDefaults)
        
        let itemId = UUID()
        shopFeature.markAsOwned(itemId)
        
        // When
        shopFeature.resetPurchases()
        
        // Then
        XCTAssertFalse(shopFeature.isItemOwned(itemId))
    }
}

// MARK: - Mock Objects

extension MockUserDefaultsService {
    func addMockPurchases() {
        // Add some mock purchased items
        let mockPurchases = ["theme_forest", "avatar_plant", "badge_expert"]
        for purchase in mockPurchases {
            UserDefaults.standard.set(true, forKey: "shop_item_\(purchase)")
        }
    }
}

// MARK: - Test Data Models

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
}

// MARK: - Performance Tests

extension ShopComponentsTests {
    func testShopItemsLoadPerformance() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        
        // When & Then
        measure {
            let shopFeature = ShopFeature(userDefaultsService: mockUserDefaults)
            _ = shopFeature.allItems
        }
    }
    
    func testShopCategoryFilteringPerformance() {
        // Given
        let mockUserDefaults = MockUserDefaultsService()
        let shopFeature = ShopFeature(userDefaultsService: mockUserDefaults)
        
        // When & Then
        measure {
            for category in ShopItemCategory.allCases {
                _ = shopFeature.itemsForCategory(category)
            }
        }
    }
}
import Foundation
import ComposableArchitecture

@Reducer
struct ShopFeature {
    @ObservableState
    struct State: Equatable {
        var shopItems: [ShopItem] = []
        var inventory: [InventoryItem] = []
        var currency: User.Currency = User.Currency(coins: 0, gems: 0, tokens: 0)
        var isLoading = false
        var error: String?
        var selectedCategory: ShopCategory = .all
        var searchText = ""
        var isPurchasing = false
        var purchaseConfirmation: PurchaseConfirmation?
        
        enum ShopCategory: String, CaseIterable {
            case all = "all"
            case powerUps = "power_ups"
            case cosmetics = "cosmetics"
            case boosters = "boosters"
            case bundles = "bundles"
            
            var displayName: String {
                switch self {
                case .all: return "All"
                case .powerUps: return "Power-ups"
                case .cosmetics: return "Cosmetics"
                case .boosters: return "Boosters"
                case .bundles: return "Bundles"
                }
            }
        }
        
        struct ShopItem: Equatable, Identifiable {
            let id: String
            let name: String
            let description: String
            let category: ShopCategory
            let price: Price
            let imageURL: String?
            let isAvailable: Bool
            let isLimitedTime: Bool
            let expiresAt: Date?
            let effects: [Effect]
            
            struct Price: Equatable {
                let coins: Int?
                let gems: Int?
                let tokens: Int?
                
                var displayPrice: String {
                    if let coins = coins { return "\(coins) coins" }
                    if let gems = gems { return "\(gems) gems" }
                    if let tokens = tokens { return "\(tokens) tokens" }
                    return "Free"
                }
            }
            
            struct Effect: Equatable {
                let type: EffectType
                let value: Double
                let duration: TimeInterval?
                
                enum EffectType: String, Codable {
                    case timeBonus = "time_bonus"
                    case scoreMultiplier = "score_multiplier"
                    case hintsRevealed = "hints_revealed"
                    case extraLife = "extra_life"
                    case coinBonus = "coin_bonus"
                }
            }
        }
        
        struct InventoryItem: Equatable, Identifiable {
            let id: String
            let shopItemId: String
            let name: String
            let quantity: Int
            let purchasedAt: Date
            let isActive: Bool
            let expiresAt: Date?
        }
        
        struct PurchaseConfirmation: Equatable {
            let item: ShopItem
            let canAfford: Bool
            let newBalance: User.Currency
        }
        
        var filteredItems: [ShopItem] {
            var items = shopItems
            
            if selectedCategory != .all {
                items = items.filter { $0.category == selectedCategory }
            }
            
            if !searchText.isEmpty {
                items = items.filter { item in
                    item.name.localizedCaseInsensitiveContains(searchText) ||
                    item.description.localizedCaseInsensitiveContains(searchText)
                }
            }
            
            return items.sorted { lhs, rhs in
                if lhs.isLimitedTime != rhs.isLimitedTime {
                    return lhs.isLimitedTime
                }
                return lhs.name < rhs.name
            }
        }
    }
    
    enum Action {
        case loadShopItems
        case shopItemsLoaded([State.ShopItem])
        case loadInventory
        case inventoryLoaded([State.InventoryItem])
        case updateCurrency(User.Currency)
        case selectCategory(State.ShopCategory)
        case updateSearchText(String)
        case confirmPurchase(State.ShopItem)
        case cancelPurchase
        case completePurchase(String)
        case purchaseCompleted(State.InventoryItem, User.Currency)
        case useItem(String)
        case itemUsed(String)
        case shopError(String)
        case clearError
    }
    
    @Dependency(\.shopService) var shopService
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadShopItems:
                state.isLoading = true
                state.error = nil
                return .run { send in
                    do {
                        let items = try await shopService.getShopItems()
                        await send(.shopItemsLoaded(items))
                    } catch {
                        await send(.shopError(error.localizedDescription))
                    }
                }
                
            case .shopItemsLoaded(let items):
                state.isLoading = false
                state.shopItems = items
                return .none
                
            case .loadInventory:
                return .run { send in
                    do {
                        let inventory = try await shopService.getInventory()
                        await send(.inventoryLoaded(inventory))
                    } catch {
                        await send(.shopError(error.localizedDescription))
                    }
                }
                
            case .inventoryLoaded(let inventory):
                state.inventory = inventory
                return .none
                
            case .updateCurrency(let currency):
                state.currency = currency
                return .none
                
            case .selectCategory(let category):
                state.selectedCategory = category
                return .none
                
            case .updateSearchText(let text):
                state.searchText = text
                return .none
                
            case .confirmPurchase(let item):
                let canAfford: Bool
                let newBalance: User.Currency
                
                if let coins = item.price.coins {
                    canAfford = state.currency.coins >= coins
                    newBalance = User.Currency(
                        coins: state.currency.coins - coins,
                        gems: state.currency.gems,
                        tokens: state.currency.tokens
                    )
                } else if let gems = item.price.gems {
                    canAfford = state.currency.gems >= gems
                    newBalance = User.Currency(
                        coins: state.currency.coins,
                        gems: state.currency.gems - gems,
                        tokens: state.currency.tokens
                    )
                } else if let tokens = item.price.tokens {
                    canAfford = state.currency.tokens >= tokens
                    newBalance = User.Currency(
                        coins: state.currency.coins,
                        gems: state.currency.gems,
                        tokens: state.currency.tokens - tokens
                    )
                } else {
                    canAfford = true
                    newBalance = state.currency
                }
                
                state.purchaseConfirmation = State.PurchaseConfirmation(
                    item: item,
                    canAfford: canAfford,
                    newBalance: newBalance
                )
                return .none
                
            case .cancelPurchase:
                state.purchaseConfirmation = nil
                return .none
                
            case .completePurchase(let itemId):
                state.isPurchasing = true
                state.purchaseConfirmation = nil
                return .run { send in
                    do {
                        let result = try await shopService.purchaseItem(itemId: itemId)
                        await send(.purchaseCompleted(result.item, result.newBalance))
                    } catch {
                        await send(.shopError(error.localizedDescription))
                    }
                }
                
            case .purchaseCompleted(let item, let newBalance):
                state.isPurchasing = false
                state.currency = newBalance
                state.inventory.append(item)
                return .none
                
            case .useItem(let itemId):
                return .run { send in
                    do {
                        try await shopService.useItem(itemId: itemId)
                        await send(.itemUsed(itemId))
                    } catch {
                        await send(.shopError(error.localizedDescription))
                    }
                }
                
            case .itemUsed(let itemId):
                if let index = state.inventory.firstIndex(where: { $0.id == itemId }) {
                    var item = state.inventory[index]
                    if item.quantity > 1 {
                        state.inventory[index] = State.InventoryItem(
                            id: item.id,
                            shopItemId: item.shopItemId,
                            name: item.name,
                            quantity: item.quantity - 1,
                            purchasedAt: item.purchasedAt,
                            isActive: true,
                            expiresAt: item.expiresAt
                        )
                    } else {
                        state.inventory.remove(at: index)
                    }
                }
                return .none
                
            case .shopError(let error):
                state.isLoading = false
                state.isPurchasing = false
                state.error = error
                return .none
                
            case .clearError:
                state.error = nil
                return .none
            }
        }
    }
}
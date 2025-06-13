import Foundation
import Dependencies

protocol ShopServiceProtocol {
    func getShopItems() async throws -> [ShopFeature.State.ShopItem]
    func getInventory() async throws -> [ShopFeature.State.InventoryItem]
    func purchaseItem(itemId: String) async throws -> PurchaseResult
    func useItem(itemId: String) async throws
}

final class ShopService: ShopServiceProtocol {
    @Dependency(\.networkService) var networkService
    
    func getShopItems() async throws -> [ShopFeature.State.ShopItem] {
        let response: ShopItemsResponse = try await networkService.request(
            .shop(.items),
            method: .get,
            parameters: nil,
            headers: nil
        )
        
        return response.items
    }
    
    func getInventory() async throws -> [ShopFeature.State.InventoryItem] {
        let response: InventoryResponse = try await networkService.request(
            .shop(.inventory),
            method: .get,
            parameters: nil,
            headers: nil
        )
        
        return response.items
    }
    
    func purchaseItem(itemId: String) async throws -> PurchaseResult {
        let response: PurchaseResponse = try await networkService.request(
            .shop(.purchase(itemId)),
            method: .post,
            parameters: nil,
            headers: nil
        )
        
        return PurchaseResult(
            item: response.item,
            newBalance: response.newBalance
        )
    }
    
    func useItem(itemId: String) async throws {
        let parameters = ["itemId": itemId]
        
        let _: EmptyResponse = try await networkService.request(
            .shop(.inventory),
            method: .post,
            parameters: parameters,
            headers: nil
        )
    }
}

struct PurchaseResult {
    let item: ShopFeature.State.InventoryItem
    let newBalance: User.Currency
}

struct ShopItemsResponse: Codable {
    let items: [ShopFeature.State.ShopItem]
}

struct InventoryResponse: Codable {
    let items: [ShopFeature.State.InventoryItem]
}

struct PurchaseResponse: Codable {
    let item: ShopFeature.State.InventoryItem
    let newBalance: User.Currency
}

extension DependencyValues {
    var shopService: ShopServiceProtocol {
        get { self[ShopServiceKey.self] }
        set { self[ShopServiceKey.self] = newValue }
    }
}

private enum ShopServiceKey: DependencyKey {
    static let liveValue: ShopServiceProtocol = ShopService()
}
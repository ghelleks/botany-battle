import XCTest
import SwiftUI
@testable import BotanyBattle

final class BasicUnitTests: XCTestCase {
    
    func testBasicSwiftFeatures() {
        // Test basic Swift features work
        let numbers = [1, 2, 3, 4, 5]
        let doubled = numbers.map { $0 * 2 }
        
        XCTAssertEqual(doubled, [2, 4, 6, 8, 10])
        
        let sum = numbers.reduce(0, +)
        XCTAssertEqual(sum, 15)
    }
    
    func testBasicAppComponents() {
        // Test that our main app components can be instantiated
        let contentView = ContentView()
        let simpleView = SimpleContentView()
        
        XCTAssertNotNil(contentView)
        XCTAssertNotNil(simpleView)
    }
    
    func testShopItemModel() {
        // Test ShopItem model
        let item = ShopItem(
            id: 1,
            name: "Test Item",
            price: 100,
            icon: "star.fill",
            owned: false
        )
        
        XCTAssertEqual(item.id, 1)
        XCTAssertEqual(item.name, "Test Item")
        XCTAssertEqual(item.price, 100)
        XCTAssertEqual(item.icon, "star.fill")
        XCTAssertFalse(item.owned)
    }
    
    func testTutorialStepModel() {
        // Test TutorialStep model
        let step = TutorialStep(
            title: "Welcome",
            description: "Welcome to the game",
            icon: "welcome"
        )
        
        XCTAssertEqual(step.title, "Welcome")
        XCTAssertEqual(step.description, "Welcome to the game")
        XCTAssertEqual(step.icon, "welcome")
    }
    
    func testBasicUIComponents() {
        // Test basic UI components
        let gameView = SimpleGameView()
        let profileView = SimpleProfileView()
        let shopView = SimpleShopView()
        
        XCTAssertNotNil(gameView)
        XCTAssertNotNil(profileView)
        XCTAssertNotNil(shopView)
    }
    
    func testDataStructures() {
        // Test basic data structures
        var gameStats = [String: Int]()
        gameStats["wins"] = 5
        gameStats["losses"] = 3
        
        XCTAssertEqual(gameStats["wins"], 5)
        XCTAssertEqual(gameStats["losses"], 3)
        
        let totalGames = (gameStats["wins"] ?? 0) + (gameStats["losses"] ?? 0)
        XCTAssertEqual(totalGames, 8)
    }
}
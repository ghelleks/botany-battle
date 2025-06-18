import XCTest
import SwiftUI
@testable import BotanyBattle

final class BasicUITests: XCTestCase {
    
    func testContentViewCreation() {
        // Test that ContentView can be created
        let contentView = ContentView()
        XCTAssertNotNil(contentView)
    }
    
    func testSimpleContentViewCreation() {
        // Test that SimpleContentView can be created
        let simpleView = SimpleContentView()
        XCTAssertNotNil(simpleView)
    }
    
    func testGameViewCreation() {
        // Test that game views can be created
        let gameView = SimpleGameView()
        let profileView = SimpleProfileView()
        let shopView = SimpleShopView()
        let settingsView = SimpleSettingsView()
        
        XCTAssertNotNil(gameView)
        XCTAssertNotNil(profileView)
        XCTAssertNotNil(shopView)
        XCTAssertNotNil(settingsView)
    }
    
    func testAuthViewCreation() {
        // Test that auth view can be created
        let authView = SimpleAuthView(isAuthenticated: .constant(false))
        XCTAssertNotNil(authView)
    }
    
    func testTutorialViewCreation() {
        // Test that tutorial view can be created
        let tutorialView = SimpleTutorialView(showTutorial: .constant(true))
        XCTAssertNotNil(tutorialView)
    }
    
    func testTabViewCreation() {
        // Test that tab view can be created
        let tabView = SimpleMainTabView(currentTab: .constant(0))
        XCTAssertNotNil(tabView)
    }
    
    func testShopItemCardCreation() {
        // Test that shop item card can be created
        let item = ShopItem(id: 1, name: "Test Item", price: 100, icon: "star.fill", owned: false)
        let card = ShopItemCard(item: item)
        XCTAssertNotNil(card)
    }
    
    func testAchievementRowCreation() {
        // Test that achievement row can be created
        let row = AchievementRow(title: "Test Achievement", description: "Test Description", icon: "trophy.fill")
        XCTAssertNotNil(row)
    }
}
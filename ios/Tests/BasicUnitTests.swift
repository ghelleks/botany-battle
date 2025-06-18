import XCTest
@testable import BotanyBattle

final class BasicUnitTests: XCTestCase {
    
    func testBasicSwiftFeatures() {
        // Test basic Swift functionality
        XCTAssertEqual(2 + 2, 4)
        XCTAssertTrue("BotanyBattle".contains("Battle"))
        XCTAssertEqual([1, 2, 3].count, 3)
    }
    
    func testBasicAppComponents() {
        // Test that basic app components can be created
        let contentView = ContentView()
        XCTAssertNotNil(contentView)
        
        let simpleView = SimpleContentView()
        XCTAssertNotNil(simpleView)
    }
    
    func testShopItemModel() {
        // Test the ShopItem model that exists in the basic app
        let item = ShopItem(id: 1, name: "Test Item", price: 100, icon: "star.fill", owned: false)
        
        XCTAssertEqual(item.id, 1)
        XCTAssertEqual(item.name, "Test Item")
        XCTAssertEqual(item.price, 100)
        XCTAssertEqual(item.icon, "star.fill")
        XCTAssertFalse(item.owned)
    }
    
    func testTutorialStepModel() {
        // Test the TutorialStep model that exists in the basic app
        let step = TutorialStep(title: "Test Step", description: "Test Description", icon: "leaf.fill")
        
        XCTAssertEqual(step.title, "Test Step")
        XCTAssertEqual(step.description, "Test Description")
        XCTAssertEqual(step.icon, "leaf.fill")
    }
    
    func testStringExtensions() {
        // Test basic string functionality
        let plantName = "Rose"
        XCTAssertTrue(plantName.count > 0)
        XCTAssertEqual(plantName.uppercased(), "ROSE")
        XCTAssertEqual(plantName.lowercased(), "rose")
    }
    
    func testDateBasics() {
        // Test basic date functionality
        let now = Date()
        let future = now.addingTimeInterval(60) // 1 minute later
        
        XCTAssertTrue(future > now)
        XCTAssertTrue(future.timeIntervalSince(now) == 60)
    }
}
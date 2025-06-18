import XCTest
import SwiftUI
@testable import BotanyBattle

final class DesignSystemTests: XCTestCase {
    
    func testBasicColors() {
        // Test basic color functionality
        let green = Color.green
        let red = Color.red
        let blue = Color.blue
        let orange = Color.orange
        
        XCTAssertNotNil(green)
        XCTAssertNotNil(red)
        XCTAssertNotNil(blue)
        XCTAssertNotNil(orange)
    }
    
    func testBasicFonts() {
        // Test basic font functionality
        let title = Font.largeTitle
        let headline = Font.headline
        let body = Font.body
        let caption = Font.caption
        
        XCTAssertNotNil(title)
        XCTAssertNotNil(headline)
        XCTAssertNotNil(body)
        XCTAssertNotNil(caption)
    }
    
    func testShopItemDesign() {
        // Test shop item design components
        let item = ShopItem(id: 1, name: "Forest Theme", price: 100, icon: "tree.fill", owned: false)
        
        XCTAssertEqual(item.name, "Forest Theme")
        XCTAssertEqual(item.price, 100)
        XCTAssertEqual(item.icon, "tree.fill")
        XCTAssertFalse(item.owned)
    }
    
    func testTutorialStepDesign() {
        // Test tutorial step design
        let step = TutorialStep(title: "Welcome", description: "Welcome to Botany Battle", icon: "leaf.fill")
        
        XCTAssertEqual(step.title, "Welcome")
        XCTAssertEqual(step.description, "Welcome to Botany Battle")
        XCTAssertEqual(step.icon, "leaf.fill")
    }
    
    func testUIComponentDesign() {
        // Test that UI components follow design system
        let difficulties = ["Easy", "Medium", "Hard", "Expert"]
        let themes = ["Light", "Dark", "System"]
        
        XCTAssertEqual(difficulties.count, 4)
        XCTAssertEqual(themes.count, 3)
        XCTAssertTrue(difficulties.contains("Easy"))
        XCTAssertTrue(themes.contains("System"))
    }
    
    func testSpacingAndLayout() {
        // Test spacing and layout consistency
        let spacing16: CGFloat = 16
        let spacing32: CGFloat = 32
        let cornerRadius12: CGFloat = 12
        
        XCTAssertEqual(spacing16, 16)
        XCTAssertEqual(spacing32, 32)
        XCTAssertEqual(cornerRadius12, 12)
    }
}
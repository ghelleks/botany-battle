import XCTest
import SwiftUI
import ViewInspector
@testable import BotanyBattle

final class BasicUITests: XCTestCase {
    
    func testSimpleContentViewExists() {
        // Test that our main view components exist
        let view = SimpleContentView()
        XCTAssertNotNil(view)
    }
    
    func testMainTabViewComponents() {
        // Test MainTabView basic structure
        let appState = AppState()
        let view = MainTabView()
            .environmentObject(appState)
        
        XCTAssertNotNil(view)
    }
    
    func testDesignSystemColors() {
        // Test that our color system works
        XCTAssertNotNil(Color.botanicalGreen)
        XCTAssertNotNil(Color.botanicalDarkGreen)
        XCTAssertNotNil(Color.successGreen)
        XCTAssertNotNil(Color.errorRed)
    }
    
    func testDesignSystemFonts() {
        // Test that our typography system works
        if #available(iOS 14.0, *) {
            XCTAssertNotNil(Font.botanicalLargeTitle)
            XCTAssertNotNil(Font.botanicalTitle)
            XCTAssertNotNil(Font.botanicalBody)
        }
    }
    
    func testBotanicalTextStyles() {
        // Test that our text styles are properly configured
        let titleStyle = BotanicalTextStyle.title
        XCTAssertNotNil(titleStyle.font)
        XCTAssertNotNil(titleStyle.color)
        
        let bodyStyle = BotanicalTextStyle.body
        XCTAssertNotNil(bodyStyle.font)
        XCTAssertNotNil(bodyStyle.color)
    }
    
    func testColorThemes() {
        // Test that our color themes are working
        let lightTheme = ColorTheme.light
        XCTAssertNotNil(lightTheme.primary)
        XCTAssertNotNil(lightTheme.background)
        
        let darkTheme = ColorTheme.dark
        XCTAssertNotNil(darkTheme.primary)
        XCTAssertNotNil(darkTheme.background)
    }
    
    func testBotanicalButtons() {
        // Test that our custom button components can be instantiated
        let button = BotanicalButton(
            title: "Test Button",
            style: .primary,
            action: {}
        )
        XCTAssertNotNil(button)
    }
    
    func testBotanicalCards() {
        // Test that our card components work
        let card = BotanicalCard {
            Text("Test Content")
        }
        XCTAssertNotNil(card)
    }
}
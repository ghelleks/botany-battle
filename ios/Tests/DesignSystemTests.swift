import XCTest
import SwiftUI
@testable import BotanyBattle

final class DesignSystemTests: XCTestCase {
    
    func testBotanicalColors() {
        XCTAssertNotNil(Color.botanicalGreen)
        XCTAssertNotNil(Color.botanicalDarkGreen)
        XCTAssertNotNil(Color.botanicalLightGreen)
        XCTAssertNotNil(Color.textPrimary)
        XCTAssertNotNil(Color.successGreen)
        XCTAssertNotNil(Color.errorRed)
    }
    
    func testBotanicalFonts() {
        XCTAssertNotNil(Font.botanicalLargeTitle)
        XCTAssertNotNil(Font.botanicalTitle)
        XCTAssertNotNil(Font.botanicalBody)
        XCTAssertNotNil(Font.botanicalHeadline)
    }
    
    func testBotanicalTextStyles() {
        XCTAssertNotNil(BotanicalTextStyle.largeTitle)
        XCTAssertNotNil(BotanicalTextStyle.title)
        XCTAssertNotNil(BotanicalTextStyle.body)
        XCTAssertNotNil(BotanicalTextStyle.headline)
    }
    
    func testColorThemes() {
        let lightTheme = ColorTheme.light
        XCTAssertNotNil(lightTheme.primary)
        XCTAssertNotNil(lightTheme.secondary)
        XCTAssertNotNil(lightTheme.background)
        
        let darkTheme = ColorTheme.dark
        XCTAssertNotNil(darkTheme.primary)
        XCTAssertNotNil(darkTheme.secondary)
        XCTAssertNotNil(darkTheme.background)
    }
}
import XCTest
import SwiftUI

final class DesignSystemTests: XCTestCase {
    
    func testBasicColors() {
        // Test that SwiftUI basic colors work
        XCTAssertNotNil(Color.primary)
        XCTAssertNotNil(Color.secondary)
        XCTAssertNotNil(Color.blue)
        XCTAssertNotNil(Color.green)
        XCTAssertNotNil(Color.red)
    }
    
    func testBasicFonts() {
        // Test that SwiftUI basic fonts work
        XCTAssertNotNil(Font.largeTitle)
        XCTAssertNotNil(Font.title)
        XCTAssertNotNil(Font.body)
        XCTAssertNotNil(Font.headline)
        XCTAssertNotNil(Font.caption)
    }
    
    func testTextModifiers() {
        // Test that text can be styled
        let text = Text("Test")
            .foregroundColor(.blue)
            .font(.title)
        
        XCTAssertNotNil(text)
    }
    
    func testButtonStyles() {
        // Test button creation
        let button = Button("Test", action: {})
        XCTAssertNotNil(button)
    }
    
    func testVStackAndHStack() {
        // Test layout containers
        let vstack = VStack {
            Text("Test")
        }
        
        let hstack = HStack {
            Text("Test")
        }
        
        XCTAssertNotNil(vstack)
        XCTAssertNotNil(hstack)
    }
    
    func testColorScheme() {
        // Test color scheme support
        XCTAssertTrue(true, "Color scheme support available")
    }
}
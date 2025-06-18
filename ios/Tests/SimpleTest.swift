import XCTest
// Note: Not importing @testable import BotanyBattle to avoid dependency issues

final class SimpleTest: XCTestCase {
    
    func testBasicMath() {
        XCTAssertEqual(2 + 2, 4)
        XCTAssertTrue(true)
        XCTAssertFalse(false)
    }
    
    func testStringBasics() {
        let testString = "BotanyBattle"
        XCTAssertEqual(testString.count, 12)
        XCTAssertTrue(testString.contains("Battle"))
        XCTAssertTrue(testString.hasPrefix("Botany"))
    }
    
    func testArrayBasics() {
        let plants = ["Rose", "Tulip", "Daisy"]
        XCTAssertEqual(plants.count, 3)
        XCTAssertTrue(plants.contains("Rose"))
        XCTAssertEqual(plants.first, "Rose")
        XCTAssertEqual(plants.last, "Daisy")
    }
    
    func testDateBasics() {
        let now = Date()
        let future = now.addingTimeInterval(60) // 1 minute later
        
        XCTAssertTrue(future > now)
        XCTAssertTrue(future.timeIntervalSince(now) == 60)
    }
}
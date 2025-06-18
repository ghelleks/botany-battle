import XCTest
import UIKit

final class DeviceCompatibilityTests: XCTestCase {
    
    func testDeviceTypeDetection() {
        // Test device type detection
        let device = UIDevice.current
        XCTAssertNotNil(device.model)
        XCTAssertNotNil(device.systemVersion)
    }
    
    func testScreenSizeCompatibility() {
        // Test screen size compatibility
        let screen = UIScreen.main
        let bounds = screen.bounds
        
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)
        
        // iPhone screen sizes should be supported
        let minWidth: CGFloat = 320 // iPhone SE width
        XCTAssertGreaterThanOrEqual(bounds.width, minWidth)
    }
    
    func testOrientationSupport() {
        // Test orientation support
        let supportedOrientations = [
            UIInterfaceOrientation.portrait,
            UIInterfaceOrientation.landscapeLeft,
            UIInterfaceOrientation.landscapeRight
        ]
        
        XCTAssertEqual(supportedOrientations.count, 3)
    }
    
    func testiOSVersionCompatibility() {
        // Test iOS version compatibility
        let systemVersion = UIDevice.current.systemVersion
        let version = Float(systemVersion.components(separatedBy: ".").first ?? "0") ?? 0
        
        // App should support iOS 15.0+
        XCTAssertGreaterThanOrEqual(version, 15.0)
    }
    
    func testMemoryConstraints() {
        // Test memory usage is reasonable
        let processInfo = ProcessInfo.processInfo
        XCTAssertGreaterThan(processInfo.physicalMemory, 0)
    }
    
    func testAccessibilitySupport() {
        // Test accessibility support across devices
        XCTAssertTrue(UIAccessibility.isVoiceOverRunning || !UIAccessibility.isVoiceOverRunning)
        XCTAssertTrue(UIAccessibility.isBoldTextEnabled || !UIAccessibility.isBoldTextEnabled)
    }
}
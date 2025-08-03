import XCTest
import SwiftUI
@testable import BotanyBattle

final class ErrorHandlingServiceTests: XCTestCase {
    
    var sut: ErrorHandlingService!
    
    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            sut = ErrorHandlingService()
        }
    }
    
    override func tearDown() async throws {
        await MainActor.run {
            sut?.clearErrorHistory()
            sut = nil
        }
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    @MainActor
    func testInit_SetsInitialState() {
        // Then
        XCTAssertNil(sut.currentError)
        XCTAssertTrue(sut.errorHistory.isEmpty)
        XCTAssertFalse(sut.isShowingError)
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor
    func testHandleError_SystemError_CreatesAppError() {
        // Given
        let systemError = URLError(.notConnectedToInternet)
        
        // When
        sut.handleError(systemError, context: .networkRequest)
        
        // Then
        XCTAssertNotNil(sut.currentError)
        XCTAssertTrue(sut.isShowingError)
        XCTAssertEqual(sut.currentError?.category, .network)
        XCTAssertEqual(sut.currentError?.context, .networkRequest)
    }
    
    @MainActor
    func testHandleAppError_ValidError_UpdatesState() {
        // Given
        let appError = AppError(
            code: "test_error",
            category: .game,
            severity: .moderate,
            context: .gamePlay,
            description: "Test error description"
        )
        
        // When
        sut.handleAppError(appError)
        
        // Then
        XCTAssertEqual(sut.currentError?.id, appError.id)
        XCTAssertTrue(sut.isShowingError)
        XCTAssertEqual(sut.errorHistory.count, 1)
        XCTAssertEqual(sut.errorHistory[0].error.code, "test_error")
    }
    
    @MainActor
    func testHandleMultipleErrors_AddsToHistory() {
        // Given
        let error1 = createMockAppError(code: "error_1", category: .network)
        let error2 = createMockAppError(code: "error_2", category: .data)
        let error3 = createMockAppError(code: "error_3", category: .game)
        
        // When
        sut.handleAppError(error1)
        sut.handleAppError(error2)
        sut.handleAppError(error3)
        
        // Then
        XCTAssertEqual(sut.errorHistory.count, 3)
        XCTAssertEqual(sut.currentError?.code, "error_3") // Most recent
    }
    
    @MainActor
    func testErrorHistory_LimitsSize() {
        // Given - Create more errors than the limit (100)
        for i in 0..<110 {
            let error = createMockAppError(code: "error_\(i)", category: .system)
            sut.handleAppError(error)
        }
        
        // Then
        XCTAssertLessThanOrEqual(sut.errorHistory.count, 100)
        // Should keep the most recent errors
        XCTAssertEqual(sut.errorHistory.last?.error.code, "error_109")
    }
    
    // MARK: - Error Resolution Tests
    
    @MainActor
    func testDismissCurrentError_ClearsState() {
        // Given
        let error = createMockAppError(code: "test_error")
        sut.handleAppError(error)
        
        // When
        sut.dismissCurrentError()
        
        // Then
        XCTAssertNil(sut.currentError)
        XCTAssertFalse(sut.isShowingError)
        // History should remain
        XCTAssertEqual(sut.errorHistory.count, 1)
    }
    
    @MainActor
    func testCanRetry_NetworkError_ReturnsTrue() {
        // Given
        let networkError = createMockAppError(category: .network, severity: .moderate)
        
        // When
        let canRetry = sut.canRetry(networkError)
        
        // Then
        XCTAssertTrue(canRetry)
    }
    
    @MainActor
    func testCanRetry_CriticalNetworkError_ReturnsFalse() {
        // Given
        let criticalError = createMockAppError(category: .network, severity: .critical)
        
        // When
        let canRetry = sut.canRetry(criticalError)
        
        // Then
        XCTAssertFalse(canRetry)
    }
    
    @MainActor
    func testCanRetry_AuthError_ReturnsFalse() {
        // Given
        let authError = createMockAppError(category: .authentication, severity: .moderate)
        
        // When
        let canRetry = sut.canRetry(authError)
        
        // Then
        XCTAssertFalse(canRetry)
    }
    
    @MainActor
    func testCanRetry_GameError_ReturnsTrue() {
        // Given
        let gameError = createMockAppError(category: .game, severity: .moderate)
        
        // When
        let canRetry = sut.canRetry(gameError)
        
        // Then
        XCTAssertTrue(canRetry)
    }
    
    // MARK: - Error Analytics Tests
    
    @MainActor
    func testGetErrorSummary_NoErrors_ReturnsZeroValues() {
        // When
        let summary = sut.getErrorSummary()
        
        // Then
        XCTAssertEqual(summary.totalErrors, 0)
        XCTAssertEqual(summary.errorsLast24Hours, 0)
        XCTAssertTrue(summary.errorsByCategory.isEmpty)
        XCTAssertTrue(summary.errorsBySeverity.isEmpty)
        XCTAssertTrue(summary.mostCommonErrors.isEmpty)
        XCTAssertNil(summary.lastErrorDate)
    }
    
    @MainActor
    func testGetErrorSummary_WithErrors_ReturnsCorrectCounts() {
        // Given
        let networkError1 = createMockAppError(category: .network, severity: .moderate)
        let networkError2 = createMockAppError(category: .network, severity: .high)
        let dataError = createMockAppError(category: .data, severity: .low)
        
        sut.handleAppError(networkError1)
        sut.handleAppError(networkError2)
        sut.handleAppError(dataError)
        
        // When
        let summary = sut.getErrorSummary()
        
        // Then
        XCTAssertEqual(summary.totalErrors, 3)
        XCTAssertEqual(summary.errorsLast24Hours, 3) // All recent
        XCTAssertEqual(summary.errorsByCategory[.network], 2)
        XCTAssertEqual(summary.errorsByCategory[.data], 1)
        XCTAssertNotNil(summary.lastErrorDate)
    }
    
    @MainActor
    func testGetErrorSummary_OldErrors_NotCountedInLast24Hours() {
        // Given
        let oldError = createMockAppError(code: "old_error")
        sut.handleAppError(oldError)
        
        // Manually set timestamp to be older than 24 hours
        if let lastEvent = sut.errorHistory.last {
            let oldEvent = ErrorEvent(
                error: lastEvent.error,
                timestamp: Date().addingTimeInterval(-25 * 3600), // 25 hours ago
                deviceInfo: lastEvent.deviceInfo,
                appState: lastEvent.appState
            )
            sut.errorHistory[sut.errorHistory.count - 1] = oldEvent
        }
        
        // When
        let summary = sut.getErrorSummary()
        
        // Then
        XCTAssertEqual(summary.totalErrors, 1)
        XCTAssertEqual(summary.errorsLast24Hours, 0)
    }
    
    @MainActor
    func testClearErrorHistory_RemovesAllHistory() {
        // Given
        let error1 = createMockAppError(code: "error_1")
        let error2 = createMockAppError(code: "error_2")
        sut.handleAppError(error1)
        sut.handleAppError(error2)
        
        // When
        sut.clearErrorHistory()
        
        // Then
        XCTAssertTrue(sut.errorHistory.isEmpty)
        let summary = sut.getErrorSummary()
        XCTAssertEqual(summary.totalErrors, 0)
    }
    
    // MARK: - Error Recovery Tests
    
    func testPerformErrorRecovery_DataError_AttemptsDataRecovery() async {
        // Given
        let dataError = createMockAppError(category: .data, severity: .moderate)
        await MainActor.run {
            sut.handleAppError(dataError)
        }
        
        // When
        await sut.performErrorRecovery()
        
        // Then - Should complete without throwing
        // In a real implementation, this would trigger data recovery actions
    }
    
    func testPerformErrorRecovery_NetworkError_AttemptsNetworkRecovery() async {
        // Given
        let networkError = createMockAppError(category: .network, severity: .moderate)
        await MainActor.run {
            sut.handleAppError(networkError)
        }
        
        // When
        await sut.performErrorRecovery()
        
        // Then - Should complete without throwing
        // In a real implementation, this would trigger network recovery actions
    }
    
    func testPerformErrorRecovery_NoCurrentError_CompletesGracefully() async {
        // Given - No current error
        
        // When
        await sut.performErrorRecovery()
        
        // Then - Should complete without throwing
        // Nothing to recover
    }
    
    // MARK: - Configuration Tests
    
    @MainActor
    func testSetReportingEnabled_UpdatesConfiguration() {
        // When
        sut.setReportingEnabled(false)
        
        // Handle an error to test reporting
        let error = createMockAppError(code: "test_error")
        sut.handleAppError(error)
        
        // Then - Error should still be handled, just not reported
        XCTAssertNotNil(sut.currentError)
        XCTAssertEqual(sut.errorHistory.count, 1)
    }
    
    @MainActor
    func testSetCrashlyticsEnabled_UpdatesConfiguration() {
        // When
        sut.setCrashlyticsEnabled(true)
        
        // Handle an error to test crashlytics
        let error = createMockAppError(code: "test_error")
        sut.handleAppError(error)
        
        // Then - Error should be handled normally
        XCTAssertNotNil(sut.currentError)
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testHandleError_Performance() {
        let error = createMockAppError(code: "performance_test")
        
        measure {
            sut.handleAppError(error)
            sut.dismissCurrentError()
        }
    }
    
    @MainActor
    func testGetErrorSummary_Performance() {
        // Given - Add some errors
        for i in 0..<10 {
            let error = createMockAppError(code: "error_\(i)")
            sut.handleAppError(error)
        }
        
        measure {
            _ = sut.getErrorSummary()
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentErrorHandling_HandlesSafely() async {
        // When - Multiple concurrent error handling
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let error = self.createMockAppError(code: "concurrent_\(i)")
                    await MainActor.run {
                        self.sut.handleAppError(error)
                    }
                }
            }
        }
        
        // Then - Should have handled all errors
        let errorCount = await MainActor.run { sut.errorHistory.count }
        XCTAssertEqual(errorCount, 10)
    }
}

// MARK: - AppError Tests

final class AppErrorTests: XCTestCase {
    
    func testAppError_Initialization() {
        // Given
        let timestamp = Date()
        
        // When
        let error = AppError(
            code: "test_code",
            category: .network,
            severity: .high,
            context: .networkRequest,
            description: "Test description"
        )
        
        // Then
        XCTAssertEqual(error.code, "test_code")
        XCTAssertEqual(error.category, .network)
        XCTAssertEqual(error.severity, .high)
        XCTAssertEqual(error.context, .networkRequest)
        XCTAssertEqual(error.localizedDescription, "Test description")
        XCTAssertNil(error.underlyingError)
        XCTAssertTrue(error.timestamp.timeIntervalSince(timestamp) >= 0)
    }
    
    func testAppError_FromURLError() {
        // Given
        let urlError = URLError(.notConnectedToInternet)
        
        // When
        let appError = AppError.from(urlError, context: .networkRequest)
        
        // Then
        XCTAssertTrue(appError.code.hasPrefix("network_"))
        XCTAssertEqual(appError.category, .network)
        XCTAssertEqual(appError.severity, .moderate)
        XCTAssertEqual(appError.context, .networkRequest)
        XCTAssertNotNil(appError.underlyingError)
    }
    
    func testAppError_FromDecodingError() {
        // Given
        let decodingError = DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: "Invalid data")
        )
        
        // When
        let appError = AppError.from(decodingError, context: .dataStorage)
        
        // Then
        XCTAssertEqual(appError.code, "data_decoding_failed")
        XCTAssertEqual(appError.category, .data)
        XCTAssertEqual(appError.severity, .moderate)
        XCTAssertEqual(appError.context, .dataStorage)
        XCTAssertNotNil(appError.underlyingError)
    }
    
    func testAppError_FromGenericError() {
        // Given
        struct CustomError: Error, LocalizedError {
            var errorDescription: String? { "Custom error message" }
        }
        let customError = CustomError()
        
        // When
        let appError = AppError.from(customError, context: .general)
        
        // Then
        XCTAssertEqual(appError.code, "unknown_error")
        XCTAssertEqual(appError.category, .system)
        XCTAssertEqual(appError.severity, .moderate)
        XCTAssertEqual(appError.context, .general)
        XCTAssertEqual(appError.localizedDescription, "Custom error message")
    }
    
    func testAppError_FromExistingAppError() {
        // Given
        let originalError = AppError(
            code: "original_code",
            category: .authentication,
            severity: .critical,
            context: .authentication,
            description: "Original description"
        )
        
        // When
        let convertedError = AppError.from(originalError, context: .general)
        
        // Then
        XCTAssertEqual(convertedError.id, originalError.id)
        XCTAssertEqual(convertedError.code, originalError.code)
        XCTAssertEqual(convertedError.category, originalError.category)
    }
}

// MARK: - Error Category Tests

final class ErrorCategoryTests: XCTestCase {
    
    func testErrorCategory_Icons() {
        XCTAssertEqual(ErrorCategory.network.icon, "wifi.exclamationmark")
        XCTAssertEqual(ErrorCategory.data.icon, "externaldrive.badge.exclamationmark")
        XCTAssertEqual(ErrorCategory.authentication.icon, "person.badge.exclamationmark")
        XCTAssertEqual(ErrorCategory.game.icon, "gamecontroller.fill")
        XCTAssertEqual(ErrorCategory.system.icon, "exclamationmark.triangle")
        XCTAssertEqual(ErrorCategory.user.icon, "person.crop.circle.badge.exclamationmark")
    }
    
    func testErrorCategory_AllCases() {
        let allCases = ErrorCategory.allCases
        XCTAssertEqual(allCases.count, 6)
        XCTAssertTrue(allCases.contains(.network))
        XCTAssertTrue(allCases.contains(.data))
        XCTAssertTrue(allCases.contains(.authentication))
        XCTAssertTrue(allCases.contains(.game))
        XCTAssertTrue(allCases.contains(.system))
        XCTAssertTrue(allCases.contains(.user))
    }
}

// MARK: - Error Severity Tests

final class ErrorSeverityTests: XCTestCase {
    
    func testErrorSeverity_Colors() {
        XCTAssertEqual(ErrorSeverity.low.color, .blue)
        XCTAssertEqual(ErrorSeverity.moderate.color, .yellow)
        XCTAssertEqual(ErrorSeverity.high.color, .orange)
        XCTAssertEqual(ErrorSeverity.critical.color, .red)
    }
    
    func testErrorSeverity_AllCases() {
        let allCases = ErrorSeverity.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.low))
        XCTAssertTrue(allCases.contains(.moderate))
        XCTAssertTrue(allCases.contains(.high))
        XCTAssertTrue(allCases.contains(.critical))
    }
}

// MARK: - Test Helper Methods

extension ErrorHandlingServiceTests {
    
    private func createMockAppError(
        code: String = "test_error",
        category: ErrorCategory = .general,
        severity: ErrorSeverity = .moderate,
        context: ErrorContext = .general,
        description: String = "Test error description"
    ) -> AppError {
        return AppError(
            code: code,
            category: category,
            severity: severity,
            context: context,
            description: description
        )
    }
}

// MARK: - Mock Device Info for Testing

extension ErrorHandlingServiceTests {
    
    func createMockDeviceInfo() -> DeviceInfo {
        return DeviceInfo(
            model: "iPhone Simulator",
            systemVersion: "17.0",
            appVersion: "1.0.0",
            memoryUsage: 50 * 1024 * 1024, // 50MB
            diskSpace: 10 * 1024 * 1024 * 1024 // 10GB
        )
    }
}
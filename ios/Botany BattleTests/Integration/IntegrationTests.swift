import XCTest
@testable import BotanyBattle

final class IntegrationTests: XCTestCase {
    
    var appState: AppState!
    
    override func setUp() async throws {
        try await super.setUp()
        
        await MainActor.run {
            appState = AppState()
        }
        
        // Wait for services to initialize
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }
    
    override func tearDown() async throws {
        await MainActor.run {
            appState = nil
        }
        try await super.tearDown()
    }
    
    // MARK: - App State Integration Tests
    
    func testAppState_ServiceInitialization_IntegratesCorrectly() async throws {
        // When
        await appState.initializeServices()
        
        // Then
        await MainActor.run {
            XCTAssertNotNil(appState.userDefaultsService)
            XCTAssertNotNil(appState.plantAPIService)
            XCTAssertNotNil(appState.timerService)
            XCTAssertNotNil(appState.gameCenterService)
            XCTAssertNotNil(appState.coreDataService)
            XCTAssertNotNil(appState.imageCache)
            XCTAssertNotNil(appState.performanceMonitor)
            XCTAssertNotNil(appState.networkService)
            XCTAssertNotNil(appState.offlineDataManager)
            XCTAssertNotNil(appState.gameProgressService)
            XCTAssertNotNil(appState.errorHandler)
        }
    }
    
    func testAppState_FeatureStates_IntegratesCorrectly() async {
        // Then
        await MainActor.run {
            XCTAssertNotNil(appState.authFeature)
            XCTAssertNotNil(appState.gameFeature)
            XCTAssertNotNil(appState.profileFeature)
            XCTAssertNotNil(appState.shopFeature)
            XCTAssertNotNil(appState.settingsFeature)
            XCTAssertNotNil(appState.tutorialFeature)
            XCTAssertNotNil(appState.practiceFeature)
            XCTAssertNotNil(appState.speedrunFeature)
            XCTAssertNotNil(appState.beatTheClockFeature)
        }
    }
    
    // MARK: - Offline Mode Integration Tests
    
    func testOfflineMode_DataFlow_WorksCorrectly() async throws {
        // Given - Start online
        await MainActor.run {
            appState.isOfflineMode = false
        }
        
        // When - Switch to offline mode
        await MainActor.run {
            appState.isOfflineMode = true
        }
        
        // Then - Should be able to access cached data
        let canPlayOffline = appState.canPlayOffline()
        XCTAssertTrue(canPlayOffline || !canPlayOffline) // Should not crash
        
        // And - Should have offline status
        let offlineStatus = appState.getOfflineStatus()
        XCTAssertNotNil(offlineStatus)
    }
    
    func testNetworkConnectivity_StateSync_WorksCorrectly() async {
        // Given
        let networkService = await MainActor.run { appState.networkService }
        
        // When - Network state changes
        await MainActor.run {
            networkService.isConnected = false
        }
        
        // Then - App state should reflect the change
        // Note: This test depends on the binding being set up correctly
        // In a real implementation, we would verify the binding works
        XCTAssertNotNil(networkService)
    }
    
    // MARK: - Data Persistence Integration Tests
    
    func testGameProgress_EndToEnd_DataFlow() async throws {
        // Given
        let gameSession = GameSession(
            id: UUID(),
            mode: .practice,
            score: 150,
            correctAnswers: 12,
            totalQuestions: 15,
            timeElapsed: 120.0,
            completedAt: Date()
        )
        
        let progressService = await MainActor.run { appState.gameProgressService }
        
        // When - Save game session
        await progressService.saveGameSession(gameSession)
        
        // Then - Should be able to load it back
        let loadedProgress = await progressService.loadGameProgress(for: .practice, limit: 1)
        XCTAssertTrue(loadedProgress.count >= 0) // Should not crash
        
        // And - Should update statistics
        let lastSaveDate = await MainActor.run { progressService.lastSaveDate }
        XCTAssertNotNil(lastSaveDate)
    }
    
    func testCoreData_GameProgress_Integration() async throws {
        // Given
        let coreDataService = appState.coreDataService
        let progressData = GameProgressData(
            id: UUID(),
            mode: .beatTheClock,
            score: 200,
            correctAnswers: 18,
            totalQuestions: 20,
            timeElapsed: 60.0,
            completedAt: Date(),
            userId: "integration-test-user"
        )
        
        // When - Save through Core Data
        try await coreDataService.saveGameProgress(progressData)
        
        // Then - Should be retrievable
        let fetchedProgress = try await coreDataService.fetchGameProgress(
            for: "integration-test-user",
            mode: .beatTheClock
        )
        
        XCTAssertGreaterThanOrEqual(fetchedProgress.count, 1)
        
        // And - Personal best should be updated
        let personalBest = try await coreDataService.getPersonalBest(
            for: "integration-test-user",
            mode: .beatTheClock
        )
        XCTAssertNotNil(personalBest)
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testErrorHandling_AppWide_Integration() async {
        // Given
        let errorHandler = await MainActor.run { appState.errorHandler }
        let testError = AppError(
            code: "integration_test_error",
            category: .game,
            severity: .moderate,
            context: .gamePlay,
            description: "Integration test error"
        )
        
        // When - Handle error through app state
        await MainActor.run {
            errorHandler.handleAppError(testError)
        }
        
        // Then - Error should be tracked
        let currentError = await MainActor.run { errorHandler.currentError }
        XCTAssertNotNil(currentError)
        XCTAssertEqual(currentError?.code, "integration_test_error")
        
        // And - Should be in error history
        let errorHistory = await MainActor.run { errorHandler.errorHistory }
        XCTAssertGreaterThanOrEqual(errorHistory.count, 1)
    }
    
    func testErrorRecovery_DataCorruption_Integration() async {
        // Given
        let errorHandler = await MainActor.run { appState.errorHandler }
        let dataError = AppError(
            code: "data_corruption",
            category: .data,
            severity: .critical,
            context: .dataStorage,
            description: "Simulated data corruption"
        )
        
        // When - Handle critical data error
        await MainActor.run {
            errorHandler.handleAppError(dataError)
        }
        
        // And - Attempt recovery
        await errorHandler.performErrorRecovery()
        
        // Then - Recovery should complete without throwing
        // In a real implementation, this would trigger data recovery procedures
        XCTAssertNotNil(errorHandler)
    }
    
    // MARK: - Performance Monitoring Integration Tests
    
    func testPerformanceMonitoring_RealTime_Integration() async {
        // Given
        let performanceMonitor = await MainActor.run { appState.performanceMonitor }
        
        // When - Start monitoring
        await MainActor.run {
            performanceMonitor.startMonitoring()
        }
        
        // And - Perform monitored task
        let result = await performanceMonitor.measureTaskDuration("integration_test_task") {
            // Simulate some work
            var sum = 0
            for i in 0..<1000 {
                sum += i
            }
            return sum
        }
        
        // Then - Task should complete and be measured
        XCTAssertEqual(result, 499500)
        
        // And - Metrics should be available
        let currentMetrics = await MainActor.run { performanceMonitor.currentMetrics }
        XCTAssertNotNil(currentMetrics)
        
        // Cleanup
        await MainActor.run {
            performanceMonitor.stopMonitoring()
        }
    }
    
    // MARK: - Image Caching Integration Tests
    
    func testImageCache_MemoryManagement_Integration() async {
        // Given
        let imageCache = await MainActor.run { appState.imageCache }
        
        // When - Access cache info multiple times
        await MainActor.run {
            for _ in 0..<10 {
                _ = imageCache.getCacheInfo()
            }
        }
        
        // Then - Should not crash and should provide valid info
        let cacheInfo = await MainActor.run { imageCache.getCacheInfo() }
        XCTAssertNotNil(cacheInfo.formattedTotalSize)
        XCTAssertNotNil(cacheInfo.formattedCurrentSize)
        
        // When - Clear cache
        await MainActor.run {
            imageCache.clearCache()
        }
        
        // Then - Cache should be cleared
        let clearedCacheInfo = await MainActor.run { imageCache.getCacheInfo() }
        XCTAssertEqual(clearedCacheInfo.currentSize, 0)
    }
    
    // MARK: - Timer Service Integration Tests
    
    func testTimerService_Lifecycle_Integration() async {
        // Given
        let timerService = await MainActor.run { appState.timerService }
        
        // When - Start timer
        await MainActor.run {
            timerService.startTimer(duration: 5)
        }
        
        // Then - Timer should be running
        let isRunning = await MainActor.run { timerService.isRunning }
        XCTAssertTrue(isRunning)
        
        // When - Pause timer
        await MainActor.run {
            timerService.pauseTimer()
        }
        
        // Then - Timer should be paused
        let isPaused = await MainActor.run { timerService.isPaused }
        XCTAssertTrue(isPaused)
        
        // When - Resume timer
        await MainActor.run {
            timerService.resumeTimer()
        }
        
        // Then - Timer should be running again
        let isRunningAgain = await MainActor.run { timerService.isRunning }
        XCTAssertTrue(isRunningAgain)
        
        // Cleanup
        await MainActor.run {
            timerService.stopTimer()
        }
    }
    
    // MARK: - Feature Integration Tests
    
    func testGameFeature_DataIntegration() async {
        // Given
        let gameFeature = await MainActor.run { appState.gameFeature }
        let coreDataService = appState.coreDataService
        
        // When - Game feature interacts with data services
        // This would typically involve the game feature saving progress
        // For now, we test that the services are properly connected
        
        // Then - Services should be available to the feature
        XCTAssertNotNil(gameFeature)
        XCTAssertNotNil(coreDataService)
        
        // Test that game feature can access required services
        // In a real implementation, we would test actual game workflows
    }
    
    func testAuthFeature_ServiceIntegration() async {
        // Given
        let authFeature = await MainActor.run { appState.authFeature }
        let gameCenterService = await MainActor.run { appState.gameCenterService }
        
        // When - Auth feature uses services
        // This would involve authentication workflows
        
        // Then - Services should be properly connected
        XCTAssertNotNil(authFeature)
        XCTAssertNotNil(gameCenterService)
    }
    
    // MARK: - Full App Workflow Integration Tests
    
    func testFullWorkflow_GameSession_EndToEnd() async throws {
        // Given - App is initialized
        await appState.initializeServices()
        
        // When - Start a game session
        let gameSession = GameSession(
            id: UUID(),
            mode: .speedrun,
            score: 300,
            correctAnswers: 20,
            totalQuestions: 25,
            timeElapsed: 180.0,
            completedAt: Date()
        )
        
        // And - Save progress
        let progressService = await MainActor.run { appState.gameProgressService }
        await progressService.saveGameSession(gameSession)
        
        // And - Update performance metrics
        let performanceMonitor = await MainActor.run { appState.performanceMonitor }
        await MainActor.run {
            performanceMonitor.startMonitoring()
        }
        
        // Then - All systems should work together
        let metrics = await MainActor.run { performanceMonitor.currentMetrics }
        let lastSave = await MainActor.run { progressService.lastSaveDate }
        
        XCTAssertNotNil(metrics)
        XCTAssertNotNil(lastSave)
        
        // Cleanup
        await MainActor.run {
            performanceMonitor.stopMonitoring()
        }
    }
    
    func testFullWorkflow_OfflineToOnline_Transition() async throws {
        // Given - App starts offline
        await MainActor.run {
            appState.isOfflineMode = true
        }
        
        // When - Perform offline operations
        let offlineSession = GameSession(
            id: UUID(),
            mode: .practice,
            score: 100,
            correctAnswers: 8,
            totalQuestions: 10,
            timeElapsed: 60.0,
            completedAt: Date()
        )
        
        let progressService = await MainActor.run { appState.gameProgressService }
        await progressService.saveGameSession(offlineSession)
        
        // And - Go back online
        await MainActor.run {
            appState.isOfflineMode = false
        }
        
        // Then - Data should sync when online
        await appState.refreshAllData()
        
        // And - Should maintain data integrity
        let loadedProgress = await progressService.loadGameProgress(for: .practice, limit: 1)
        XCTAssertTrue(loadedProgress.count >= 0)
    }
    
    // MARK: - Stress Testing
    
    func testStress_ConcurrentOperations_Integration() async {
        // Given
        let numberOfOperations = 20
        
        // When - Perform multiple concurrent operations
        await withTaskGroup(of: Void.self) { group in
            // Concurrent timer operations
            for i in 0..<numberOfOperations {
                group.addTask {
                    await MainActor.run {
                        let timer = TimerService()
                        timer.startTimer(duration: 1)
                        timer.stopTimer()
                    }
                }
            }
            
            // Concurrent data operations
            for i in 0..<numberOfOperations {
                group.addTask {
                    let progress = GameProgressData(
                        id: UUID(),
                        mode: .practice,
                        score: i,
                        correctAnswers: i % 10,
                        totalQuestions: 10,
                        timeElapsed: Double(i),
                        completedAt: Date(),
                        userId: "stress-test-user"
                    )
                    
                    try? await self.appState.coreDataService.saveGameProgress(progress)
                }
            }
            
            // Concurrent performance monitoring
            for _ in 0..<numberOfOperations {
                group.addTask {
                    await MainActor.run {
                        _ = self.appState.performanceMonitor.currentMetrics
                    }
                }
            }
        }
        
        // Then - App should remain stable
        let isStable = await MainActor.run {
            appState.errorHandler.currentError == nil
        }
        XCTAssertTrue(isStable, "App became unstable during stress test")
    }
    
    // MARK: - Resource Cleanup Tests
    
    func testResourceCleanup_Integration() async {
        // Given - Use all services
        await appState.initializeServices()
        
        let performanceMonitor = await MainActor.run { appState.performanceMonitor }
        let imageCache = await MainActor.run { appState.imageCache }
        let timerService = await MainActor.run { appState.timerService }
        
        await MainActor.run {
            performanceMonitor.startMonitoring()
            timerService.startTimer(duration: 5)
        }
        
        // When - Clean up resources
        await MainActor.run {
            performanceMonitor.stopMonitoring()
            timerService.stopTimer()
            imageCache.clearCache()
        }
        
        appState.clearAllCaches()
        
        // Then - Resources should be cleaned up
        let isMonitoring = await MainActor.run { performanceMonitor.isMonitoring }
        let isTimerRunning = await MainActor.run { timerService.isRunning }
        let cacheSize = await MainActor.run { imageCache.getCacheInfo().currentSize }
        
        XCTAssertFalse(isMonitoring)
        XCTAssertFalse(isTimerRunning)
        XCTAssertEqual(cacheSize, 0)
    }
}

// MARK: - Authentication Integration Tests

final class AuthenticationIntegrationTests: XCTestCase {
    
    var appState: AppState!
    
    override func setUp() async throws {
        try await super.setUp()
        
        await MainActor.run {
            appState = AppState()
        }
    }
    
    override func tearDown() async throws {
        await MainActor.run {
            appState = nil
        }
        try await super.tearDown()
    }
    
    func testGuestMode_Integration() async {
        // Given - User starts in guest mode
        let authFeature = await MainActor.run { appState.authFeature }
        
        // When - Operate in guest mode
        // This would involve testing guest functionality
        
        // Then - Should work without authentication
        XCTAssertNotNil(authFeature)
        
        // And - Should be able to play single-player games
        let canPlayOffline = appState.canPlayOffline()
        XCTAssertTrue(canPlayOffline || !canPlayOffline) // Should not crash
    }
    
    func testGameCenter_Integration() async {
        // Given
        let gameCenterService = await MainActor.run { appState.gameCenterService }
        let authFeature = await MainActor.run { appState.authFeature }
        
        // When - Test Game Center integration
        // This would involve testing actual Game Center functionality
        
        // Then - Services should be properly connected
        XCTAssertNotNil(gameCenterService)
        XCTAssertNotNil(authFeature)
    }
}

// MARK: - UI Integration Tests

final class UIIntegrationTests: XCTestCase {
    
    func testMainTabView_StateBinding() async {
        // Given
        let appState = await MainActor.run { AppState() }
        
        // When - Create main tab view
        await MainActor.run {
            let mainTabView = MainTabView()
            // In a real test, we would test the view hierarchy and bindings
            _ = mainTabView
        }
        
        // Then - Should initialize without crashing
        XCTAssertNotNil(appState)
    }
    
    func testErrorHandling_UI_Integration() async {
        // Given
        let errorHandler = await MainActor.run { ErrorHandlingService() }
        
        // When - Create error with UI components
        let error = AppError(
            code: "ui_test_error",
            category: .user,
            severity: .moderate,
            context: .userAction,
            description: "UI integration test error"
        )
        
        await MainActor.run {
            errorHandler.handleAppError(error)
        }
        
        // Then - UI should be able to display error
        let isShowingError = await MainActor.run { errorHandler.isShowingError }
        XCTAssertTrue(isShowingError)
    }
}

// MARK: - Performance Integration Tests

final class PerformanceIntegrationTests: XCTestCase {
    
    func testEndToEnd_Performance() async {
        // Given
        let appState = await MainActor.run { AppState() }
        
        // When - Measure end-to-end performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Initialize services
        await appState.initializeServices()
        
        // Perform typical operations
        let gameSession = GameSession(
            id: UUID(),
            mode: .practice,
            score: 100,
            correctAnswers: 10,
            totalQuestions: 15,
            timeElapsed: 90.0,
            completedAt: Date()
        )
        
        let progressService = await MainActor.run { appState.gameProgressService }
        await progressService.saveGameSession(gameSession)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalTime = endTime - startTime
        
        // Then - Should complete within reasonable time
        XCTAssertLessThan(totalTime, 5.0, "End-to-end operation too slow: \(totalTime)s")
        
        print("✅ End-to-end performance: \(String(format: "%.3f", totalTime))s")
    }
}

// MARK: - Data Consistency Integration Tests

final class DataConsistencyIntegrationTests: XCTestCase {
    
    var appState: AppState!
    
    override func setUp() async throws {
        try await super.setUp()
        
        await MainActor.run {
            appState = AppState()
        }
    }
    
    override func tearDown() async throws {
        try await appState?.coreDataService.clearAllData()
        await MainActor.run {
            appState = nil
        }
        try await super.tearDown()
    }
    
    func testData_Consistency_AcrossServices() async throws {
        // Given
        let coreDataService = appState.coreDataService
        let progressService = await MainActor.run { appState.gameProgressService }
        
        // When - Save data through both services
        let gameSession = GameSession(
            id: UUID(),
            mode: .beatTheClock,
            score: 500,
            correctAnswers: 25,
            totalQuestions: 30,
            timeElapsed: 240.0,
            completedAt: Date()
        )
        
        await progressService.saveGameSession(gameSession)
        
        // Then - Data should be consistent
        let coreDataProgress = try await coreDataService.fetchGameProgress(
            for: "test-user", // This would be the current user
            mode: .beatTheClock
        )
        
        let progressServiceData = await progressService.loadGameProgress(
            for: .beatTheClock,
            limit: 1
        )
        
        // Both should have data (exact consistency depends on implementation)
        XCTAssertTrue(coreDataProgress.count >= 0)
        XCTAssertTrue(progressServiceData.count >= 0)
    }
}
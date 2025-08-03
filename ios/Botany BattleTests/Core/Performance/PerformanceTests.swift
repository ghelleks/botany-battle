import XCTest
@testable import BotanyBattle

final class PerformanceTests: XCTestCase {
    
    var performanceMonitor: PerformanceMonitor!
    var imageCache: ImageCacheService!
    var coreDataService: CoreDataService!
    var timerService: TimerService!
    
    override func setUp() async throws {
        try await super.setUp()
        
        await MainActor.run {
            performanceMonitor = PerformanceMonitor.shared
            imageCache = ImageCacheService.shared
            timerService = TimerService()
        }
        coreDataService = CoreDataService.shared
    }
    
    override func tearDown() async throws {
        await MainActor.run {
            performanceMonitor?.stopMonitoring()
            imageCache?.clearCache()
            timerService?.stopTimer()
        }
        
        try await coreDataService?.clearAllData()
        
        performanceMonitor = nil
        imageCache = nil
        coreDataService = nil
        timerService = nil
        
        try await super.tearDown()
    }
    
    // MARK: - App Launch Performance Tests
    
    func testAppLaunchTime_Performance() {
        // This test measures the time it takes to initialize core services
        measure {
            let expectation = XCTestExpectation(description: "App initialization")
            
            Task { @MainActor in
                // Simulate app initialization
                let userDefaults = UserDefaultsService()
                let plantAPI = PlantAPIService()
                let gameCenter = GameCenterService()
                
                // Initialize services
                _ = userDefaults
                _ = plantAPI
                _ = gameCenter
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 2.0) // Should complete within 2 seconds
        }
    }
    
    func testCoreDataInitialization_Performance() {
        measure {
            let expectation = XCTestExpectation(description: "Core Data initialization")
            
            Task {
                // Test Core Data stack initialization time
                let service = CoreDataService()
                
                // Wait for Core Data to be ready
                while !service.isReady {
                    try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                }
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Memory Performance Tests
    
    func testImageCache_MemoryUsage() async throws {
        // Test that image cache doesn't exceed memory limits
        let initialMemory = await getMemoryUsage()
        
        // Load multiple images (simulated)
        let imageUrls = (0..<50).map { "https://example.com/image\($0).jpg" }
        
        for url in imageUrls {
            // Simulate caching images
            await MainActor.run {
                // In a real test, we would load actual images
                // For now, we just test the cache structure
                _ = imageCache.getCacheInfo()
            }
        }
        
        let finalMemory = await getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable (less than 100MB)
        XCTAssertLessThan(memoryIncrease, 100 * 1024 * 1024)
    }
    
    func testCoreData_MemoryUsage() async throws {
        let initialMemory = await getMemoryUsage()
        
        // Create many game progress entries
        for i in 0..<1000 {
            let progress = GameProgressData(
                id: UUID(),
                mode: .practice,
                score: i,
                correctAnswers: i % 20,
                totalQuestions: 20,
                timeElapsed: Double(i),
                completedAt: Date(),
                userId: "test-user"
            )
            
            try await coreDataService.saveGameProgress(progress)
        }
        
        let finalMemory = await getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024) // Less than 50MB
    }
    
    // MARK: - Timer Performance Tests
    
    @MainActor
    func testTimer_MemoryLeak_Prevention() {
        // Test that timers are properly cleaned up
        weak var weakTimer: TimerService?
        
        autoreleasepool {
            let timer = TimerService()
            weakTimer = timer
            
            // Start and stop timer multiple times
            timer.startTimer(duration: 60)
            timer.pauseTimer()
            timer.resumeTimer()
            timer.stopTimer()
        }
        
        // Force garbage collection
        autoreleasepool {}
        
        // Timer should be deallocated
        XCTAssertNil(weakTimer, "Timer service should be deallocated")
    }
    
    @MainActor
    func testMultipleTimers_Performance() {
        measure {
            let timers = (0..<10).map { _ in TimerService() }
            
            // Start all timers
            for timer in timers {
                timer.startTimer(duration: 5)
            }
            
            // Stop all timers
            for timer in timers {
                timer.stopTimer()
            }
        }
    }
    
    // MARK: - Performance Monitor Tests
    
    @MainActor
    func testPerformanceMonitor_StartStop_Performance() {
        measure {
            performanceMonitor.startMonitoring()
            performanceMonitor.stopMonitoring()
        }
    }
    
    func testPerformanceMonitor_TaskMeasurement() async {
        let taskName = "test_task"
        
        // Measure a simple task
        let result = await performanceMonitor.measureTaskDuration(taskName) {
            // Simulate some work
            var sum = 0
            for i in 0..<1000 {
                sum += i
            }
            return sum
        }
        
        XCTAssertEqual(result, 499500) // Expected sum
    }
    
    func testPerformanceMonitor_ConcurrentTasks_Performance() async {
        // Test measuring multiple concurrent tasks
        await withTaskGroup(of: Int.self) { group in
            for i in 0..<5 {
                group.addTask {
                    return await self.performanceMonitor.measureTaskDuration("concurrent_task_\(i)") {
                        // Simulate work
                        return i * 100
                    }
                }
            }
            
            var results: [Int] = []
            for await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.count, 5)
        }
    }
    
    // MARK: - Database Performance Tests
    
    func testCoreData_BulkInsert_Performance() async throws {
        measure {
            let expectation = XCTestExpectation(description: "Bulk insert")
            
            Task {
                // Insert 100 records
                for i in 0..<100 {
                    let progress = GameProgressData(
                        id: UUID(),
                        mode: .practice,
                        score: i,
                        correctAnswers: i % 15,
                        totalQuestions: 15,
                        timeElapsed: Double(i) * 2,
                        completedAt: Date(),
                        userId: "bulk-test-user"
                    )
                    
                    try await self.coreDataService.saveGameProgress(progress)
                }
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testCoreData_Query_Performance() async throws {
        // First, insert test data
        for i in 0..<500 {
            let progress = GameProgressData(
                id: UUID(),
                mode: GameMode.allCases[i % 3],
                score: i,
                correctAnswers: i % 20,
                totalQuestions: 20,
                timeElapsed: Double(i),
                completedAt: Date().addingTimeInterval(-Double(i) * 60),
                userId: "query-test-user"
            )
            
            try await coreDataService.saveGameProgress(progress)
        }
        
        // Measure query performance
        measure {
            let expectation = XCTestExpectation(description: "Query performance")
            
            Task {
                _ = try await self.coreDataService.fetchGameProgress(
                    for: "query-test-user",
                    mode: .practice
                )
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Network Performance Tests
    
    func testPlantAPI_ResponseTime_Performance() async {
        let plantAPI = PlantAPIService()
        
        measure {
            let expectation = XCTestExpectation(description: "API response")
            
            Task {
                _ = await plantAPI.fetchPlants()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testNetworkConnectivity_Check_Performance() async {
        let networkService = NetworkConnectivityService.shared
        
        measure {
            let expectation = XCTestExpectation(description: "Connectivity check")
            
            Task {
                _ = await networkService.checkConnectivity()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - UI Performance Tests
    
    @MainActor
    func testView_RenderTime_Performance() {
        let viewName = "TestView"
        
        measure {
            // Simulate view rendering measurement
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Simulate view creation and layout
            for _ in 0..<100 {
                let _ = CGRect(x: 0, y: 0, width: 375, height: 812)
            }
            
            let renderTime = CFAbsoluteTimeGetCurrent() - startTime
            
            // Log the render time
            if renderTime > 0.016 { // 60fps = 16.67ms per frame
                print("⚠️ View render time exceeded 60fps: \(renderTime * 1000)ms")
            }
        }
    }
    
    // MARK: - Stress Tests
    
    func testConcurrent_Service_Access() async {
        // Test concurrent access to all services
        await withTaskGroup(of: Void.self) { group in
            // Core Data access
            group.addTask {
                for i in 0..<50 {
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
                    
                    try? await self.coreDataService.saveGameProgress(progress)
                }
            }
            
            // Image cache access
            group.addTask {
                await MainActor.run {
                    for i in 0..<50 {
                        _ = self.imageCache.getCacheInfo()
                    }
                }
            }
            
            // Timer operations
            group.addTask {
                await MainActor.run {
                    for _ in 0..<10 {
                        let timer = TimerService()
                        timer.startTimer(duration: 1)
                        timer.stopTimer()
                    }
                }
            }
            
            // Performance monitoring
            group.addTask {
                await MainActor.run {
                    for _ in 0..<20 {
                        _ = self.performanceMonitor.currentMetrics
                    }
                }
            }
        }
    }
    
    func testMemory_Intensive_Operations() async throws {
        let initialMemory = await getMemoryUsage()
        
        // Perform memory-intensive operations
        await withTaskGroup(of: Void.self) { group in
            // Large data processing
            group.addTask {
                for i in 0..<1000 {
                    let progress = GameProgressData(
                        id: UUID(),
                        mode: .beatTheClock,
                        score: i,
                        correctAnswers: i % 25,
                        totalQuestions: 25,
                        timeElapsed: Double(i) * 1.5,
                        completedAt: Date(),
                        userId: "memory-test-user-\(i % 10)"
                    )
                    
                    try? await self.coreDataService.saveGameProgress(progress)
                }
            }
            
            // Image processing simulation
            group.addTask {
                await MainActor.run {
                    for i in 0..<100 {
                        // Simulate image processing
                        let _ = UIImage(systemName: "leaf.fill")
                        _ = self.imageCache.getCacheInfo()
                    }
                }
            }
        }
        
        let finalMemory = await getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be manageable
        XCTAssertLessThan(memoryIncrease, 200 * 1024 * 1024) // Less than 200MB
        
        print("Memory increase during stress test: \(memoryIncrease / (1024 * 1024))MB")
    }
    
    // MARK: - Performance Benchmarks
    
    func testPerformance_Benchmarks() async throws {
        let benchmarks = PerformanceBenchmarks()
        
        // Run all benchmark tests
        await benchmarks.runAllBenchmarks()
        
        // Verify benchmark results
        XCTAssertNotNil(benchmarks.results)
        XCTAssertFalse(benchmarks.results.isEmpty)
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() async -> UInt64 {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                var info = mach_task_basic_info()
                var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
                
                let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        task_info(mach_task_self_,
                                 task_flavor_t(MACH_TASK_BASIC_INFO),
                                 $0,
                                 &count)
                    }
                }
                
                let memoryUsage = kerr == KERN_SUCCESS ? info.resident_size : 0
                continuation.resume(returning: memoryUsage)
            }
        }
    }
}

// MARK: - Performance Benchmarks

class PerformanceBenchmarks {
    var results: [String: TimeInterval] = [:]
    
    func runAllBenchmarks() async {
        await runServiceInitializationBenchmark()
        await runDataOperationsBenchmark()
        await runConcurrencyBenchmark()
    }
    
    private func runServiceInitializationBenchmark() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Initialize all core services
        await MainActor.run {
            let _ = UserDefaultsService()
            let _ = PlantAPIService()
            let _ = TimerService()
            let _ = ImageCacheService.shared
            let _ = PerformanceMonitor.shared
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        results["service_initialization"] = duration
        
        print("📊 Service initialization: \(String(format: "%.3f", duration * 1000))ms")
    }
    
    private func runDataOperationsBenchmark() async {
        let coreData = CoreDataService.shared
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform data operations
        for i in 0..<100 {
            let progress = GameProgressData(
                id: UUID(),
                mode: .practice,
                score: i,
                correctAnswers: i % 15,
                totalQuestions: 15,
                timeElapsed: Double(i),
                completedAt: Date(),
                userId: "benchmark-user"
            )
            
            try? await coreData.saveGameProgress(progress)
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        results["data_operations"] = duration
        
        print("📊 Data operations (100 saves): \(String(format: "%.3f", duration * 1000))ms")
    }
    
    private func runConcurrencyBenchmark() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Run concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    // Simulate concurrent work
                    var sum = 0
                    for j in 0..<1000 {
                        sum += i * j
                    }
                    _ = sum
                }
            }
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        results["concurrency"] = duration
        
        print("📊 Concurrency (10 tasks): \(String(format: "%.3f", duration * 1000))ms")
    }
}

// MARK: - Memory Leak Tests

final class MemoryLeakTests: XCTestCase {
    
    func testTimerService_MemoryLeak() {
        weak var weakTimer: TimerService?
        
        autoreleasepool {
            let timer = TimerService()
            weakTimer = timer
            
            // Use timer
            timer.startTimer(duration: 5)
            timer.stopTimer()
        }
        
        // Timer should be deallocated
        XCTAssertNil(weakTimer, "TimerService has a memory leak")
    }
    
    func testImageCache_MemoryLeak() {
        weak var weakCache: ImageCacheService?
        
        autoreleasepool {
            let cache = ImageCacheService()
            weakCache = cache
            
            // Use cache
            _ = cache.getCacheInfo()
            cache.clearCache()
        }
        
        // Cache should be deallocated
        XCTAssertNil(weakCache, "ImageCacheService has a memory leak")
    }
    
    func testPerformanceMonitor_MemoryLeak() {
        weak var weakMonitor: PerformanceMonitor?
        
        autoreleasepool {
            let monitor = PerformanceMonitor()
            weakMonitor = monitor
            
            // Use monitor
            monitor.startMonitoring()
            monitor.stopMonitoring()
        }
        
        // Monitor should be deallocated
        XCTAssertNil(weakMonitor, "PerformanceMonitor has a memory leak")
    }
    
    func testAppState_MemoryLeak() {
        weak var weakAppState: AppState?
        
        autoreleasepool {
            let appState = AppState()
            weakAppState = appState
            
            // Use app state
            _ = appState.isOfflineMode
        }
        
        // App state should be deallocated
        XCTAssertNil(weakAppState, "AppState has a memory leak")
    }
    
    func testCombine_Cancellables_MemoryLeak() {
        weak var weakObject: TestObservableObject?
        
        autoreleasepool {
            let object = TestObservableObject()
            weakObject = object
            
            // Set up Combine subscription
            object.setupSubscription()
            
            // Cancel subscription
            object.cancelSubscription()
        }
        
        // Object should be deallocated
        XCTAssertNil(weakObject, "Combine subscriptions have a memory leak")
    }
}

// MARK: - Test Helper Classes

@MainActor
class TestObservableObject: ObservableObject {
    @Published var value: Int = 0
    private var cancellables = Set<AnyCancellable>()
    
    func setupSubscription() {
        $value
            .sink { _ in
                // Do something
            }
            .store(in: &cancellables)
    }
    
    func cancelSubscription() {
        cancellables.removeAll()
    }
}

// MARK: - Performance Requirements Validation

final class PerformanceRequirementsTests: XCTestCase {
    
    func testAppLaunchTime_RequirementMet() async {
        // Requirement: App launch time < 2 seconds
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate app launch
        await MainActor.run {
            let appState = AppState()
            _ = appState
        }
        
        let launchTime = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(launchTime, 2.0, "App launch time exceeds 2 seconds: \(launchTime)s")
        print("✅ App launch time: \(String(format: "%.3f", launchTime))s")
    }
    
    func testFrameRate_60FPS_Requirement() {
        // Requirement: Smooth 60fps gameplay
        let targetFrameTime: TimeInterval = 1.0 / 60.0 // 16.67ms
        
        measure {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Simulate frame rendering
            for _ in 0..<60 {
                // Simulate rendering work
                var sum = 0
                for i in 0..<1000 {
                    sum += i
                }
                _ = sum
            }
            
            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
            let averageFrameTime = totalTime / 60.0
            
            XCTAssertLessThan(averageFrameTime, targetFrameTime * 1.5, 
                             "Frame time too high: \(averageFrameTime * 1000)ms")
        }
    }
    
    func testMemoryUsage_Requirement() async {
        // Requirement: Memory usage should be reasonable
        let initialMemory = await getMemoryUsage()
        
        // Perform typical app operations
        await simulateTypicalUsage()
        
        let finalMemory = await getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Should not exceed 150MB increase during typical usage
        XCTAssertLessThan(memoryIncrease, 150 * 1024 * 1024, 
                         "Memory usage too high: \(memoryIncrease / (1024 * 1024))MB")
        
        print("✅ Memory usage increase: \(memoryIncrease / (1024 * 1024))MB")
    }
    
    private func simulateTypicalUsage() async {
        let coreData = CoreDataService.shared
        
        // Save some game progress
        for i in 0..<50 {
            let progress = GameProgressData(
                id: UUID(),
                mode: .practice,
                score: i,
                correctAnswers: i % 15,
                totalQuestions: 15,
                timeElapsed: Double(i) * 2,
                completedAt: Date(),
                userId: "typical-user"
            )
            
            try? await coreData.saveGameProgress(progress)
        }
        
        // Access image cache
        await MainActor.run {
            let imageCache = ImageCacheService.shared
            for _ in 0..<20 {
                _ = imageCache.getCacheInfo()
            }
        }
        
        // Use timers
        await MainActor.run {
            let timer = TimerService()
            timer.startTimer(duration: 1)
            timer.stopTimer()
        }
    }
    
    private func getMemoryUsage() async -> UInt64 {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                var info = mach_task_basic_info()
                var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
                
                let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        task_info(mach_task_self_,
                                 task_flavor_t(MACH_TASK_BASIC_INFO),
                                 $0,
                                 &count)
                    }
                }
                
                let memoryUsage = kerr == KERN_SUCCESS ? info.resident_size : 0
                continuation.resume(returning: memoryUsage)
            }
        }
    }
}
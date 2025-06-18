import Foundation
import SwiftUI
import os.log

// MARK: - Performance Monitor

final class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    private let logger = Logger(subsystem: "com.botanybattle.app", category: "Performance")
    private var measurements: [String: PerformanceMeasurement] = [:]
    private let queue = DispatchQueue(label: "performance.monitor", qos: .utility)
    
    private init() {}
    
    // MARK: - Measurement Management
    
    func startMeasurement(_ identifier: String, category: PerformanceCategory = .general) {
        queue.async {
            let measurement = PerformanceMeasurement(
                identifier: identifier,
                category: category,
                startTime: CFAbsoluteTimeGetCurrent()
            )
            self.measurements[identifier] = measurement
            self.logger.debug("Started measurement: \(identifier)")
        }
    }
    
    func endMeasurement(_ identifier: String) {
        queue.async {
            guard var measurement = self.measurements[identifier] else {
                self.logger.warning("No measurement found for identifier: \(identifier)")
                return
            }
            
            measurement.endTime = CFAbsoluteTimeGetCurrent()
            measurement.duration = measurement.endTime - measurement.startTime
            
            self.measurements[identifier] = measurement
            
            self.logger.info("Completed measurement: \(identifier) - Duration: \(measurement.duration)s")
            
            // Log slow operations
            if measurement.duration > measurement.category.warningThreshold {
                self.logger.warning("Slow operation detected: \(identifier) took \(measurement.duration)s")
            }
            
            // Store for analytics
            self.recordMeasurement(measurement)
        }
    }
    
    func measureAsync<T>(
        _ identifier: String,
        category: PerformanceCategory = .general,
        operation: @escaping () async throws -> T
    ) async rethrows -> T {
        startMeasurement(identifier, category: category)
        defer { endMeasurement(identifier) }
        return try await operation()
    }
    
    func measureSync<T>(
        _ identifier: String,
        category: PerformanceCategory = .general,
        operation: () throws -> T
    ) rethrows -> T {
        startMeasurement(identifier, category: category)
        defer { endMeasurement(identifier) }
        return try operation()
    }
    
    // MARK: - Analytics
    
    private func recordMeasurement(_ measurement: PerformanceMeasurement) {
        // Record measurement for analytics
        AnalyticsService.shared.recordPerformanceMetric(
            identifier: measurement.identifier,
            category: measurement.category.rawValue,
            duration: measurement.duration,
            timestamp: Date()
        )
    }
    
    func getAverageDuration(for identifier: String) -> Double? {
        // This would typically query stored measurements from analytics
        // For now, return the current measurement duration
        return measurements[identifier]?.duration
    }
    
    func getAllMeasurements() -> [PerformanceMeasurement] {
        return Array(measurements.values)
    }
    
    func clearMeasurements() {
        queue.async {
            self.measurements.removeAll()
        }
    }
}

// MARK: - Performance Measurement

struct PerformanceMeasurement {
    let identifier: String
    let category: PerformanceCategory
    let startTime: CFAbsoluteTime
    var endTime: CFAbsoluteTime = 0
    var duration: Double = 0
    
    var isCompleted: Bool {
        endTime > 0
    }
}

// MARK: - Performance Categories

enum PerformanceCategory: String, CaseIterable {
    case general = "general"
    case gameLogic = "game_logic"
    case networking = "networking"
    case userInterface = "user_interface"
    case dataProcessing = "data_processing"
    case imageLoading = "image_loading"
    case timerOperations = "timer_operations"
    case scoring = "scoring"
    case persistence = "persistence"
    
    var warningThreshold: Double {
        switch self {
        case .general: return 1.0
        case .gameLogic: return 0.5
        case .networking: return 3.0
        case .userInterface: return 0.1
        case .dataProcessing: return 0.5
        case .imageLoading: return 2.0
        case .timerOperations: return 0.05
        case .scoring: return 0.2
        case .persistence: return 0.3
        }
    }
}

// MARK: - Memory Monitor

final class MemoryMonitor: ObservableObject {
    static let shared = MemoryMonitor()
    
    private let logger = Logger(subsystem: "com.botanybattle.app", category: "Memory")
    @Published var currentMemoryUsage: UInt64 = 0
    @Published var peakMemoryUsage: UInt64 = 0
    
    private var timer: Timer?
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.updateMemoryUsage()
        }
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateMemoryUsage() {
        let usage = getCurrentMemoryUsage()
        
        DispatchQueue.main.async {
            self.currentMemoryUsage = usage
            self.peakMemoryUsage = max(self.peakMemoryUsage, usage)
        }
        
        // Log memory warnings
        let usageInMB = Double(usage) / 1024.0 / 1024.0
        if usageInMB > 100.0 { // Warn if using more than 100MB
            logger.warning("High memory usage detected: \(usageInMB, precision: 1) MB")
        }
        
        // Record for analytics
        AnalyticsService.shared.recordMemoryUsage(usage)
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    func logMemorySnapshot(_ context: String) {
        let usage = getCurrentMemoryUsage()
        let usageInMB = Double(usage) / 1024.0 / 1024.0
        logger.info("Memory snapshot (\(context)): \(usageInMB, precision: 1) MB")
    }
}

// MARK: - Frame Rate Monitor

final class FrameRateMonitor: ObservableObject {
    static let shared = FrameRateMonitor()
    
    private let logger = Logger(subsystem: "com.botanybattle.app", category: "FrameRate")
    @Published var currentFPS: Double = 60.0
    @Published var averageFPS: Double = 60.0
    
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var totalTime: CFTimeInterval = 0
    
    private init() {}
    
    func startMonitoring() {
        guard displayLink == nil else { return }
        
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
        frameCount = 0
        totalTime = 0
    }
    
    @objc private func displayLinkTick(_ displayLink: CADisplayLink) {
        let currentTimestamp = displayLink.timestamp
        
        if lastTimestamp > 0 {
            let deltaTime = currentTimestamp - lastTimestamp
            let fps = 1.0 / deltaTime
            
            DispatchQueue.main.async {
                self.currentFPS = fps
            }
            
            frameCount += 1
            totalTime += deltaTime
            
            // Calculate average FPS over last 60 frames
            if frameCount >= 60 {
                let avgFPS = Double(frameCount) / totalTime
                
                DispatchQueue.main.async {
                    self.averageFPS = avgFPS
                }
                
                // Log performance issues
                if avgFPS < 45.0 {
                    logger.warning("Low frame rate detected: \(avgFPS, precision: 1) FPS")
                }
                
                // Record for analytics
                AnalyticsService.shared.recordFrameRate(avgFPS)
                
                // Reset counters
                frameCount = 0
                totalTime = 0
            }
        }
        
        lastTimestamp = currentTimestamp
    }
}

// MARK: - Image Cache Manager

final class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSString, UIImage>()
    private let logger = Logger(subsystem: "com.botanybattle.app", category: "ImageCache")
    
    private init() {
        // Configure cache limits
        cache.countLimit = 100 // Maximum 100 images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    func setImage(_ image: UIImage, forKey key: String) {
        let cost = imageMemorySize(image)
        cache.setObject(image, forKey: key as NSString, cost: cost)
        logger.debug("Cached image: \(key) (\(cost) bytes)")
    }
    
    func getImage(forKey key: String) -> UIImage? {
        let image = cache.object(forKey: key as NSString)
        if image != nil {
            logger.debug("Cache hit: \(key)")
        }
        return image
    }
    
    @objc private func clearCache() {
        cache.removeAllObjects()
        logger.info("Image cache cleared due to memory warning")
    }
    
    private func imageMemorySize(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.height * cgImage.bytesPerRow
    }
    
    func getCacheInfo() -> (count: Int, size: String) {
        // Approximate cache size
        let count = cache.countLimit
        let sizeInMB = Double(cache.totalCostLimit) / 1024.0 / 1024.0
        return (count, String(format: "%.1f MB", sizeInMB))
    }
}

// MARK: - Performance View Modifier

struct PerformanceTracked: ViewModifier {
    let identifier: String
    let category: PerformanceCategory
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                PerformanceMonitor.shared.startMeasurement(
                    "\(identifier)_view_appear",
                    category: .userInterface
                )
            }
            .onDisappear {
                PerformanceMonitor.shared.endMeasurement(
                    "\(identifier)_view_appear"
                )
            }
    }
}

extension View {
    func performanceTracked(
        identifier: String,
        category: PerformanceCategory = .userInterface
    ) -> some View {
        modifier(PerformanceTracked(identifier: identifier, category: category))
    }
}

// MARK: - Debounce Helper

final class Debouncer {
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue
    
    init(queue: DispatchQueue = .main) {
        self.queue = queue
    }
    
    func debounce(delay: TimeInterval, action: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem(block: action)
        
        if let workItem = workItem {
            queue.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }
}
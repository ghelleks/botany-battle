import Foundation
import Combine
import SwiftUI

// MARK: - Performance Monitor

@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var isMonitoring = false
    @Published var currentMetrics = PerformanceMetrics()
    @Published var alerts: [PerformanceAlert] = []
    
    // Configuration
    private let memoryWarningThreshold: UInt64 = 150 * 1024 * 1024 // 150MB
    private let cpuUsageThreshold: Double = 80.0 // 80%
    private let frameRateThreshold: Double = 45.0 // 45 FPS
    private let maxAlerts = 10
    
    // Monitoring
    private var timer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var startTime = Date()
    private var frameTimestamps: [CFTimeInterval] = []
    
    // Callbacks
    var onMemoryWarning: (() -> Void)?
    var onPerformanceIssue: ((PerformanceIssue) -> Void)?
    
    init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        // Monitor memory warnings
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
        
        // Monitor app lifecycle
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.startMonitoring()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.pauseMonitoring()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        startTime = Date()
        print("📊 Performance monitoring started")
        
        // Start periodic monitoring
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMetrics()
            }
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        timer?.cancel()
        timer = nil
        print("📊 Performance monitoring stopped")
    }
    
    func pauseMonitoring() {
        timer?.cancel()
        timer = nil
    }
    
    func logPerformanceIssue(_ issue: PerformanceIssue) {
        let alert = PerformanceAlert(
            id: UUID(),
            issue: issue,
            timestamp: Date(),
            metrics: currentMetrics
        )
        
        alerts.append(alert)
        
        // Keep only recent alerts
        if alerts.count > maxAlerts {
            alerts.removeFirst(alerts.count - maxAlerts)
        }
        
        print("⚠️ Performance issue logged: \(issue)")
    }
    
    func measureTaskDuration<T>(
        _ taskName: String,
        task: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            Task { @MainActor in
                self.logTaskDuration(taskName, duration: duration)
            }
        }
        
        return try await task()
    }
    
    func measureViewRenderTime<T: View>(
        _ viewName: String,
        @ViewBuilder view: () -> T
    ) -> some View {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        return view()
            .onAppear {
                let renderTime = CFAbsoluteTimeGetCurrent() - startTime
                logViewRenderTime(viewName, duration: renderTime)
            }
    }
    
    func recordFrameTime() {
        let currentTime = CFAbsoluteTimeGetCurrent()
        frameTimestamps.append(currentTime)
        
        // Keep only last 60 timestamps (for 1 second at 60fps)
        if frameTimestamps.count > 60 {
            frameTimestamps.removeFirst(frameTimestamps.count - 60)
        }
        
        updateFrameRate()
    }
    
    // MARK: - Private Methods
    
    private func updateMetrics() {
        Task {
            let newMetrics = PerformanceMetrics(
                memoryUsage: getMemoryUsage(),
                cpuUsage: getCPUUsage(),
                frameRate: calculateFrameRate(),
                uptime: Date().timeIntervalSince(startTime),
                batteryLevel: UIDevice.current.batteryLevel
            )
            
            await MainActor.run {
                self.currentMetrics = newMetrics
                self.checkThresholds(newMetrics)
            }
        }
    }
    
    private func getMemoryUsage() -> UInt64 {
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
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    private func getCPUUsage() -> Double {
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
        
        if kerr == KERN_SUCCESS {
            // This is a simplified CPU usage calculation
            return Double(info.virtual_size) / Double(1024 * 1024) // Convert to MB as proxy
        } else {
            return 0.0
        }
    }
    
    private func calculateFrameRate() -> Double {
        guard frameTimestamps.count >= 2 else { return 0.0 }
        
        let timeSpan = frameTimestamps.last! - frameTimestamps.first!
        let frameCount = Double(frameTimestamps.count - 1)
        
        return frameCount / timeSpan
    }
    
    private func updateFrameRate() {
        let frameRate = calculateFrameRate()
        currentMetrics.frameRate = frameRate
        
        if frameRate < frameRateThreshold && frameRate > 0 {
            onPerformanceIssue?(.lowFrameRate(frameRate))
        }
    }
    
    private func checkThresholds(_ metrics: PerformanceMetrics) {
        // Check memory usage
        if metrics.memoryUsage > memoryWarningThreshold {
            onPerformanceIssue?(.highMemoryUsage(metrics.memoryUsage))
        }
        
        // Check CPU usage
        if metrics.cpuUsage > cpuUsageThreshold {
            onPerformanceIssue?(.highCPUUsage(metrics.cpuUsage))
        }
        
        // Check frame rate
        if metrics.frameRate < frameRateThreshold && metrics.frameRate > 0 {
            onPerformanceIssue?(.lowFrameRate(metrics.frameRate))
        }
    }
    
    private func handleMemoryWarning() {
        onMemoryWarning?()
        logPerformanceIssue(.memoryWarning)
    }
    
    private func logTaskDuration(_ taskName: String, duration: TimeInterval) {
        if duration > 1.0 { // Log tasks taking more than 1 second
            logPerformanceIssue(.slowTask(taskName, duration))
        }
    }
    
    private func logViewRenderTime(_ viewName: String, duration: TimeInterval) {
        if duration > 0.1 { // Log views taking more than 100ms to render
            logPerformanceIssue(.slowViewRender(viewName, duration))
        }
    }
    
    // MARK: - Analytics
    
    func getPerformanceReport() -> PerformanceReport {
        let averageMemory = alerts.compactMap { 
            $0.metrics.memoryUsage 
        }.reduce(0, +) / UInt64(max(alerts.count, 1))
        
        let averageCPU = alerts.compactMap { 
            $0.metrics.cpuUsage 
        }.reduce(0, +) / Double(max(alerts.count, 1))
        
        let averageFrameRate = alerts.compactMap { 
            $0.metrics.frameRate 
        }.reduce(0, +) / Double(max(alerts.count, 1))
        
        let issueBreakdown = Dictionary(
            grouping: alerts.map { $0.issue },
            by: { $0.category }
        ).mapValues { $0.count }
        
        return PerformanceReport(
            sessionDuration: Date().timeIntervalSince(startTime),
            totalAlerts: alerts.count,
            averageMemoryUsage: averageMemory,
            averageCPUUsage: averageCPU,
            averageFrameRate: averageFrameRate,
            issueBreakdown: issueBreakdown,
            currentMetrics: currentMetrics
        )
    }
}

// MARK: - Performance Data Models

struct PerformanceMetrics {
    var memoryUsage: UInt64 = 0
    var cpuUsage: Double = 0.0
    var frameRate: Double = 0.0
    var uptime: TimeInterval = 0
    var batteryLevel: Float = -1.0
    
    var formattedMemoryUsage: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory)
    }
    
    var formattedCPUUsage: String {
        String(format: "%.1f%%", cpuUsage)
    }
    
    var formattedFrameRate: String {
        String(format: "%.1f fps", frameRate)
    }
    
    var formattedUptime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: uptime) ?? "0s"
    }
}

enum PerformanceIssue: Equatable {
    case highMemoryUsage(UInt64)
    case highCPUUsage(Double)
    case lowFrameRate(Double)
    case memoryWarning
    case slowTask(String, TimeInterval)
    case slowViewRender(String, TimeInterval)
    case networkTimeout
    case cacheOverflow
    
    var category: String {
        switch self {
        case .highMemoryUsage, .memoryWarning, .cacheOverflow:
            return "Memory"
        case .highCPUUsage:
            return "CPU"
        case .lowFrameRate:
            return "Rendering"
        case .slowTask, .slowViewRender:
            return "Performance"
        case .networkTimeout:
            return "Network"
        }
    }
    
    var description: String {
        switch self {
        case .highMemoryUsage(let usage):
            return "High memory usage: \(ByteCountFormatter.string(fromByteCount: Int64(usage), countStyle: .memory))"
        case .highCPUUsage(let usage):
            return "High CPU usage: \(String(format: "%.1f%%", usage))"
        case .lowFrameRate(let rate):
            return "Low frame rate: \(String(format: "%.1f fps", rate))"
        case .memoryWarning:
            return "Memory warning received"
        case .slowTask(let name, let duration):
            return "Slow task '\(name)': \(String(format: "%.2fs", duration))"
        case .slowViewRender(let name, let duration):
            return "Slow view render '\(name)': \(String(format: "%.2fs", duration))"
        case .networkTimeout:
            return "Network request timeout"
        case .cacheOverflow:
            return "Cache overflow detected"
        }
    }
    
    var severity: AlertSeverity {
        switch self {
        case .memoryWarning, .highMemoryUsage:
            return .critical
        case .highCPUUsage, .lowFrameRate:
            return .warning
        case .slowTask, .slowViewRender, .networkTimeout, .cacheOverflow:
            return .info
        }
    }
}

enum AlertSeverity {
    case info
    case warning
    case critical
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "xmark.octagon"
        }
    }
}

struct PerformanceAlert: Identifiable {
    let id: UUID
    let issue: PerformanceIssue
    let timestamp: Date
    let metrics: PerformanceMetrics
}

struct PerformanceReport {
    let sessionDuration: TimeInterval
    let totalAlerts: Int
    let averageMemoryUsage: UInt64
    let averageCPUUsage: Double
    let averageFrameRate: Double
    let issueBreakdown: [String: Int]
    let currentMetrics: PerformanceMetrics
}

// MARK: - Performance View Modifier

struct PerformanceMonitoringModifier: ViewModifier {
    let viewName: String
    @StateObject private var monitor = PerformanceMonitor.shared
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                monitor.recordFrameTime()
            }
            .background(
                // Invisible view that triggers frame recording
                Rectangle()
                    .fill(Color.clear)
                    .onReceive(Timer.publish(every: 1/60.0, on: .main, in: .common).autoconnect()) { _ in
                        monitor.recordFrameTime()
                    }
            )
    }
}

extension View {
    func performanceMonitoring(_ viewName: String) -> some View {
        modifier(PerformanceMonitoringModifier(viewName: viewName))
    }
}

// MARK: - Performance Dashboard View

struct PerformanceDashboard: View {
    @StateObject private var monitor = PerformanceMonitor.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("Current Metrics") {
                    MetricRow(title: "Memory Usage", value: monitor.currentMetrics.formattedMemoryUsage, icon: "memorychip")
                    MetricRow(title: "Frame Rate", value: monitor.currentMetrics.formattedFrameRate, icon: "speedometer")
                    MetricRow(title: "Uptime", value: monitor.currentMetrics.formattedUptime, icon: "clock")
                }
                
                Section("Recent Alerts") {
                    if monitor.alerts.isEmpty {
                        Text("No performance issues detected")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(monitor.alerts.suffix(5).reversed(), id: \.id) { alert in
                            AlertRow(alert: alert)
                        }
                    }
                }
                
                Section("Controls") {
                    Button(monitor.isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
                        if monitor.isMonitoring {
                            monitor.stopMonitoring()
                        } else {
                            monitor.startMonitoring()
                        }
                    }
                    .foregroundColor(monitor.isMonitoring ? .red : .green)
                    
                    Button("Clear Alerts") {
                        monitor.alerts.removeAll()
                    }
                    .foregroundColor(.orange)
                    .disabled(monitor.alerts.isEmpty)
                }
            }
            .navigationTitle("Performance")
            .onAppear {
                monitor.startMonitoring()
            }
        }
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(title)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

struct AlertRow: View {
    let alert: PerformanceAlert
    
    var body: some View {
        HStack {
            Image(systemName: alert.issue.severity.icon)
                .foregroundColor(alert.issue.severity.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.issue.description)
                    .font(.subheadline)
                
                Text(alert.timestamp.formatted(.dateTime.hour().minute().second()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    PerformanceDashboard()
}
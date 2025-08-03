import Foundation
import Combine
import SwiftUI

// MARK: - Error Handling Service

@MainActor
class ErrorHandlingService: ObservableObject {
    static let shared = ErrorHandlingService()
    
    @Published var currentError: AppError?
    @Published var errorHistory: [ErrorEvent] = []
    @Published var isShowingError = false
    
    private let maxErrorHistory = 100
    private var cancellables = Set<AnyCancellable>()
    
    // Error reporting configuration
    private var reportingEnabled = true
    private var crashlyticsEnabled = false // Would integrate with Firebase Crashlytics
    
    init() {
        setupErrorMonitoring()
    }
    
    private func setupErrorMonitoring() {
        // Monitor for unhandled errors
        $currentError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error = error {
                    self?.logError(error)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Error Handling
    
    func handleError(_ error: Error, context: ErrorContext = .general) {
        let appError = AppError.from(error, context: context)
        handleAppError(appError)
    }
    
    func handleAppError(_ error: AppError) {
        currentError = error
        isShowingError = true
        
        // Log the error
        logError(error)
        
        // Report to analytics if enabled
        if reportingEnabled {
            reportError(error)
        }
        
        // Handle specific error types
        handleSpecificError(error)
    }
    
    private func handleSpecificError(_ error: AppError) {
        switch error.category {
        case .network:
            handleNetworkError(error)
        case .data:
            handleDataError(error)
        case .authentication:
            handleAuthError(error)
        case .game:
            handleGameError(error)
        case .system:
            handleSystemError(error)
        case .user:
            handleUserError(error)
        }
    }
    
    private func handleNetworkError(_ error: AppError) {
        // Switch to offline mode if network errors persist
        if error.severity == .critical {
            NotificationCenter.default.post(
                name: .networkErrorDetected,
                object: error
            )
        }
    }
    
    private func handleDataError(_ error: AppError) {
        // Attempt data recovery or backup restoration
        if error.severity == .critical {
            NotificationCenter.default.post(
                name: .dataCorruptionDetected,
                object: error
            )
        }
    }
    
    private func handleAuthError(_ error: AppError) {
        // Handle authentication failures
        if error.code == "auth_expired" {
            NotificationCenter.default.post(
                name: .authenticationExpired,
                object: error
            )
        }
    }
    
    private func handleGameError(_ error: AppError) {
        // Handle game-specific errors
        if error.severity == .critical {
            // Save current game state before handling error
            NotificationCenter.default.post(
                name: .gameCriticalError,
                object: error
            )
        }
    }
    
    private func handleSystemError(_ error: AppError) {
        // Handle system-level errors
        if error.severity == .critical {
            // Prepare for potential app restart
            NotificationCenter.default.post(
                name: .systemCriticalError,
                object: error
            )
        }
    }
    
    private func handleUserError(_ error: AppError) {
        // These are typically user-facing errors that just need display
        // No special handling required
    }
    
    // MARK: - Error Logging
    
    private func logError(_ error: AppError) {
        let event = ErrorEvent(
            error: error,
            timestamp: Date(),
            deviceInfo: getDeviceInfo(),
            appState: getCurrentAppState()
        )
        
        errorHistory.append(event)
        
        // Maintain history size
        if errorHistory.count > maxErrorHistory {
            errorHistory.removeFirst(errorHistory.count - maxErrorHistory)
        }
        
        // Print to console in debug mode
        #if DEBUG
        print("🚨 Error: \(error.localizedDescription)")
        print("   Context: \(error.context)")
        print("   Severity: \(error.severity)")
        print("   Code: \(error.code)")
        if let underlying = error.underlyingError {
            print("   Underlying: \(underlying)")
        }
        #endif
    }
    
    private func reportError(_ error: AppError) {
        // Report to analytics service (Firebase, etc.)
        // This would integrate with your analytics provider
        
        if crashlyticsEnabled {
            // Report to Crashlytics
            // Crashlytics.crashlytics().record(error: error.underlyingError ?? error)
        }
        
        // Log to custom analytics
        let errorData: [String: Any] = [
            "error_code": error.code,
            "error_category": error.category.rawValue,
            "error_severity": error.severity.rawValue,
            "error_context": error.context.rawValue,
            "app_version": getAppVersion(),
            "ios_version": UIDevice.current.systemVersion,
            "device_model": UIDevice.current.model
        ]
        
        // Send to analytics service
        print("📊 Error reported to analytics: \(errorData)")
    }
    
    // MARK: - Error Resolution
    
    func dismissCurrentError() {
        currentError = nil
        isShowingError = false
    }
    
    func retryLastOperation() {
        guard let error = currentError else { return }
        
        // Attempt to retry based on error context
        switch error.context {
        case .networkRequest:
            NotificationCenter.default.post(name: .retryNetworkRequest, object: nil)
        case .dataSync:
            NotificationCenter.default.post(name: .retryDataSync, object: nil)
        case .gameLoad:
            NotificationCenter.default.post(name: .retryGameLoad, object: nil)
        default:
            break
        }
        
        dismissCurrentError()
    }
    
    func canRetry(_ error: AppError) -> Bool {
        switch error.category {
        case .network, .data:
            return error.severity != .critical
        case .game:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Error Recovery
    
    func performErrorRecovery() async {
        guard let error = currentError else { return }
        
        switch error.category {
        case .data:
            await performDataRecovery()
        case .network:
            await performNetworkRecovery()
        case .game:
            await performGameRecovery()
        default:
            break
        }
    }
    
    private func performDataRecovery() async {
        print("🔧 Attempting data recovery...")
        
        // Clear corrupted caches
        try? await CoreDataService.shared.clearCache()
        
        // Reset to defaults if necessary
        NotificationCenter.default.post(name: .dataRecoveryInitiated, object: nil)
    }
    
    private func performNetworkRecovery() async {
        print("🔧 Attempting network recovery...")
        
        // Check connectivity
        let connectivity = NetworkConnectivityService.shared
        let isConnected = await connectivity.checkConnectivity()
        
        if !isConnected {
            // Switch to offline mode
            NotificationCenter.default.post(name: .offlineModeActivated, object: nil)
        }
    }
    
    private func performGameRecovery() async {
        print("🔧 Attempting game recovery...")
        
        // Save current progress if possible
        NotificationCenter.default.post(name: .gameRecoveryInitiated, object: nil)
    }
    
    // MARK: - Utility Methods
    
    private func getDeviceInfo() -> DeviceInfo {
        return DeviceInfo(
            model: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            appVersion: getAppVersion(),
            memoryUsage: getCurrentMemoryUsage(),
            diskSpace: getAvailableDiskSpace()
        )
    }
    
    private func getCurrentAppState() -> String {
        // Return current app state for debugging
        return "active" // Would be more sophisticated in real implementation
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        // Get current memory usage
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
        
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
    
    private func getAvailableDiskSpace() -> Int64 {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            return (systemAttributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        } catch {
            return 0
        }
    }
    
    // MARK: - Error Analytics
    
    func getErrorSummary() -> ErrorSummary {
        let last24Hours = errorHistory.filter { 
            $0.timestamp.timeIntervalSinceNow > -86400 
        }
        
        let errorsByCategory = Dictionary(grouping: last24Hours) { $0.error.category }
        let errorsBySeverity = Dictionary(grouping: last24Hours) { $0.error.severity }
        
        return ErrorSummary(
            totalErrors: errorHistory.count,
            errorsLast24Hours: last24Hours.count,
            errorsByCategory: errorsByCategory.mapValues { $0.count },
            errorsBySeverity: errorsBySeverity.mapValues { $0.count },
            mostCommonErrors: getMostCommonErrors(),
            lastErrorDate: errorHistory.last?.timestamp
        )
    }
    
    private func getMostCommonErrors() -> [String] {
        let errorCounts = Dictionary(grouping: errorHistory) { $0.error.code }
            .mapValues { $0.count }
        
        return errorCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }
    
    func clearErrorHistory() {
        errorHistory.removeAll()
    }
    
    // MARK: - Configuration
    
    func setReportingEnabled(_ enabled: Bool) {
        reportingEnabled = enabled
    }
    
    func setCrashlyticsEnabled(_ enabled: Bool) {
        crashlyticsEnabled = enabled
    }
}

// MARK: - Data Models

struct AppError: LocalizedError, Identifiable {
    let id = UUID()
    let code: String
    let category: ErrorCategory
    let severity: ErrorSeverity
    let context: ErrorContext
    let localizedDescription: String
    let underlyingError: Error?
    let timestamp: Date
    
    init(
        code: String,
        category: ErrorCategory,
        severity: ErrorSeverity,
        context: ErrorContext,
        description: String,
        underlyingError: Error? = nil
    ) {
        self.code = code
        self.category = category
        self.severity = severity
        self.context = context
        self.localizedDescription = description
        self.underlyingError = underlyingError
        self.timestamp = Date()
    }
    
    static func from(_ error: Error, context: ErrorContext) -> AppError {
        // Convert system errors to AppError
        if let appError = error as? AppError {
            return appError
        }
        
        // Handle common error types
        if let urlError = error as? URLError {
            return AppError(
                code: "network_\(urlError.code.rawValue)",
                category: .network,
                severity: .moderate,
                context: context,
                description: urlError.localizedDescription,
                underlyingError: error
            )
        }
        
        if error is DecodingError {
            return AppError(
                code: "data_decoding_failed",
                category: .data,
                severity: .moderate,
                context: context,
                description: "Failed to process data",
                underlyingError: error
            )
        }
        
        // Generic error
        return AppError(
            code: "unknown_error",
            category: .system,
            severity: .moderate,
            context: context,
            description: error.localizedDescription,
            underlyingError: error
        )
    }
}

enum ErrorCategory: String, CaseIterable {
    case network = "network"
    case data = "data"
    case authentication = "authentication"
    case game = "game"
    case system = "system"
    case user = "user"
    
    var icon: String {
        switch self {
        case .network:
            return "wifi.exclamationmark"
        case .data:
            return "externaldrive.badge.exclamationmark"
        case .authentication:
            return "person.badge.exclamationmark"
        case .game:
            return "gamecontroller.fill"
        case .system:
            return "exclamationmark.triangle"
        case .user:
            return "person.crop.circle.badge.exclamationmark"
        }
    }
}

enum ErrorSeverity: String, CaseIterable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case critical = "critical"
    
    var color: Color {
        switch self {
        case .low:
            return .blue
        case .moderate:
            return .yellow
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }
}

enum ErrorContext: String, CaseIterable {
    case general = "general"
    case appLaunch = "app_launch"
    case authentication = "authentication"
    case gameLoad = "game_load"
    case gamePlay = "game_play"
    case dataSync = "data_sync"
    case networkRequest = "network_request"
    case dataStorage = "data_storage"
    case imageLoading = "image_loading"
    case userAction = "user_action"
}

struct ErrorEvent {
    let error: AppError
    let timestamp: Date
    let deviceInfo: DeviceInfo
    let appState: String
}

struct DeviceInfo {
    let model: String
    let systemVersion: String
    let appVersion: String
    let memoryUsage: UInt64
    let diskSpace: Int64
}

struct ErrorSummary {
    let totalErrors: Int
    let errorsLast24Hours: Int
    let errorsByCategory: [ErrorCategory: Int]
    let errorsBySeverity: [ErrorSeverity: Int]
    let mostCommonErrors: [String]
    let lastErrorDate: Date?
}

// MARK: - Error View Modifier

struct ErrorHandlingModifier: ViewModifier {
    @StateObject private var errorHandler = ErrorHandlingService.shared
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $errorHandler.isShowingError) {
                if let error = errorHandler.currentError,
                   errorHandler.canRetry(error) {
                    Button("Retry") {
                        errorHandler.retryLastOperation()
                    }
                }
                
                Button("Dismiss") {
                    errorHandler.dismissCurrentError()
                }
            } message: {
                if let error = errorHandler.currentError {
                    Text(error.localizedDescription)
                }
            }
    }
}

extension View {
    func errorHandling() -> some View {
        modifier(ErrorHandlingModifier())
    }
}

// MARK: - Error Dashboard View

struct ErrorDashboard: View {
    @StateObject private var errorHandler = ErrorHandlingService.shared
    
    var body: some View {
        NavigationView {
            List {
                Section("Current Status") {
                    if let currentError = errorHandler.currentError {
                        ErrorRow(error: currentError)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("No current errors")
                        }
                    }
                }
                
                Section("Recent Errors") {
                    if errorHandler.errorHistory.isEmpty {
                        Text("No errors recorded")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(errorHandler.errorHistory.suffix(10).reversed(), id: \.error.id) { event in
                            ErrorEventRow(event: event)
                        }
                    }
                }
                
                Section("Actions") {
                    Button("Clear History") {
                        errorHandler.clearErrorHistory()
                    }
                    .foregroundColor(.orange)
                    .disabled(errorHandler.errorHistory.isEmpty)
                    
                    if let currentError = errorHandler.currentError,
                       errorHandler.canRetry(currentError) {
                        Button("Retry Last Operation") {
                            errorHandler.retryLastOperation()
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Error Log")
        }
    }
}

struct ErrorRow: View {
    let error: AppError
    
    var body: some View {
        HStack {
            Image(systemName: error.category.icon)
                .foregroundColor(error.severity.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(error.localizedDescription)
                    .font(.subheadline)
                
                Text(error.code)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(error.severity.rawValue.capitalized)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(error.severity.color.opacity(0.2))
                .foregroundColor(error.severity.color)
                .cornerRadius(4)
        }
    }
}

struct ErrorEventRow: View {
    let event: ErrorEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: event.error.category.icon)
                    .foregroundColor(event.error.severity.color)
                    .frame(width: 20)
                
                Text(event.error.localizedDescription)
                    .font(.subheadline)
                    .lineLimit(2)
                
                Spacer()
                
                Text(event.timestamp.formatted(.dateTime.hour().minute()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Context: \(event.error.context.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let networkErrorDetected = Notification.Name("networkErrorDetected")
    static let dataCorruptionDetected = Notification.Name("dataCorruptionDetected")
    static let authenticationExpired = Notification.Name("authenticationExpired")
    static let gameCriticalError = Notification.Name("gameCriticalError")
    static let systemCriticalError = Notification.Name("systemCriticalError")
    static let retryNetworkRequest = Notification.Name("retryNetworkRequest")
    static let retryDataSync = Notification.Name("retryDataSync")
    static let retryGameLoad = Notification.Name("retryGameLoad")
    static let dataRecoveryInitiated = Notification.Name("dataRecoveryInitiated")
    static let gameRecoveryInitiated = Notification.Name("gameRecoveryInitiated")
}

// MARK: - Preview

#Preview {
    ErrorDashboard()
}
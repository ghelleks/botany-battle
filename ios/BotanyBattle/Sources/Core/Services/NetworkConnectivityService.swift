import Foundation
import Network
import Combine

// MARK: - Network Connectivity Service

@MainActor
class NetworkConnectivityService: ObservableObject {
    static let shared = NetworkConnectivityService()
    
    @Published var isConnected = false
    @Published var connectionType: ConnectionType = .unknown
    @Published var connectionQuality: ConnectionQuality = .unknown
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    
    // Connection history for analytics
    @Published var connectionHistory: [ConnectionEvent] = []
    private let maxHistorySize = 50
    
    // Offline mode configuration
    var offlineModeEnabled = true
    var autoSwitchToOffline = true
    
    init() {
        setupNetworkMonitoring()
        startMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
    }
    
    private func startMonitoring() {
        monitor.start(queue: queue)
        print("📡 Network monitoring started")
    }
    
    private func handlePathUpdate(_ path: NWPath) {
        let wasConnected = isConnected
        let newConnectionStatus = path.status == .satisfied
        
        // Update connection status
        isConnected = newConnectionStatus
        connectionType = determineConnectionType(from: path)
        connectionQuality = determineConnectionQuality(from: path)
        
        // Log connection event
        let event = ConnectionEvent(
            timestamp: Date(),
            isConnected: isConnected,
            connectionType: connectionType,
            quality: connectionQuality
        )
        
        addConnectionEvent(event)
        
        // Notify about connectivity changes
        if wasConnected != isConnected {
            handleConnectivityChange(from: wasConnected, to: isConnected)
        }
        
        print("📡 Network status: \(isConnected ? "Connected" : "Disconnected") (\(connectionType))")
    }
    
    private func determineConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
    
    private func determineConnectionQuality(from path: NWPath) -> ConnectionQuality {
        if !isConnected {
            return .none
        }
        
        // Basic quality assessment based on interface type
        switch connectionType {
        case .wifi, .ethernet:
            return .good
        case .cellular:
            return .fair // Could be enhanced with more sophisticated detection
        case .unknown:
            return .poor
        }
    }
    
    private func addConnectionEvent(_ event: ConnectionEvent) {
        connectionHistory.append(event)
        
        // Maintain history size
        if connectionHistory.count > maxHistorySize {
            connectionHistory.removeFirst(connectionHistory.count - maxHistorySize)
        }
    }
    
    private func handleConnectivityChange(from wasConnected: Bool, to isConnected: Bool) {
        if !wasConnected && isConnected {
            handleConnectionRestored()
        } else if wasConnected && !isConnected {
            handleConnectionLost()
        }
    }
    
    private func handleConnectionRestored() {
        print("🌐 Connection restored")
        
        // Post notification for other services
        NotificationCenter.default.post(
            name: .networkConnectivityChanged,
            object: true
        )
        
        // Trigger data sync if needed
        NotificationCenter.default.post(
            name: .networkConnectionRestored,
            object: nil
        )
    }
    
    private func handleConnectionLost() {
        print("📴 Connection lost - switching to offline mode")
        
        // Post notification for other services
        NotificationCenter.default.post(
            name: .networkConnectivityChanged,
            object: false
        )
        
        // Notify about offline mode
        if autoSwitchToOffline {
            NotificationCenter.default.post(
                name: .offlineModeActivated,
                object: nil
            )
        }
    }
    
    // MARK: - Public Methods
    
    func checkConnectivity() async -> Bool {
        // Force a connectivity check
        return await withCheckedContinuation { continuation in
            let testMonitor = NWPathMonitor()
            testMonitor.pathUpdateHandler = { path in
                let isConnected = path.status == .satisfied
                testMonitor.cancel()
                continuation.resume(returning: isConnected)
            }
            testMonitor.start(queue: DispatchQueue.global())
        }
    }
    
    func testNetworkReachability(to host: String) async -> Bool {
        guard let url = URL(string: "https://\(host)") else {
            return false
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    func getConnectionInfo() -> ConnectionInfo {
        return ConnectionInfo(
            isConnected: isConnected,
            type: connectionType,
            quality: connectionQuality,
            uptime: getConnectionUptime(),
            eventsCount: connectionHistory.count
        )
    }
    
    private func getConnectionUptime() -> TimeInterval {
        guard let lastConnectedEvent = connectionHistory.last(where: { $0.isConnected }) else {
            return 0
        }
        
        return Date().timeIntervalSince(lastConnectedEvent.timestamp)
    }
    
    // MARK: - Offline Mode Management
    
    func enableOfflineMode() {
        offlineModeEnabled = true
        NotificationCenter.default.post(
            name: .offlineModeEnabled,
            object: nil
        )
    }
    
    func disableOfflineMode() {
        offlineModeEnabled = false
        NotificationCenter.default.post(
            name: .offlineModeDisabled,
            object: nil
        )
    }
    
    func getOfflineCapabilities() -> OfflineCapabilities {
        return OfflineCapabilities(
            canPlaySinglePlayer: true,
            canAccessCachedPlants: true,
            canViewProfile: true,
            canAccessShop: false, // Requires network for purchases
            canSyncProgress: false
        )
    }
    
    // MARK: - Cleanup
    
    deinit {
        monitor.cancel()
        print("🗑️ NetworkConnectivityService deallocated")
    }
}

// MARK: - Data Models

enum ConnectionType: String, CaseIterable {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case ethernet = "Ethernet"
    case unknown = "Unknown"
    
    var icon: String {
        switch self {
        case .wifi:
            return "wifi"
        case .cellular:
            return "antenna.radiowaves.left.and.right"
        case .ethernet:
            return "cable.connector"
        case .unknown:
            return "questionmark.circle"
        }
    }
}

enum ConnectionQuality: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case none = "None"
    case unknown = "Unknown"
    
    var color: String {
        switch self {
        case .excellent:
            return "green"
        case .good:
            return "blue"
        case .fair:
            return "orange"
        case .poor:
            return "red"
        case .none:
            return "gray"
        case .unknown:
            return "gray"
        }
    }
}

struct ConnectionEvent {
    let timestamp: Date
    let isConnected: Bool
    let connectionType: ConnectionType
    let quality: ConnectionQuality
}

struct ConnectionInfo {
    let isConnected: Bool
    let type: ConnectionType
    let quality: ConnectionQuality
    let uptime: TimeInterval
    let eventsCount: Int
    
    var formattedUptime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: uptime) ?? "0s"
    }
}

struct OfflineCapabilities {
    let canPlaySinglePlayer: Bool
    let canAccessCachedPlants: Bool
    let canViewProfile: Bool
    let canAccessShop: Bool
    let canSyncProgress: Bool
}

// MARK: - Offline Data Manager

@MainActor
class OfflineDataManager: ObservableObject {
    static let shared = OfflineDataManager()
    
    @Published var hasOfflineData = false
    @Published var offlineDataSize: Int64 = 0
    @Published var lastOfflineUpdate: Date?
    
    private let fileManager = FileManager.default
    private let coreDataService = CoreDataService.shared
    private let imageCache = ImageCacheService.shared
    
    init() {
        updateOfflineDataStatus()
    }
    
    // MARK: - Offline Data Management
    
    func prepareOfflineData() async throws {
        print("📦 Preparing offline data...")
        
        // Cache essential plant data
        try await cacheEssentialPlantData()
        
        // Preload images for offline use
        try await preloadEssentialImages()
        
        // Update status
        updateOfflineDataStatus()
        
        lastOfflineUpdate = Date()
        print("✅ Offline data prepared successfully")
    }
    
    private func cacheEssentialPlantData() async throws {
        // Cache a subset of plants for offline play
        let plantAPI = PlantAPIService()
        
        do {
            let plants = try await plantAPI.fetchPlants(limit: 100) // Cache 100 plants
            try await coreDataService.cachePlantData(plants)
            print("✅ Cached \(plants.count) plants for offline use")
        } catch {
            print("❌ Failed to cache plant data: \(error)")
            throw error
        }
    }
    
    private func preloadEssentialImages() async throws {
        guard let cachedPlants = try? await coreDataService.fetchCachedPlants() else {
            return
        }
        
        let imageUrls = cachedPlants.compactMap { $0.imageURL }
        imageCache.preloadImages(Array(imageUrls.prefix(50))) // Preload first 50 images
        
        print("✅ Preloading \(min(50, imageUrls.count)) images for offline use")
    }
    
    func clearOfflineData() async throws {
        try await coreDataService.clearCache()
        imageCache.clearCache()
        
        updateOfflineDataStatus()
        lastOfflineUpdate = nil
        
        print("✅ Offline data cleared")
    }
    
    private func updateOfflineDataStatus() {
        Task {
            do {
                let cachedPlants = try await coreDataService.fetchCachedPlants()
                let cacheInfo = imageCache.getCacheInfo()
                
                await MainActor.run {
                    hasOfflineData = !cachedPlants.isEmpty
                    offlineDataSize = Int64(cacheInfo.currentSize)
                }
            } catch {
                await MainActor.run {
                    hasOfflineData = false
                    offlineDataSize = 0
                }
            }
        }
    }
    
    // MARK: - Offline Capabilities
    
    func getOfflineGameModes() -> [GameMode] {
        guard hasOfflineData else { return [] }
        
        return [.practice, .speedrun, .beatTheClock] // All single-player modes work offline
    }
    
    func canPlayOffline() -> Bool {
        return hasOfflineData
    }
    
    func getOfflineDataSummary() -> OfflineDataSummary {
        return OfflineDataSummary(
            hasData: hasOfflineData,
            dataSize: offlineDataSize,
            lastUpdate: lastOfflineUpdate,
            capabilities: getOfflineCapabilities()
        )
    }
    
    private func getOfflineCapabilities() -> [String] {
        var capabilities: [String] = []
        
        if hasOfflineData {
            capabilities.append("Single-player game modes")
            capabilities.append("Cached plant identification")
            capabilities.append("Progress tracking")
            capabilities.append("Settings management")
        }
        
        return capabilities
    }
}

struct OfflineDataSummary {
    let hasData: Bool
    let dataSize: Int64
    let lastUpdate: Date?
    let capabilities: [String]
    
    var formattedDataSize: String {
        ByteCountFormatter.string(fromByteCount: dataSize, countStyle: .file)
    }
    
    var formattedLastUpdate: String {
        guard let lastUpdate = lastUpdate else { return "Never" }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: lastUpdate, relativeTo: Date())
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let networkConnectionRestored = Notification.Name("networkConnectionRestored")
    static let offlineModeActivated = Notification.Name("offlineModeActivated")
    static let offlineModeEnabled = Notification.Name("offlineModeEnabled")
    static let offlineModeDisabled = Notification.Name("offlineModeDisabled")
}

// MARK: - Preview Support

#if DEBUG
extension NetworkConnectivityService {
    static func mock(isConnected: Bool = true) -> NetworkConnectivityService {
        let service = NetworkConnectivityService()
        service.isConnected = isConnected
        service.connectionType = isConnected ? .wifi : .unknown
        service.connectionQuality = isConnected ? .good : .none
        return service
    }
}

extension OfflineDataManager {
    static func mock(hasOfflineData: Bool = true) -> OfflineDataManager {
        let manager = OfflineDataManager()
        manager.hasOfflineData = hasOfflineData
        manager.offlineDataSize = hasOfflineData ? 50_000_000 : 0 // 50MB
        manager.lastOfflineUpdate = hasOfflineData ? Date().addingTimeInterval(-3600) : nil // 1 hour ago
        return manager
    }
}
#endif
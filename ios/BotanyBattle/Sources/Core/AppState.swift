import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    
    // MARK: - Core Services
    @Published var userDefaultsService = UserDefaultsService()
    @Published var plantAPIService = PlantAPIService()
    @Published var timerService = TimerService()
    @Published var gameCenterService = GameCenterService()
    @Published var coreDataService = CoreDataService.shared
    @Published var imageCache = ImageCacheService.shared
    @Published var performanceMonitor = PerformanceMonitor.shared
    @Published var networkService = NetworkConnectivityService.shared
    @Published var gameProgressService = GameProgressPersistenceService()
    @Published var errorHandler = ErrorHandlingService()
    
    // MARK: - Feature States
    @Published var authFeature = AuthFeature()
    @Published var gameFeature = GameFeature()
    @Published var profileFeature = ProfileFeature()
    @Published var shopFeature = ShopFeature()
    @Published var settingsFeature = SettingsFeature()
    @Published var tutorialFeature = TutorialFeature()
    @Published var practiceFeature = PracticeFeature()
    @Published var speedrunFeature = SpeedrunFeature()
    @Published var beatTheClockFeature = BeatTheClockFeature()
    
    // MARK: - App State
    @Published var isOfflineMode = false
    @Published var currentTab = 0
    @Published var isLoading = true
    @Published var showTutorial = false
    @Published var appError: AppError?
    
    // MARK: - Lazy Services
    lazy var offlineDataManager = OfflineDataManager(
        coreDataService: coreDataService,
        networkService: networkService
    )
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        checkTutorialStatus()
    }
    
    // MARK: - Initialization
    
    func initializeServices() async {
        await performanceMonitor.measureTaskDuration("app_initialization") {
            // Initialize Core Data first
            await coreDataService.initialize()
            
            // Setup network monitoring
            networkService.$isConnected
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isConnected in
                    self?.isOfflineMode = !isConnected
                }
                .store(in: &cancellables)
            
            // Initialize other services
            await gameCenterService.initialize()
            performanceMonitor.startMonitoring()
            
            // Setup feature dependencies
            setupFeatureDependencies()
            
            isLoading = false
        }
    }
    
    // MARK: - Feature Dependencies Setup
    
    private func setupFeatureDependencies() {
        // Inject services into features
        gameFeature.setup(
            timerService: timerService,
            plantAPIService: plantAPIService,
            progressService: gameProgressService
        )
        
        authFeature.setup(
            gameCenterService: gameCenterService,
            userDefaults: userDefaultsService
        )
        
        profileFeature.setup(
            progressService: gameProgressService,
            gameCenterService: gameCenterService
        )
        
        practiceFeature.setup(
            plantAPIService: plantAPIService,
            progressService: gameProgressService
        )
        
        speedrunFeature.setup(
            timerService: timerService,
            plantAPIService: plantAPIService,
            progressService: gameProgressService
        )
        
        beatTheClockFeature.setup(
            timerService: timerService,
            plantAPIService: plantAPIService,
            progressService: gameProgressService
        )
    }
    
    // MARK: - App Lifecycle
    
    func handleAppBackground() {
        // Pause timers and save state
        timerService.pauseTimer()
        
        // Save current game state if active
        Task {
            if let currentGameState = gameFeature.getCurrentGameState() {
                await gameProgressService.saveCurrentGameState(currentGameState)
            }
        }
        
        // Stop performance monitoring
        performanceMonitor.stopMonitoring()
    }
    
    func handleAppForeground() async {
        // Resume performance monitoring
        performanceMonitor.startMonitoring()
        
        // Check network connectivity
        await networkService.checkConnectivity()
        
        // Resume timer if needed
        if gameFeature.shouldResumeTimer() {
            timerService.resumeTimer()
        }
        
        // Refresh data if online
        if !isOfflineMode {
            await refreshAllData()
        }
    }
    
    // MARK: - Data Management
    
    func refreshAllData() async {
        guard !isOfflineMode else { return }
        
        await performanceMonitor.measureTaskDuration("data_refresh") {
            // Refresh plant data
            await plantAPIService.refreshPlantData()
            
            // Sync game progress
            await gameProgressService.syncWithCloud()
            
            // Update Game Center data
            await gameCenterService.syncData()
        }
    }
    
    func clearAllCaches() {
        imageCache.clearCache()
        plantAPIService.clearCache()
        coreDataService.clearTemporaryData()
    }
    
    // MARK: - Offline Support
    
    func canPlayOffline() -> Bool {
        return offlineDataManager.hasOfflineCapabilities()
    }
    
    func getOfflineStatus() -> OfflineStatus {
        return offlineDataManager.getOfflineStatus()
    }
    
    // MARK: - Error Handling
    
    func handleError(_ error: Error) {
        let appError = AppError.from(error)
        errorHandler.handleAppError(appError)
        self.appError = appError
    }
    
    // MARK: - Private Setup
    
    private func setupBindings() {
        // Bind error handler to app error display
        errorHandler.$currentError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.appError = error
            }
            .store(in: &cancellables)
        
        // Bind network status
        networkService.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isOfflineMode = !isConnected
            }
            .store(in: &cancellables)
    }
    
    private func checkTutorialStatus() {
        showTutorial = !userDefaultsService.bool(forKey: "hasSeenTutorial")
    }
    
    func completeTutorial() {
        userDefaultsService.set(true, forKey: "hasSeenTutorial")
        showTutorial = false
    }
}

// MARK: - Supporting Types

struct OfflineStatus {
    let canPlaySinglePlayer: Bool
    let cachedPlantsAvailable: Int
    let lastSyncDate: Date?
    let limitedFeatures: [String]
    
    var statusMessage: String {
        if canPlaySinglePlayer {
            return "Playing offline • \(cachedPlantsAvailable) plants available"
        } else {
            return "Connect to internet for full experience"
        }
    }
}

class OfflineDataManager {
    private let coreDataService: CoreDataService
    private let networkService: NetworkConnectivityService
    
    init(coreDataService: CoreDataService, networkService: NetworkConnectivityService) {
        self.coreDataService = coreDataService
        self.networkService = networkService
    }
    
    func hasOfflineCapabilities() -> Bool {
        // Check if we have cached plant data for offline play
        return true // Simplified for now
    }
    
    func getOfflineStatus() -> OfflineStatus {
        return OfflineStatus(
            canPlaySinglePlayer: true,
            cachedPlantsAvailable: 50, // Would be actual count
            lastSyncDate: Date(),
            limitedFeatures: networkService.isConnected ? [] : ["Multiplayer", "Shop", "Leaderboards"]
        )
    }
}

extension AppError {
    static func from(_ error: Error) -> AppError {
        return AppError(
            code: "unknown_error",
            category: .system,
            severity: .moderate,
            context: .unknown,
            description: error.localizedDescription
        )
    }
}
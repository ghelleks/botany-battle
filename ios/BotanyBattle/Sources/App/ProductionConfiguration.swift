import SwiftUI

// MARK: - Production Configuration

struct ProductionConfiguration {
    
    // MARK: - App Configuration
    static let appName = "Botany Battle"
    static let bundleIdentifier = "com.botanybattle.app"
    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    // MARK: - API Configuration
    static let apiBaseURL = "https://api.inaturalist.org/v1"
    static let apiTimeout: TimeInterval = 30.0
    static let maxRetryAttempts = 3
    
    // MARK: - Performance Configuration
    static let targetFrameRate = 60
    static let maxMemoryUsageMB = 150
    static let appLaunchTimeTarget: TimeInterval = 2.0
    static let serviceInitializationTimeout: TimeInterval = 5.0
    
    // MARK: - Game Configuration
    static let beatTheClockDuration = 60
    static let speedrunTargetQuestions = 25
    static let maxOfflinePlants = 100
    static let cacheExpirationHours = 24
    
    // MARK: - UI Configuration
    static let animationDuration: TimeInterval = 0.3
    static let minimumTapTargetSize: CGFloat = 44.0
    static let defaultCornerRadius: CGFloat = 12.0
    
    // MARK: - Feature Flags
    struct FeatureFlags {
        static let enableMultiplayer = true
        static let enableOfflineMode = true
        static let enablePerformanceMonitoring = true
        static let enableErrorReporting = true
        static let enableAnalytics = false // Disabled for privacy
        static let enableDebugLogging = false
    }
    
    // MARK: - Accessibility Configuration
    struct Accessibility {
        static let enableVoiceOver = true
        static let enableDynamicType = true
        static let enableReducedMotion = true
        static let enableHighContrast = true
        static let minimumContrastRatio = 4.5
    }
    
    // MARK: - Security Configuration
    struct Security {
        static let enableSSLPinning = true
        static let apiKeyRotationDays = 90
        static let sessionTimeoutMinutes = 30
    }
    
    // MARK: - Environment Detection
    enum Environment {
        case development
        case staging
        case production
        
        static var current: Environment {
            #if DEBUG
            return .development
            #elseif STAGING
            return .staging
            #else
            return .production
            #endif
        }
        
        var apiBaseURL: String {
            switch self {
            case .development:
                return "https://dev-api.inaturalist.org/v1"
            case .staging:
                return "https://staging-api.inaturalist.org/v1"
            case .production:
                return "https://api.inaturalist.org/v1"
            }
        }
        
        var enableDebugLogging: Bool {
            switch self {
            case .development:
                return true
            case .staging:
                return true
            case .production:
                return false
            }
        }
    }
    
    // MARK: - Theme Configuration
    struct Theme {
        static let primaryColor = Color.green
        static let accentColor = Color.blue
        static let errorColor = Color.red
        static let warningColor = Color.orange
        static let successColor = Color.green
        
        static let backgroundColor = Color(.systemBackground)
        static let secondaryBackgroundColor = Color(.secondarySystemBackground)
        static let groupedBackgroundColor = Color(.systemGroupedBackground)
    }
    
    // MARK: - Validation
    static func validateConfiguration() -> Bool {
        guard !apiBaseURL.isEmpty,
              apiTimeout > 0,
              maxRetryAttempts > 0,
              appLaunchTimeTarget > 0,
              beatTheClockDuration > 0,
              speedrunTargetQuestions > 0 else {
            assertionFailure("Invalid production configuration")
            return false
        }
        
        return true
    }
    
    // MARK: - Runtime Information
    static var runtimeInfo: [String: Any] {
        return [
            "appName": appName,
            "version": version,
            "buildNumber": buildNumber,
            "environment": Environment.current.description,
            "device": UIDevice.current.model,
            "osVersion": UIDevice.current.systemVersion,
            "bundleIdentifier": bundleIdentifier
        ]
    }
}

// MARK: - Environment Description
extension ProductionConfiguration.Environment: CustomStringConvertible {
    var description: String {
        switch self {
        case .development:
            return "development"
        case .staging:
            return "staging"
        case .production:
            return "production"
        }
    }
}

// MARK: - Debug Helpers
#if DEBUG
extension ProductionConfiguration {
    static func printConfiguration() {
        print("🔧 Production Configuration")
        print("   App: \(appName) v\(version) (\(buildNumber))")
        print("   Environment: \(Environment.current)")
        print("   API: \(Environment.current.apiBaseURL)")
        print("   Debug Logging: \(Environment.current.enableDebugLogging)")
        print("   Performance Monitoring: \(FeatureFlags.enablePerformanceMonitoring)")
        print("   Offline Mode: \(FeatureFlags.enableOfflineMode)")
    }
}
#endif
import Foundation
import ComposableArchitecture

// MARK: - AppFeature State Extensions for Guest Mode

extension AppFeature.State {
    
    // MARK: - Authentication Status Helpers
    
    /// Returns the current user's display name (authenticated user or guest)
    var currentUserDisplayName: String {
        if isAuthenticated, let user = auth.currentUser {
            return user.displayName
        } else {
            return guestDisplayName
        }
    }
    
    /// Returns true if the user has access to multiplayer features
    var canAccessMultiplayer: Bool {
        isAuthenticated && authenticationPreference != .disabled
    }
    
    /// Returns true if the user can access social features
    var canAccessSocialFeatures: Bool {
        isAuthenticated
    }
    
    /// Returns true if the user should see upgrade prompts
    var shouldShowUpgradePrompts: Bool {
        isGuestMode && hasAttemptedAuthFeatures
    }
    
    // MARK: - Tab Visibility Helpers
    
    /// Returns true if the profile tab should be visible
    var showProfileTab: Bool {
        isAuthenticated || authenticationPreference == .required
    }
    
    /// Returns true if the leaderboards should be accessible
    var showLeaderboards: Bool {
        isAuthenticated
    }
    
    // MARK: - Feature Access Control
    
    /// Check if a specific authenticated feature can be accessed
    func canAccess(_ feature: AuthenticatedFeature) -> Bool {
        switch authenticationPreference {
        case .disabled:
            return false
        case .required:
            return isAuthenticated
        case .optional:
            return isAuthenticated || feature == .multiplayer // Multiplayer requires auth
        }
    }
    
    /// Get the appropriate message when a feature is not available
    func unavailableFeatureMessage(for feature: AuthenticatedFeature) -> String {
        if authenticationPreference == .disabled {
            return "\(feature.displayName) is currently disabled"
        } else if !isAuthenticated {
            return "Connect with Game Center to access \(feature.displayName)"
        } else {
            return "\(feature.displayName) is not available"
        }
    }
    
    // MARK: - Guest Session Helpers
    
    /// Returns formatted session duration string
    var formattedSessionDuration: String {
        let duration = sessionDuration
        let hours = Int(duration) / 3600
        let minutes = Int(duration % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Returns the user's game statistics
    var gameStatistics: GameStatistics {
        if let guestSession = guestSession {
            return GameStatistics(
                gamesPlayed: guestSession.gamesPlayed,
                totalScore: guestSession.totalScore,
                averageScore: guestSession.averageScore,
                preferredDifficulty: guestSession.preferredDifficulty,
                sessionDuration: sessionDuration
            )
        } else {
            return GameStatistics.empty
        }
    }
    
    // MARK: - Authentication Flow Helpers
    
    /// Returns the appropriate call-to-action for authentication
    var authCallToAction: String {
        if attemptedAuthFeatures.isEmpty {
            return "Connect with Game Center"
        } else {
            let featureNames = attemptedAuthFeatures.map(\.displayName).joined(separator: ", ")
            return "Connect to unlock \(featureNames)"
        }
    }
    
    /// Returns benefits of authenticating based on attempted features
    var authenticationBenefits: [String] {
        var benefits: [String] = []
        
        if attemptedAuthFeatures.contains(.multiplayer) {
            benefits.append("Play against other players")
        }
        if attemptedAuthFeatures.contains(.profile) {
            benefits.append("Track your achievements")
        }
        if attemptedAuthFeatures.contains(.leaderboards) {
            benefits.append("Compare scores globally")
        }
        if attemptedAuthFeatures.contains(.socialFeatures) {
            benefits.append("Connect with friends")
        }
        if attemptedAuthFeatures.contains(.cloudSync) {
            benefits.append("Sync progress across devices")
        }
        
        // Add default benefits if none attempted
        if benefits.isEmpty {
            benefits = [
                "Play multiplayer games",
                "Track achievements",
                "Access leaderboards",
                "Sync across devices"
            ]
        }
        
        return benefits
    }
}

// MARK: - Game Statistics

struct GameStatistics {
    let gamesPlayed: Int
    let totalScore: Int
    let averageScore: Double
    let preferredDifficulty: Game.Difficulty
    let sessionDuration: TimeInterval
    
    static let empty = GameStatistics(
        gamesPlayed: 0,
        totalScore: 0,
        averageScore: 0,
        preferredDifficulty: .medium,
        sessionDuration: 0
    )
    
    var formattedAverageScore: String {
        String(format: "%.1f", averageScore)
    }
    
    var hasPlayedGames: Bool {
        gamesPlayed > 0
    }
}

// MARK: - AppFeature Action Convenience

extension AppFeature {
    
    // MARK: - Authentication Convenience Actions
    
    /// Create action to request authentication for a specific feature
    static func requestFeatureAccess(_ feature: State.AuthenticatedFeature) -> Action {
        .requestFeature(feature)
    }
    
    /// Create action to show authentication prompt with context
    static func showAuthPrompt(for action: State.PendingAuthAction) -> Action {
        .showConnectPrompt(action)
    }
    
    /// Create action to record completed game in guest session
    static func recordGuestGame(score: Int, difficulty: Game.Difficulty) -> Action {
        .recordGameCompletion(score: score, difficulty: difficulty)
    }
    
    /// Create action to update authentication preference
    static func updateAuthPreference(_ preference: State.AuthPreference) -> Action {
        .setAuthenticationPreference(preference)
    }
}
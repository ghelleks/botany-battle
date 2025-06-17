import Foundation
import ComposableArchitecture

// MARK: - AuthFeature Extensions for On-Demand Authentication

extension AuthFeature.State {
    
    // MARK: - Authentication Status Helpers
    
    /// Returns true if authentication should be attempted automatically
    var shouldAttemptAutoAuthentication: Bool {
        switch authenticationMode {
        case .required:
            return true
        case .optional, .onDemand, .disabled:
            return false
        }
    }
    
    /// Returns true if user can skip authentication
    var canSkipAuthentication: Bool {
        authenticationMode != .required
    }
    
    /// Returns true if silent authentication has been attempted and failed
    var hasFailedSilentAuthentication: Bool {
        silentAuthenticationFailed && !isAuthenticated
    }
    
    /// Returns true if too many authentication attempts have been made
    var hasExceededRetryLimit: Bool {
        authenticationRetryCount >= 3
    }
    
    /// Returns time since last authentication attempt
    var timeSinceLastAttempt: TimeInterval? {
        guard let lastAttempt = lastAuthenticationAttempt else { return nil }
        return Date().timeIntervalSince(lastAttempt)
    }
    
    /// Returns appropriate retry delay based on attempt count
    var retryDelay: TimeInterval {
        switch authenticationRetryCount {
        case 0: return 0
        case 1: return 2
        case 2: return 5
        default: return 10
        }
    }
    
    // MARK: - User-Friendly Messages
    
    /// Returns user-friendly authentication status message
    var authenticationStatusMessage: String {
        if isAuthenticated {
            if let user = currentUser {
                return "Connected as \(user.displayName)"
            } else {
                return "Connected to Game Center"
            }
        } else if hasFailedSilentAuthentication {
            return "Game Center not available"
        } else if isLoading {
            return "Connecting to Game Center..."
        } else {
            return "Not connected to Game Center"
        }
    }
    
    /// Returns appropriate call-to-action based on current state
    var authenticationCallToAction: String {
        if isAuthenticated {
            return "Connected"
        } else if hasExceededRetryLimit {
            return "Try Again Later"
        } else if isLoading {
            return "Connecting..."
        } else {
            return "Connect to Game Center"
        }
    }
    
    /// Returns user-friendly error message for authentication failures
    var friendlyErrorMessage: String? {
        guard let error = error else { return nil }
        
        if error.contains("not authenticated") {
            return "Please sign in to Game Center in Settings"
        } else if error.contains("network") || error.contains("connection") {
            return "Check your internet connection and try again"
        } else if error.contains("cancelled") {
            return "Authentication was cancelled"
        } else if hasExceededRetryLimit {
            return "Too many attempts. Please try again later"
        } else {
            return "Unable to connect to Game Center"
        }
    }
}

// MARK: - AuthFeature Action Convenience

extension AuthFeature {
    
    // MARK: - Authentication Flow Actions
    
    /// Create action for silent authentication check (no UI prompts)
    static var checkSilently: Action {
        .checkAuthStatusSilently
    }
    
    /// Create action for explicit user-requested authentication
    static var authenticateExplicitly: Action {
        .authenticateWithGameCenter
    }
    
    /// Create action to set authentication mode
    static func setMode(_ mode: AuthenticationMode) -> Action {
        .setAuthenticationMode(mode)
    }
    
    /// Create action to retry authentication with delay
    static var retryWithDelay: Action {
        .retryAuthentication
    }
    
    /// Create action to skip authentication and continue as guest
    static var continueAsGuest: Action {
        .skipAuthentication
    }
}

// MARK: - AuthenticationMode Extensions

extension AuthFeature.AuthenticationMode {
    
    /// User-friendly display name for the authentication mode
    var displayName: String {
        switch self {
        case .required: return "Required"
        case .optional: return "Optional"
        case .disabled: return "Disabled"
        case .onDemand: return "On Demand"
        }
    }
    
    /// Description of what this mode means for users
    var description: String {
        switch self {
        case .required:
            return "Game Center authentication is required to use this app"
        case .optional:
            return "Connect with Game Center for additional features, or continue as guest"
        case .disabled:
            return "Game Center authentication is disabled"
        case .onDemand:
            return "Game Center authentication will be requested when needed"
        }
    }
    
    /// Returns true if this mode allows guest access
    var allowsGuestMode: Bool {
        switch self {
        case .required:
            return false
        case .optional, .disabled, .onDemand:
            return true
        }
    }
    
    /// Returns true if this mode should show authentication UI immediately
    var requiresImmediateAuth: Bool {
        self == .required
    }
}

// MARK: - Authentication Helper Functions

extension AuthFeature {
    
    /// Determine the best authentication action based on current state and mode
    static func recommendedAction(for state: State) -> Action? {
        if state.isAuthenticated {
            return nil // Already authenticated
        }
        
        if state.isLoading {
            return nil // Already in progress
        }
        
        switch state.authenticationMode {
        case .required:
            return .authenticateIfNeeded
        case .optional:
            return state.hasFailedSilentAuthentication ? nil : .checkAuthStatusSilently
        case .onDemand:
            return nil // Only authenticate when explicitly requested
        case .disabled:
            return .skipAuthentication
        }
    }
    
    /// Check if authentication should be retried based on current state
    static func shouldRetryAuthentication(for state: State) -> Bool {
        guard !state.isAuthenticated && !state.isLoading else { return false }
        guard !state.hasExceededRetryLimit else { return false }
        
        // Check if enough time has passed since last attempt
        if let timeSinceLastAttempt = state.timeSinceLastAttempt {
            return timeSinceLastAttempt >= state.retryDelay
        }
        
        return true
    }
}

// MARK: - Integration Helpers

extension AuthFeature.State {
    
    /// Create a summary of the current authentication state for debugging
    var debugSummary: String {
        var summary = ["Authentication State Summary:"]
        summary.append("  Mode: \(authenticationMode.displayName)")
        summary.append("  Authenticated: \(isAuthenticated)")
        summary.append("  Loading: \(isLoading)")
        summary.append("  Retry Count: \(authenticationRetryCount)")
        summary.append("  Silent Failed: \(silentAuthenticationFailed)")
        
        if let error = error {
            summary.append("  Error: \(error)")
        }
        
        if let lastAttempt = lastAuthenticationAttempt {
            summary.append("  Last Attempt: \(lastAttempt)")
        }
        
        return summary.joined(separator: "\n")
    }
}
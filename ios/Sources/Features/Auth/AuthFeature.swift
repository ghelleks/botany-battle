import Foundation
import ComposableArchitecture
import GameKit

@Reducer
struct AuthFeature {
    @ObservableState
    struct State: Equatable {
        var isAuthenticated = false
        var isLoading = false
        var currentUser: User?
        var error: String?
        var showingGameCenterLogin = false
        var authenticationMode: AuthenticationMode = .optional
        var lastAuthenticationAttempt: Date?
        var authenticationRetryCount = 0
        var silentAuthenticationFailed = false
    }
    
    enum AuthenticationMode: Equatable {
        case required    // Force authentication (legacy behavior)
        case optional    // Check status but don't force auth
        case disabled    // Skip all authentication
        case onDemand    // Only authenticate when explicitly requested
    }
    
    enum Action {
        case checkAuthStatus
        case checkAuthStatusSilently
        case authenticateWithGameCenter
        case authenticateIfNeeded
        case logout
        case loginSuccess(User)
        case logoutSuccess
        case authCheckComplete
        case authError(String)
        case clearError
        case showGameCenterLogin
        case hideGameCenterLogin
        case setAuthenticationMode(AuthenticationMode)
        case retryAuthentication
        case skipAuthentication
    }
    
    @Dependency(\.gameCenterService) var gameCenterService
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .checkAuthStatus:
                // Legacy action - behavior depends on authentication mode
                switch state.authenticationMode {
                case .required:
                    return .send(.authenticateIfNeeded)
                case .optional, .onDemand:
                    return .send(.checkAuthStatusSilently)
                case .disabled:
                    return .send(.authCheckComplete)
                }
                
            case .checkAuthStatusSilently:
                // Only check existing authentication status, don't prompt
                state.isLoading = true
                return .run { send in
                    do {
                        if gameCenterService.isAuthenticated() {
                            let user = try await gameCenterService.getCurrentUser()
                            await send(.loginSuccess(user))
                        } else {
                            await send(.authCheckComplete)
                        }
                    } catch {
                        await send(.authCheckComplete)
                    }
                }
                
            case .authenticateIfNeeded:
                // Check status and authenticate if required mode
                state.isLoading = true
                return .run { [mode = state.authenticationMode] send in
                    do {
                        if gameCenterService.isAuthenticated() {
                            let user = try await gameCenterService.getCurrentUser()
                            await send(.loginSuccess(user))
                        } else if mode == .required {
                            // Only force authentication in required mode
                            let user = try await gameCenterService.authenticatePlayer()
                            await send(.loginSuccess(user))
                        } else {
                            await send(.authCheckComplete)
                        }
                    } catch {
                        await send(.authError(error.localizedDescription))
                    }
                }
                
            case .authenticateWithGameCenter:
                // Explicit authentication request
                state.isLoading = true
                state.error = nil
                state.lastAuthenticationAttempt = Date()
                state.authenticationRetryCount += 1
                return .run { send in
                    do {
                        let user = try await gameCenterService.authenticatePlayer()
                        await send(.loginSuccess(user))
                    } catch {
                        await send(.authError(error.localizedDescription))
                    }
                }
                
            case .logout:
                state.isLoading = true
                return .run { send in
                    do {
                        try await gameCenterService.signOut()
                        await send(.logoutSuccess)
                    } catch {
                        await send(.authError(error.localizedDescription))
                    }
                }
                
            case .loginSuccess(let user):
                state.isLoading = false
                state.isAuthenticated = true
                state.currentUser = user
                state.error = nil
                state.showingGameCenterLogin = false
                state.authenticationRetryCount = 0
                state.silentAuthenticationFailed = false
                return .none
                
            case .logoutSuccess:
                state.isLoading = false
                state.isAuthenticated = false
                state.currentUser = nil
                state.error = nil
                state.authenticationRetryCount = 0
                state.lastAuthenticationAttempt = nil
                return .none
                
            case .authCheckComplete:
                state.isLoading = false
                state.isAuthenticated = false
                if state.authenticationMode == .optional {
                    state.silentAuthenticationFailed = true
                }
                return .none
                
            case .authError(let error):
                state.isLoading = false
                state.error = error
                state.silentAuthenticationFailed = true
                return .none
                
            case .clearError:
                state.error = nil
                return .none
                
            case .showGameCenterLogin:
                state.showingGameCenterLogin = true
                return .none
                
            case .hideGameCenterLogin:
                state.showingGameCenterLogin = false
                return .none
                
            case .setAuthenticationMode(let mode):
                state.authenticationMode = mode
                // If switching to required mode and not authenticated, trigger auth
                if mode == .required && !state.isAuthenticated {
                    return .send(.authenticateIfNeeded)
                }
                return .none
                
            case .retryAuthentication:
                // Reset retry count if too many attempts
                if state.authenticationRetryCount >= 3 {
                    state.authenticationRetryCount = 0
                    state.error = "Maximum authentication attempts reached. Please try again later."
                    return .none
                }
                return .send(.authenticateWithGameCenter)
                
            case .skipAuthentication:
                state.isLoading = false
                state.error = nil
                state.silentAuthenticationFailed = true
                return .send(.authCheckComplete)
            }
        }
    }
}
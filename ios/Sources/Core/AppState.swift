import Foundation
import ComposableArchitecture

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var auth = AuthFeature.State()
        var game = GameFeature.State()
        var profile = ProfileFeature.State()
        var shop = ShopFeature.State()
        var settings = SettingsFeature.State()
        var tutorial = TutorialFeature.State()
        var help = HelpFeature.State()
        var isAuthenticated = false
        var isGuestMode = true
        var authenticationPreference: AuthPreference = .optional
        var userRequestedAuthentication = false
        var currentTab: Tab = .game
        
        enum Tab: CaseIterable {
            case game
            case profile
            case shop
            case settings
        }
        
        enum AuthPreference: Equatable {
            case required    // Force authentication (legacy behavior)
            case optional    // Allow guest mode with optional auth
            case disabled    // Never authenticate (testing mode)
        }
        
        // Computed property to determine when to show authentication view
        var showAuthenticationView: Bool {
            switch authenticationPreference {
            case .required:
                return !isAuthenticated
            case .optional:
                return userRequestedAuthentication && !isAuthenticated
            case .disabled:
                return false
            }
        }
        
        // Computed property for features requiring authentication
        var requiresAuthentication: Bool {
            !isAuthenticated && !isGuestMode
        }
    }
    
    enum Action {
        case auth(AuthFeature.Action)
        case game(GameFeature.Action)
        case profile(ProfileFeature.Action)
        case shop(ShopFeature.Action)
        case settings(SettingsFeature.Action)
        case tutorial(TutorialFeature.Action)
        case help(HelpFeature.Action)
        case tabChanged(State.Tab)
        case onAppear
        case requestAuthentication
        case cancelAuthentication
        case enterGuestMode
        case setAuthenticationPreference(State.AuthPreference)
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.auth, action: \.auth) {
            AuthFeature()
        }
        
        Scope(state: \.game, action: \.game) {
            GameFeature()
        }
        
        Scope(state: \.profile, action: \.profile) {
            ProfileFeature()
        }
        
        Scope(state: \.shop, action: \.shop) {
            ShopFeature()
        }
        
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        
        Scope(state: \.tutorial, action: \.tutorial) {
            TutorialFeature()
        }
        
        Scope(state: \.help, action: \.help) {
            HelpFeature()
        }
        
        Reduce { state, action in
            switch action {
            case .auth(.loginSuccess):
                state.isAuthenticated = true
                state.isGuestMode = false
                state.userRequestedAuthentication = false
                return .none
                
            case .auth(.logoutSuccess):
                state.isAuthenticated = false
                state.isGuestMode = true
                state.userRequestedAuthentication = false
                return .none
                
            case .tabChanged(let tab):
                state.currentTab = tab
                return .none
                
            case .onAppear:
                // In guest mode, we skip automatic authentication
                if state.authenticationPreference == .required {
                    return .concatenate(
                        .run { send in
                            await send(.auth(.checkAuthStatus))
                        },
                        .send(.tutorial(.checkTutorialStatus))
                    )
                } else {
                    // Just check tutorial status, skip auth check
                    return .send(.tutorial(.checkTutorialStatus))
                }
                
            case .requestAuthentication:
                state.userRequestedAuthentication = true
                return .send(.auth(.authenticateWithGameCenter))
                
            case .cancelAuthentication:
                state.userRequestedAuthentication = false
                return .none
                
            case .enterGuestMode:
                state.isGuestMode = true
                state.userRequestedAuthentication = false
                return .none
                
            case .setAuthenticationPreference(let preference):
                state.authenticationPreference = preference
                // If switching to required mode and not authenticated, trigger auth
                if preference == .required && !state.isAuthenticated {
                    state.userRequestedAuthentication = true
                    return .send(.auth(.checkAuthStatus))
                }
                return .none
                
            case .auth, .game, .profile, .shop, .settings, .tutorial, .help:
                return .none
            }
        }
    }
}
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
        
        // Authentication State
        var isAuthenticated = false
        var isGuestMode = true
        var authenticationPreference: AuthPreference = .optional
        var userRequestedAuthentication = false
        
        // User Session Management
        var guestSession: GuestSession?
        var sessionStartTime = Date()
        var hasCompletedTutorial = false
        
        // UI State
        var currentTab: Tab = .game
        var showConnectPrompt = false
        var pendingAuthAction: PendingAuthAction?
        
        // Feature Access Tracking
        var attemptedAuthFeatures: Set<AuthenticatedFeature> = []
        
        enum Tab: CaseIterable {
            case game
            case profile
            case shop
            case settings
        }
        
        enum AuthPreference: Equatable, CaseIterable {
            case required    // Force authentication (legacy behavior)
            case optional    // Allow guest mode with optional auth
            case disabled    // Never authenticate (testing mode)
            
            var displayName: String {
                switch self {
                case .required: return "Required"
                case .optional: return "Optional"
                case .disabled: return "Disabled"
                }
            }
        }
        
        enum PendingAuthAction: Equatable {
            case accessMultiplayer
            case viewProfile
            case accessLeaderboards
            case purchaseItems
        }
        
        enum AuthenticatedFeature: String, CaseIterable, Hashable {
            case multiplayer = "multiplayer"
            case profile = "profile"
            case leaderboards = "leaderboards"
            case socialFeatures = "social"
            case cloudSync = "sync"
            
            var displayName: String {
                switch self {
                case .multiplayer: return "Multiplayer Games"
                case .profile: return "Player Profile"
                case .leaderboards: return "Leaderboards"
                case .socialFeatures: return "Social Features"
                case .cloudSync: return "Cloud Sync"
                }
            }
            
            var description: String {
                switch self {
                case .multiplayer: return "Play against other players online"
                case .profile: return "View your Game Center profile and achievements"
                case .leaderboards: return "Compare scores with other players"
                case .socialFeatures: return "Connect with friends and share achievements"
                case .cloudSync: return "Sync your progress across devices"
                }
            }
        }
        
        // Computed Properties
        
        // Determine when to show authentication view
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
        
        // Check if features requiring authentication are blocked
        var requiresAuthentication: Bool {
            !isAuthenticated && !isGuestMode
        }
        
        // Available tabs based on authentication status
        var availableTabs: [Tab] {
            if isAuthenticated {
                return Tab.allCases
            } else {
                // In guest mode, hide profile tab
                return [.game, .shop, .settings]
            }
        }
        
        // Check if specific feature is available
        func isFeatureAvailable(_ feature: AuthenticatedFeature) -> Bool {
            switch feature {
            case .multiplayer, .profile, .leaderboards, .socialFeatures:
                return isAuthenticated
            case .cloudSync:
                return isAuthenticated // Could be made optional in future
            }
        }
        
        // Guest session information
        var guestDisplayName: String {
            guestSession?.displayName ?? "Guest Player"
        }
        
        // Session duration for analytics
        var sessionDuration: TimeInterval {
            Date().timeIntervalSince(sessionStartTime)
        }
        
        // Check if user has attempted auth features
        var hasAttemptedAuthFeatures: Bool {
            !attemptedAuthFeatures.isEmpty
        }
        
        // Get authentication prompt message based on attempted feature
        var authPromptMessage: String {
            guard let pendingAction = pendingAuthAction else {
                return "Connect with Game Center to unlock additional features"
            }
            
            switch pendingAction {
            case .accessMultiplayer:
                return "Connect with Game Center to play against other players"
            case .viewProfile:
                return "Connect with Game Center to view your profile and achievements"
            case .accessLeaderboards:
                return "Connect with Game Center to compare your scores with others"
            case .purchaseItems:
                return "Connect with Game Center to access premium features"
            }
        }
        
        // Get authentication benefits for display
        var authenticationBenefits: [String] {
            [
                "Play multiplayer battles against other players",
                "Compete on global leaderboards",
                "Sync your progress across devices",
                "Earn Game Center achievements"
            ]
        }
    }
    
    // Guest Session Management
    struct GuestSession: Equatable {
        let id: String
        let displayName: String
        let createdAt: Date
        var gamesPlayed: Int
        var totalScore: Int
        var preferredDifficulty: Game.Difficulty
        
        init(displayName: String = "Guest Player") {
            self.id = UUID().uuidString
            self.displayName = displayName
            self.createdAt = Date()
            self.gamesPlayed = 0
            self.totalScore = 0
            self.preferredDifficulty = .medium
        }
        
        mutating func recordGame(score: Int, difficulty: Game.Difficulty) {
            gamesPlayed += 1
            totalScore += score
            preferredDifficulty = difficulty
        }
        
        var averageScore: Double {
            gamesPlayed > 0 ? Double(totalScore) / Double(gamesPlayed) : 0
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
        
        // Authentication Actions
        case requestAuthentication
        case cancelAuthentication
        case enterGuestMode
        case setAuthenticationPreference(State.AuthPreference)
        case requestFeature(State.AuthenticatedFeature)
        case showConnectPrompt(State.PendingAuthAction?)
        case hideConnectPrompt
        
        // Guest Session Actions
        case createGuestSession(String?)
        case updateGuestSession(gamesPlayed: Int, totalScore: Int, difficulty: Game.Difficulty)
        case recordGameCompletion(score: Int, difficulty: Game.Difficulty)
        
        // Session Management
        case sessionStarted
        case tutorialCompleted
        case featureAttempted(State.AuthenticatedFeature)
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
            // MARK: - Authentication Actions
            case .auth(.loginSuccess):
                state.isAuthenticated = true
                state.isGuestMode = false
                state.userRequestedAuthentication = false
                state.showConnectPrompt = false
                state.pendingAuthAction = nil
                // Clear attempted features since user is now authenticated
                state.attemptedAuthFeatures.removeAll()
                // Sync authentication status with GameFeature
                return .concatenate(
                    .send(.game(.setAuthenticationStatus(true))),
                    .send(.game(.authenticationSucceeded))
                )
                
            case .auth(.logoutSuccess):
                state.isAuthenticated = false
                state.isGuestMode = true
                state.userRequestedAuthentication = false
                state.showConnectPrompt = false
                state.pendingAuthAction = nil
                // Sync authentication status with GameFeature and create new guest session
                return .concatenate(
                    .send(.game(.setAuthenticationStatus(false))),
                    .send(.createGuestSession(nil))
                )
                
            case .requestAuthentication:
                state.userRequestedAuthentication = true
                return .send(.auth(.authenticateWithGameCenter))
                
            case .cancelAuthentication:
                state.userRequestedAuthentication = false
                state.showConnectPrompt = false
                state.pendingAuthAction = nil
                return .none
                
            case .enterGuestMode:
                state.isGuestMode = true
                state.userRequestedAuthentication = false
                state.showConnectPrompt = false
                if state.guestSession == nil {
                    return .send(.createGuestSession(nil))
                }
                return .none
                
            case .setAuthenticationPreference(let preference):
                state.authenticationPreference = preference
                let authMode = mapToAuthFeatureMode(preference)
                
                // Sync with AuthFeature
                var effects: [Effect<Action>] = [.send(.auth(.setAuthenticationMode(authMode)))]
                
                // If switching to required mode and not authenticated, trigger auth
                if preference == .required && !state.isAuthenticated {
                    state.userRequestedAuthentication = true
                    effects.append(.send(.auth(.checkAuthStatus)))
                }
                
                return .concatenate(effects)
                
            case .requestFeature(let feature):
                state.attemptedAuthFeatures.insert(feature)
                if !state.isAuthenticated {
                    // Map feature to pending action and show connect prompt
                    let pendingAction: State.PendingAuthAction = switch feature {
                    case .multiplayer: .accessMultiplayer
                    case .profile: .viewProfile
                    case .leaderboards: .accessLeaderboards
                    case .socialFeatures, .cloudSync: .purchaseItems
                    }
                    return .send(.showConnectPrompt(pendingAction))
                }
                return .none
                
            case .showConnectPrompt(let pendingAction):
                state.showConnectPrompt = true
                state.pendingAuthAction = pendingAction
                return .none
                
            case .hideConnectPrompt:
                state.showConnectPrompt = false
                state.pendingAuthAction = nil
                return .none
                
            // MARK: - Guest Session Actions
            case .createGuestSession(let displayName):
                state.guestSession = GuestSession(displayName: displayName ?? "Guest Player")
                state.sessionStartTime = Date()
                return .send(.sessionStarted)
                
            case .updateGuestSession(let gamesPlayed, let totalScore, let difficulty):
                state.guestSession?.gamesPlayed = gamesPlayed
                state.guestSession?.totalScore = totalScore
                state.guestSession?.preferredDifficulty = difficulty
                return .none
                
            case .recordGameCompletion(let score, let difficulty):
                state.guestSession?.recordGame(score: score, difficulty: difficulty)
                return .none
                
            // MARK: - Session Management
            case .sessionStarted:
                state.sessionStartTime = Date()
                return .none
                
            case .tutorialCompleted:
                state.hasCompletedTutorial = true
                return .none
                
            case .featureAttempted(let feature):
                state.attemptedAuthFeatures.insert(feature)
                return .none
                
            // MARK: - Navigation and App Lifecycle
            case .tabChanged(let tab):
                state.currentTab = tab
                // If user tries to access profile tab without authentication, show prompt
                if tab == .profile && !state.isAuthenticated {
                    return .send(.requestFeature(.profile))
                }
                return .none
                
            case .onAppear:
                // Sync authentication status with GameFeature
                var effects: [Effect<Action>] = [.send(.game(.setAuthenticationStatus(state.isAuthenticated)))]
                
                // Initialize guest session if needed
                if state.isGuestMode && state.guestSession == nil {
                    effects.append(contentsOf: [
                        .send(.createGuestSession(nil)),
                        handleInitialAuth(state: state)
                    ])
                } else {
                    effects.append(handleInitialAuth(state: state))
                }
                
                return .concatenate(effects)
                
            // MARK: - Game Delegate Actions
            case .game(.delegate(.requestAuthentication(let feature))):
                // Map GameFeature's AuthenticatedFeature to AppFeature's AuthenticatedFeature
                let appFeature: State.AuthenticatedFeature = switch feature {
                case .multiplayer: .multiplayer
                case .leaderboards: .leaderboards
                }
                return .send(.requestFeature(appFeature))
                
            case .auth, .game, .profile, .shop, .settings, .tutorial, .help:
                return .none
            }
        }
    }
    
    // MARK: - Helper Functions
    private func handleInitialAuth(state: State) -> Effect<Action> {
        // Sync authentication mode with AuthFeature
        let authMode = mapToAuthFeatureMode(state.authenticationPreference)
        
        return .concatenate(
            .send(.auth(.setAuthenticationMode(authMode))),
            // In guest mode, we use silent authentication check
            state.authenticationPreference == .required 
                ? .send(.auth(.checkAuthStatus))
                : .send(.auth(.checkAuthStatusSilently)),
            .send(.tutorial(.checkTutorialStatus))
        )
    }
    
    private func mapToAuthFeatureMode(_ preference: State.AuthPreference) -> AuthFeature.AuthenticationMode {
        switch preference {
        case .required: return .required
        case .optional: return .optional
        case .disabled: return .disabled
        }
    }
}
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
        var isAuthenticated = false
        var currentTab: Tab = .game
        
        enum Tab: CaseIterable {
            case game
            case profile
            case shop
        }
    }
    
    enum Action {
        case auth(AuthFeature.Action)
        case game(GameFeature.Action)
        case profile(ProfileFeature.Action)
        case shop(ShopFeature.Action)
        case tabChanged(State.Tab)
        case onAppear
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
        
        Reduce { state, action in
            switch action {
            case .auth(.loginSuccess):
                state.isAuthenticated = true
                return .none
                
            case .auth(.logoutSuccess):
                state.isAuthenticated = false
                return .none
                
            case .tabChanged(let tab):
                state.currentTab = tab
                return .none
                
            case .onAppear:
                return .run { send in
                    await send(.auth(.checkAuthStatus))
                }
                
            case .auth, .game, .profile, .shop:
                return .none
            }
        }
    }
}
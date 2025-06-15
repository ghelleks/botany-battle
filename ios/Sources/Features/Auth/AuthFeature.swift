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
    }
    
    enum Action {
        case checkAuthStatus
        case authenticateWithGameCenter
        case logout
        case loginSuccess(User)
        case logoutSuccess
        case authCheckComplete
        case authError(String)
        case clearError
        case showGameCenterLogin
        case hideGameCenterLogin
    }
    
    @Dependency(\.gameCenterService) var gameCenterService
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .checkAuthStatus:
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
                
            case .authenticateWithGameCenter:
                state.isLoading = true
                state.error = nil
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
                return .none
                
            case .logoutSuccess:
                state.isLoading = false
                state.isAuthenticated = false
                state.currentUser = nil
                state.error = nil
                return .none
                
            case .authCheckComplete:
                state.isLoading = false
                state.isAuthenticated = false
                return .none
                
            case .authError(let error):
                state.isLoading = false
                state.error = error
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
            }
        }
    }
}
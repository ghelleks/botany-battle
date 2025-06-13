import Foundation
import ComposableArchitecture
import Amplify
import AWSCognitoAuthPlugin

@Reducer
struct AuthFeature {
    @ObservableState
    struct State: Equatable {
        var isAuthenticated = false
        var isLoading = false
        var currentUser: User?
        var error: String?
        var loginForm = LoginForm()
        var signupForm = SignupForm()
        
        struct LoginForm: Equatable {
            var username = ""
            var password = ""
            var isValid: Bool {
                !username.isEmpty && !password.isEmpty
            }
        }
        
        struct SignupForm: Equatable {
            var username = ""
            var email = ""
            var password = ""
            var confirmPassword = ""
            var displayName = ""
            
            var isValid: Bool {
                !username.isEmpty &&
                !email.isEmpty &&
                !password.isEmpty &&
                password == confirmPassword &&
                password.count >= 8
            }
        }
    }
    
    enum Action {
        case checkAuthStatus
        case login(username: String, password: String)
        case signup(username: String, email: String, password: String, displayName: String)
        case logout
        case loginSuccess(User)
        case signupSuccess
        case logoutSuccess
        case authCheckComplete
        case authError(String)
        case clearError
        case updateLoginForm(username: String?, password: String?)
        case updateSignupForm(username: String?, email: String?, password: String?, confirmPassword: String?, displayName: String?)
    }
    
    @Dependency(\.authService) var authService
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .checkAuthStatus:
                state.isLoading = true
                return .run { [state] send in
                    do {
                        let user = try await authService.getCurrentUser()
                        await send(.loginSuccess(user))
                    } catch {
                        // If user is not authenticated, this is not an error - just set loading to false
                        await send(.authCheckComplete)
                    }
                }
                
            case .login(let username, let password):
                state.isLoading = true
                state.error = nil
                return .run { send in
                    do {
                        let user = try await authService.signIn(username: username, password: password)
                        await send(.loginSuccess(user))
                    } catch {
                        await send(.authError(error.localizedDescription))
                    }
                }
                
            case .signup(let username, let email, let password, let displayName):
                state.isLoading = true
                state.error = nil
                return .run { send in
                    do {
                        try await authService.signUp(
                            username: username,
                            email: email,
                            password: password,
                            displayName: displayName
                        )
                        await send(.signupSuccess)
                    } catch {
                        await send(.authError(error.localizedDescription))
                    }
                }
                
            case .logout:
                state.isLoading = true
                return .run { send in
                    do {
                        try await authService.signOut()
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
                return .none
                
            case .signupSuccess:
                state.isLoading = false
                state.error = nil
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
                
            case .updateLoginForm(let username, let password):
                if let username = username {
                    state.loginForm.username = username
                }
                if let password = password {
                    state.loginForm.password = password
                }
                return .none
                
            case .updateSignupForm(let username, let email, let password, let confirmPassword, let displayName):
                if let username = username {
                    state.signupForm.username = username
                }
                if let email = email {
                    state.signupForm.email = email
                }
                if let password = password {
                    state.signupForm.password = password
                }
                if let confirmPassword = confirmPassword {
                    state.signupForm.confirmPassword = confirmPassword
                }
                if let displayName = displayName {
                    state.signupForm.displayName = displayName
                }
                return .none
            }
        }
    }
}
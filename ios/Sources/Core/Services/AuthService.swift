import Foundation
import Amplify
import AWSCognitoAuthPlugin
import Dependencies

protocol AuthServiceProtocol {
    func signIn(username: String, password: String) async throws -> User
    func signUp(username: String, email: String, password: String, displayName: String?) async throws
    func signOut() async throws
    func getCurrentUser() async throws -> User
    func refreshSession() async throws
}

final class AuthService: AuthServiceProtocol {
    func signIn(username: String, password: String) async throws -> User {
        let signInResult = try await Amplify.Auth.signIn(username: username, password: password)
        
        guard signInResult.isSignedIn else {
            throw AuthError.signInFailed
        }
        
        return try await getCurrentUser()
    }
    
    func signUp(username: String, email: String, password: String, displayName: String?) async throws {
        let userAttributes = [
            AuthUserAttribute(.email, value: email),
            AuthUserAttribute(.preferredUsername, value: displayName ?? username)
        ]
        
        let options = AuthSignUpRequest.Options(userAttributes: userAttributes)
        
        let signUpResult = try await Amplify.Auth.signUp(
            username: username,
            password: password,
            options: options
        )
        
        guard signUpResult.isSignUpComplete else {
            throw AuthError.signUpFailed
        }
    }
    
    func signOut() async throws {
        _ = await Amplify.Auth.signOut()
    }
    
    func getCurrentUser() async throws -> User {
        let authUser = try await Amplify.Auth.getCurrentUser()
        let session = try await Amplify.Auth.fetchAuthSession()
        
        guard let cognitoSession = session as? AuthCognitoTokensProvider,
              let tokens = try cognitoSession.getCognitoTokens().get() else {
            throw AuthError.sessionInvalid
        }
        
        // In a real implementation, you would fetch user details from your backend
        // For now, we'll create a mock user
        return User(
            id: authUser.userId,
            username: authUser.username,
            email: authUser.username, // Placeholder
            displayName: authUser.username,
            avatarURL: nil,
            createdAt: Date(),
            stats: User.UserStats(
                totalGamesPlayed: 0,
                totalWins: 0,
                currentStreak: 0,
                longestStreak: 0,
                eloRating: 1000,
                rank: "Seedling",
                plantsIdentified: 0,
                accuracyRate: 0.0
            ),
            currency: User.Currency(coins: 100, gems: 0, tokens: 0)
        )
    }
    
    func refreshSession() async throws {
        _ = try await Amplify.Auth.fetchAuthSession(options: .forceRefresh())
    }
}

enum AuthError: Error, LocalizedError {
    case signInFailed
    case signUpFailed
    case sessionInvalid
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .signInFailed:
            return "Failed to sign in. Please check your credentials."
        case .signUpFailed:
            return "Failed to create account. Please try again."
        case .sessionInvalid:
            return "Your session has expired. Please sign in again."
        case .userNotFound:
            return "User not found."
        }
    }
}

extension DependencyValues {
    var authService: AuthServiceProtocol {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }
}

private enum AuthServiceKey: DependencyKey {
    static let liveValue: AuthServiceProtocol = AuthService()
}
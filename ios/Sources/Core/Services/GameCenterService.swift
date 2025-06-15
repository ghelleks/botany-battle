import Foundation
import GameKit
import Dependencies
import os.log

protocol GameCenterServiceProtocol {
    func authenticatePlayer() async throws -> User
    func signOut() async throws
    func getCurrentUser() async throws -> User
    func isAuthenticated() -> Bool
    func getAuthenticationToken() async throws -> String
}

@available(iOS 14.0, macOS 11.0, *)
final class GameCenterService: GameCenterServiceProtocol {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BotanyBattle", category: "GameCenter")
    
    private var currentUser: User?
    
    func authenticatePlayer() async throws -> User {
        logger.info("Starting Game Center authentication")
        
        // Check if Game Center is available
        guard GKLocalPlayer.local.isAuthenticated || !GKLocalPlayer.local.isUnderage else {
            logger.error("Game Center not available or player underage")
            throw GameCenterError.notSupported
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
                Task { @MainActor in
                    if let error = error {
                        self?.logger.error("Game Center authentication failed: \(error.localizedDescription)")
                        continuation.resume(throwing: GameCenterError.authenticationFailed(error))
                        return
                    }
                    
                    if let viewController = viewController {
                        // In a real app, you would present this view controller
                        // For now, we'll treat this as an authentication failure
                        self?.logger.warning("Game Center requires user interaction")
                        continuation.resume(throwing: GameCenterError.requiresUserInteraction)
                        return
                    }
                    
                    if GKLocalPlayer.local.isAuthenticated {
                        self?.logger.info("Game Center authentication successful")
                        do {
                            let user = try await self?.createUserFromGameCenterPlayer()
                            self?.currentUser = user
                            continuation.resume(returning: user!)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    } else {
                        self?.logger.error("Game Center authentication failed - player not authenticated")
                        continuation.resume(throwing: GameCenterError.notAuthenticated)
                    }
                }
            }
        }
    }
    
    func signOut() async throws {
        logger.info("Signing out from Game Center")
        currentUser = nil
        // Note: Game Center doesn't have a sign out method
        // The user must sign out through device settings
    }
    
    func getCurrentUser() async throws -> User {
        guard isAuthenticated() else {
            throw GameCenterError.notAuthenticated
        }
        
        if let currentUser = currentUser {
            return currentUser
        }
        
        // Recreate user from Game Center player
        let user = try await createUserFromGameCenterPlayer()
        currentUser = user
        return user
    }
    
    func isAuthenticated() -> Bool {
        return GKLocalPlayer.local.isAuthenticated
    }
    
    func getAuthenticationToken() async throws -> String {
        guard isAuthenticated() else {
            throw GameCenterError.notAuthenticated
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            GKLocalPlayer.local.generateIdentityVerificationSignature { publicKeyURL, signature, salt, timestamp, error in
                if let error = error {
                    continuation.resume(throwing: GameCenterError.tokenGenerationFailed(error))
                    return
                }
                
                guard let signature = signature,
                      let salt = salt else {
                    continuation.resume(throwing: GameCenterError.tokenGenerationFailed(NSError(domain: "GameCenter", code: -1)))
                    return
                }
                
                // Create a simple token format that includes the necessary verification data
                let tokenData = [
                    "playerId": GKLocalPlayer.local.gamePlayerID,
                    "signature": signature.base64EncodedString(),
                    "salt": salt.base64EncodedString(),
                    "timestamp": String(timestamp),
                    "bundleId": Bundle.main.bundleIdentifier ?? "",
                    "publicKeyURL": publicKeyURL?.absoluteString ?? ""
                ]
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: tokenData)
                    let token = jsonData.base64EncodedString()
                    continuation.resume(returning: token)
                } catch {
                    continuation.resume(throwing: GameCenterError.tokenGenerationFailed(error))
                }
            }
        }
    }
    
    private func createUserFromGameCenterPlayer() async throws -> User {
        let player = GKLocalPlayer.local
        
        guard player.isAuthenticated else {
            throw GameCenterError.notAuthenticated
        }
        
        // Get display name (use alias directly as loadDisplayName is not available)
        let displayName = player.displayName.isEmpty ? player.alias : player.displayName
        
        // Get profile photo
        let avatarURL: URL? = await withCheckedContinuation { continuation in
            player.loadPhoto(for: .normal) { image, error in
                // In a real implementation, you might upload this image to your server
                // For now, we'll just return nil
                continuation.resume(returning: nil)
            }
        }
        
        return User(
            id: player.gamePlayerID,
            username: player.alias,
            email: nil, // Game Center doesn't provide email
            displayName: displayName,
            avatarURL: avatarURL,
            createdAt: Date(), // We don't have access to the actual creation date
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
}

enum GameCenterError: Error, LocalizedError {
    case notSupported
    case notAuthenticated
    case authenticationFailed(Error)
    case requiresUserInteraction
    case tokenGenerationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Game Center is not supported on this device."
        case .notAuthenticated:
            return "Please sign in to Game Center in Settings."
        case .authenticationFailed(let error):
            return "Game Center authentication failed: \(error.localizedDescription)"
        case .requiresUserInteraction:
            return "Game Center requires user interaction to complete authentication."
        case .tokenGenerationFailed(let error):
            return "Failed to generate authentication token: \(error.localizedDescription)"
        }
    }
}

extension DependencyValues {
    var gameCenterService: GameCenterServiceProtocol {
        get { self[GameCenterServiceKey.self] }
        set { self[GameCenterServiceKey.self] = newValue }
    }
}

private enum GameCenterServiceKey: DependencyKey {
    static let liveValue: GameCenterServiceProtocol = GameCenterService()
}
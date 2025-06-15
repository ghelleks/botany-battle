import Foundation
import GameKit
import Dependencies
import os.log

protocol GameCenterMatchmakingServiceProtocol {
    func findMatch(for difficulty: Game.Difficulty) async throws -> Game
    func inviteFriend(_ playerId: String, difficulty: Game.Difficulty) async throws -> Game
    func acceptInvitation(_ invitation: GameCenterInvitation) async throws -> Game
    func cancelMatchmaking() async throws
}

struct GameCenterInvitation {
    let gameId: String
    let fromPlayer: String
    let difficulty: Game.Difficulty
    let expiresAt: Date
}

@available(iOS 14.0, macOS 11.0, *)
final class GameCenterMatchmakingService: GameCenterMatchmakingServiceProtocol {
    @Dependency(\.gameCenterService) var gameCenterService
    @Dependency(\.networkService) var networkService
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BotanyBattle", category: "GameCenterMatchmaking")
    
    func findMatch(for difficulty: Game.Difficulty) async throws -> Game {
        logger.info("Starting Game Center matchmaking for difficulty: \(difficulty.rawValue)")
        
        // Ensure user is authenticated with Game Center
        guard gameCenterService.isAuthenticated() else {
            throw GameCenterMatchmakingError.notAuthenticated
        }
        
        // Get Game Center authentication token
        let authToken = try await gameCenterService.getAuthenticationToken()
        
        // Send matchmaking request to backend with Game Center credentials
        let request = MatchmakingRequest(
            difficulty: difficulty,
            authToken: authToken,
            playerPreferences: getPlayerPreferences()
        )
        
        let response: MatchmakingResponse = try await networkService.request(
            .game(.findMatch),
            method: .post,
            parameters: request.asDictionary(),
            headers: ["Authorization": "GameCenter \(authToken)"]
        )
        
        if let gameId = response.gameId {
            // Join the matched game
            return try await joinGame(gameId: gameId, authToken: authToken)
        } else {
            // Enter matchmaking queue
            return try await waitForMatch(queueId: response.queueId, authToken: authToken)
        }
    }
    
    func inviteFriend(_ playerId: String, difficulty: Game.Difficulty) async throws -> Game {
        logger.info("Inviting friend to Game Center match: \(playerId)")
        
        guard gameCenterService.isAuthenticated() else {
            throw GameCenterMatchmakingError.notAuthenticated
        }
        
        let authToken = try await gameCenterService.getAuthenticationToken()
        
        let request = DirectInviteRequest(
            targetPlayerId: playerId,
            difficulty: difficulty,
            authToken: authToken
        )
        
        let response: InviteResponse = try await networkService.request(
            .game(.inviteFriend),
            method: .post,
            parameters: request.asDictionary(),
            headers: ["Authorization": "GameCenter \(authToken)"]
        )
        
        return try await joinGame(gameId: response.gameId, authToken: authToken)
    }
    
    func acceptInvitation(_ invitation: GameCenterInvitation) async throws -> Game {
        logger.info("Accepting Game Center invitation: \(invitation.gameId)")
        
        guard gameCenterService.isAuthenticated() else {
            throw GameCenterMatchmakingError.notAuthenticated
        }
        
        let authToken = try await gameCenterService.getAuthenticationToken()
        
        return try await joinGame(gameId: invitation.gameId, authToken: authToken)
    }
    
    func cancelMatchmaking() async throws {
        logger.info("Canceling Game Center matchmaking")
        
        guard gameCenterService.isAuthenticated() else {
            throw GameCenterMatchmakingError.notAuthenticated
        }
        
        let authToken = try await gameCenterService.getAuthenticationToken()
        
        let _: EmptyResponse = try await networkService.request(
            .game(.cancelMatchmaking),
            method: .post,
            parameters: nil,
            headers: ["Authorization": "GameCenter \(authToken)"]
        )
    }
    
    // MARK: - Private Methods
    
    private func getPlayerPreferences() -> PlayerPreferences {
        // Get player's preferred game settings
        return PlayerPreferences(
            allowCrossSkillMatching: true,
            maxWaitTime: 30, // seconds
            preferredRegion: Locale.current.region?.identifier ?? "US"
        )
    }
    
    private func joinGame(gameId: String, authToken: String) async throws -> Game {
        let response: GameResponse = try await networkService.request(
            .game(.join(gameId)),
            method: .post,
            parameters: nil,
            headers: ["Authorization": "GameCenter \(authToken)"]
        )
        
        return response.game
    }
    
    private func waitForMatch(queueId: String, authToken: String) async throws -> Game {
        // Poll for match or use WebSocket connection
        let maxAttempts = 30 // 30 seconds
        
        for attempt in 1...maxAttempts {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            do {
                let response: MatchStatusResponse = try await networkService.request(
                    .game(.matchStatus(queueId)),
                    method: .get,
                    parameters: nil,
                    headers: ["Authorization": "GameCenter \(authToken)"]
                )
                
                if let gameId = response.gameId {
                    return try await joinGame(gameId: gameId, authToken: authToken)
                }
                
                if response.status == "cancelled" {
                    throw GameCenterMatchmakingError.matchmakingCancelled
                }
                
            } catch {
                if attempt == maxAttempts {
                    throw GameCenterMatchmakingError.matchmakingTimeout
                }
                // Continue polling on network errors
            }
        }
        
        throw GameCenterMatchmakingError.matchmakingTimeout
    }
}

// MARK: - Supporting Types

struct MatchmakingRequest {
    let difficulty: Game.Difficulty
    let authToken: String
    let playerPreferences: PlayerPreferences
    
    func asDictionary() -> [String: Any] {
        return [
            "difficulty": difficulty.rawValue,
            "preferences": [
                "allowCrossSkillMatching": playerPreferences.allowCrossSkillMatching,
                "maxWaitTime": playerPreferences.maxWaitTime,
                "preferredRegion": playerPreferences.preferredRegion
            ]
        ]
    }
}

struct DirectInviteRequest {
    let targetPlayerId: String
    let difficulty: Game.Difficulty
    let authToken: String
    
    func asDictionary() -> [String: Any] {
        return [
            "targetPlayerId": targetPlayerId,
            "difficulty": difficulty.rawValue
        ]
    }
}

struct PlayerPreferences {
    let allowCrossSkillMatching: Bool
    let maxWaitTime: Int
    let preferredRegion: String
}

struct MatchmakingResponse: Codable {
    let gameId: String?
    let queueId: String
    let estimatedWaitTime: Int?
    let message: String?
}

struct InviteResponse: Codable {
    let gameId: String
    let expiresAt: String
}

struct MatchStatusResponse: Codable {
    let queueId: String
    let status: String // "waiting", "matched", "cancelled"
    let gameId: String?
    let estimatedWaitTime: Int?
}


enum GameCenterMatchmakingError: Error, LocalizedError {
    case notAuthenticated
    case matchmakingTimeout
    case matchmakingCancelled
    case invalidInvitation
    case playerNotFound
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to Game Center to find matches."
        case .matchmakingTimeout:
            return "Matchmaking timed out. Please try again."
        case .matchmakingCancelled:
            return "Matchmaking was cancelled."
        case .invalidInvitation:
            return "This invitation is no longer valid."
        case .playerNotFound:
            return "The invited player could not be found."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - GameEndpoint Extensions

extension GameEndpoint {
    static let findMatch = GameEndpoint.create // reuse existing endpoint
    static let inviteFriend = GameEndpoint.create // would need new backend endpoint
    static let cancelMatchmaking = GameEndpoint.create // would need new backend endpoint
    static func matchStatus(_ queueId: String) -> GameEndpoint {
        return .status(queueId) // reuse existing status endpoint
    }
}

// MARK: - Dependency

extension DependencyValues {
    var gameCenterMatchmakingService: GameCenterMatchmakingServiceProtocol {
        get { self[GameCenterMatchmakingServiceKey.self] }
        set { self[GameCenterMatchmakingServiceKey.self] = newValue }
    }
}

private enum GameCenterMatchmakingServiceKey: DependencyKey {
    static let liveValue: GameCenterMatchmakingServiceProtocol = GameCenterMatchmakingService()
}
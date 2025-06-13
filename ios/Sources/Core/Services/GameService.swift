import Foundation
import Starscream
import Dependencies

protocol GameServiceProtocol {
    func findGame(difficulty: Game.Difficulty) async throws -> Game
    func joinGame(gameId: String) async throws -> Game
    func leaveGame(gameId: String) async throws
    func submitAnswer(gameId: String, roundId: String, answer: String) async throws
    func getGameHistory() async throws -> [Game]
    func observeGame(gameId: String) -> AsyncStream<GameUpdate>
}

final class GameService: GameServiceProtocol, WebSocketDelegate {
    @Dependency(\.networkService) var networkService
    private var webSocket: WebSocket?
    private var gameUpdateContinuation: AsyncStream<GameUpdate>.Continuation?
    
    func findGame(difficulty: Game.Difficulty) async throws -> Game {
        let parameters = ["difficulty": difficulty.rawValue]
        
        let response: GameResponse = try await networkService.request(
            .game(.create),
            method: .post,
            parameters: parameters,
            headers: nil
        )
        
        return response.game
    }
    
    func joinGame(gameId: String) async throws -> Game {
        let response: GameResponse = try await networkService.request(
            .game(.join(gameId)),
            method: .post,
            parameters: nil,
            headers: nil
        )
        
        return response.game
    }
    
    func leaveGame(gameId: String) async throws {
        let _: EmptyResponse = try await networkService.request(
            .game(.leave(gameId)),
            method: .post,
            parameters: nil,
            headers: nil
        )
    }
    
    func submitAnswer(gameId: String, roundId: String, answer: String) async throws {
        let parameters = ["answer": answer]
        
        let _: EmptyResponse = try await networkService.request(
            .game(.answer(gameId, roundId)),
            method: .post,
            parameters: parameters,
            headers: nil
        )
    }
    
    func getGameHistory() async throws -> [Game] {
        let response: GameHistoryResponse = try await networkService.request(
            .game(.history),
            method: .get,
            parameters: nil,
            headers: nil
        )
        
        return response.games
    }
    
    func observeGame(gameId: String) -> AsyncStream<GameUpdate> {
        return AsyncStream { continuation in
            self.gameUpdateContinuation = continuation
            self.connectToGame(gameId: gameId)
            
            continuation.onTermination = { _ in
                self.disconnectFromGame()
            }
        }
    }
    
    private func connectToGame(gameId: String) {
        guard let url = URL(string: "\(APIConfig.websocketURL)/game/\(gameId)") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        
        webSocket = WebSocket(request: request)
        webSocket?.delegate = self
        webSocket?.connect()
    }
    
    private func disconnectFromGame() {
        webSocket?.disconnect()
        webSocket = nil
        gameUpdateContinuation?.finish()
        gameUpdateContinuation = nil
    }
    
    // MARK: - WebSocketDelegate
    
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(let headers):
            print("WebSocket connected: \(headers)")
            
        case .disconnected(let reason, let code):
            print("WebSocket disconnected: \(reason) with code: \(code)")
            gameUpdateContinuation?.finish()
            
        case .text(let string):
            handleWebSocketMessage(string)
            
        case .binary(let data):
            print("Received binary data: \(data.count)")
            
        case .ping(_):
            break
            
        case .pong(_):
            break
            
        case .viabilityChanged(_):
            break
            
        case .reconnectSuggested(_):
            break
            
        case .cancelled:
            gameUpdateContinuation?.finish()
            
        case .error(let error):
            print("WebSocket error: \(error?.localizedDescription ?? "Unknown error")")
            gameUpdateContinuation?.finish()
        }
    }
    
    private func handleWebSocketMessage(_ message: String) {
        guard let data = message.data(using: .utf8) else { return }
        
        do {
            let update = try JSONDecoder().decode(GameUpdateMessage.self, from: data)
            
            switch update.type {
            case "game_updated":
                if let game = update.game {
                    gameUpdateContinuation?.yield(.gameUpdated(game))
                }
                
            case "round_started":
                if let round = update.round {
                    gameUpdateContinuation?.yield(.roundStarted(round))
                }
                
            case "round_ended":
                if let round = update.round {
                    gameUpdateContinuation?.yield(.roundEnded(round))
                }
                
            case "game_ended":
                if let game = update.game {
                    gameUpdateContinuation?.yield(.gameEnded(game))
                }
                
            default:
                print("Unknown message type: \(update.type)")
            }
        } catch {
            print("Failed to decode WebSocket message: \(error)")
        }
    }
}

enum GameUpdate {
    case gameUpdated(Game)
    case roundStarted(Round)
    case roundEnded(Round)
    case gameEnded(Game)
}

struct GameResponse: Codable {
    let game: Game
}

struct GameHistoryResponse: Codable {
    let games: [Game]
}

struct EmptyResponse: Codable {}

struct GameUpdateMessage: Codable {
    let type: String
    let game: Game?
    let round: Round?
}

extension DependencyValues {
    var gameService: GameServiceProtocol {
        get { self[GameServiceKey.self] }
        set { self[GameServiceKey.self] = newValue }
    }
}

private enum GameServiceKey: DependencyKey {
    static let liveValue: GameServiceProtocol = GameService()
}
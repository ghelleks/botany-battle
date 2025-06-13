import Foundation
import ComposableArchitecture

@Reducer
struct GameFeature {
    @ObservableState
    struct State: Equatable {
        var currentGame: Game?
        var currentRound: Round?
        var isSearchingForGame = false
        var gameHistory: [Game] = []
        var selectedDifficulty: Game.Difficulty = .medium
        var error: String?
        var timeRemaining: TimeInterval = 0
        var selectedAnswer: String?
        var hasAnswered = false
        
        var canAnswer: Bool {
            guard let round = currentRound else { return false }
            return round.isActive && !hasAnswered
        }
        
        var gameProgress: Double {
            guard let game = currentGame else { return 0.0 }
            return Double(game.currentRound) / Double(game.totalRounds)
        }
    }
    
    enum Action {
        case searchForGame(Game.Difficulty)
        case joinGame(String)
        case leaveGame
        case submitAnswer(String)
        case gameFound(Game)
        case gameUpdated(Game)
        case roundStarted(Round)
        case roundEnded(Round)
        case gameEnded(Game)
        case timerTick
        case gameError(String)
        case clearError
        case loadGameHistory
        case gameHistoryLoaded([Game])
    }
    
    @Dependency(\.gameService) var gameService
    @Dependency(\.continuousClock) var clock
    
    enum CancelID { case timer }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .searchForGame(let difficulty):
                state.isSearchingForGame = true
                state.selectedDifficulty = difficulty
                state.error = nil
                return .run { send in
                    do {
                        let game = try await gameService.findGame(difficulty: difficulty)
                        await send(.gameFound(game))
                    } catch {
                        await send(.gameError(error.localizedDescription))
                    }
                }
                
            case .joinGame(let gameId):
                return .run { send in
                    do {
                        let game = try await gameService.joinGame(gameId: gameId)
                        await send(.gameFound(game))
                    } catch {
                        await send(.gameError(error.localizedDescription))
                    }
                }
                
            case .leaveGame:
                state.currentGame = nil
                state.currentRound = nil
                state.isSearchingForGame = false
                state.hasAnswered = false
                state.selectedAnswer = nil
                return .cancel(id: CancelID.timer)
                
            case .submitAnswer(let answer):
                guard let game = state.currentGame,
                      let round = state.currentRound,
                      state.canAnswer else { return .none }
                
                state.selectedAnswer = answer
                state.hasAnswered = true
                
                return .run { send in
                    do {
                        try await gameService.submitAnswer(
                            gameId: game.id,
                            roundId: round.id,
                            answer: answer
                        )
                    } catch {
                        await send(.gameError(error.localizedDescription))
                    }
                }
                
            case .gameFound(let game):
                state.isSearchingForGame = false
                state.currentGame = game
                return .run { send in
                    for await update in gameService.observeGame(gameId: game.id) {
                        switch update {
                        case .gameUpdated(let updatedGame):
                            await send(.gameUpdated(updatedGame))
                        case .roundStarted(let round):
                            await send(.roundStarted(round))
                        case .roundEnded(let round):
                            await send(.roundEnded(round))
                        case .gameEnded(let endedGame):
                            await send(.gameEnded(endedGame))
                        }
                    }
                }
                
            case .gameUpdated(let game):
                state.currentGame = game
                return .none
                
            case .roundStarted(let round):
                state.currentRound = round
                state.hasAnswered = false
                state.selectedAnswer = nil
                state.timeRemaining = round.timeLimit
                
                return .run { send in
                    for await _ in clock.timer(interval: .seconds(1)) {
                        await send(.timerTick)
                    }
                } cancellableId: CancelID.timer
                
            case .roundEnded(let round):
                state.currentRound = round
                return .cancel(id: CancelID.timer)
                
            case .gameEnded(let game):
                state.currentGame = game
                state.currentRound = nil
                return .concatenate(
                    .cancel(id: CancelID.timer),
                    .send(.loadGameHistory)
                )
                
            case .timerTick:
                guard let round = state.currentRound else {
                    return .cancel(id: CancelID.timer)
                }
                
                let newTimeRemaining = round.timeRemaining
                state.timeRemaining = newTimeRemaining
                
                if newTimeRemaining <= 0 {
                    return .cancel(id: CancelID.timer)
                }
                
                return .none
                
            case .gameError(let error):
                state.isSearchingForGame = false
                state.error = error
                return .none
                
            case .clearError:
                state.error = nil
                return .none
                
            case .loadGameHistory:
                return .run { send in
                    do {
                        let history = try await gameService.getGameHistory()
                        await send(.gameHistoryLoaded(history))
                    } catch {
                        await send(.gameError(error.localizedDescription))
                    }
                }
                
            case .gameHistoryLoaded(let history):
                state.gameHistory = history
                return .none
            }
        }
    }
}
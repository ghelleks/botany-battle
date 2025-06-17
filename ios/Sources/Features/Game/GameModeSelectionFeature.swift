import Foundation
import ComposableArchitecture

@Reducer
struct GameModeSelectionFeature {
    @ObservableState
    struct State: Equatable {
        var selectedMode: GameMode = .beatTheClock
        var selectedDifficulty: Game.Difficulty = .medium
        var showDifficultySelection = false
        var personalBests: [PersonalBest] = []
        var gameHistory: [GameHistoryItem] = []
        var beatTheClockBests: [Game.Difficulty: BeatTheClockScore] = [:]
        var speedrunBests: [Game.Difficulty: SpeedrunScore] = [:]
        var error: String?
        var isLoading = false
        
        // Computed properties
        var personalBestForSelectedMode: PersonalBest? {
            personalBests.first { $0.gameMode == selectedMode && $0.difficulty == selectedDifficulty }
        }
        
        var recentGamesForSelectedMode: [GameHistoryItem] {
            gameHistory.filter { $0.gameMode == selectedMode }.prefix(3).map { $0 }
        }
        
        var canStartGame: Bool {
            return !isLoading
        }
    }
    
    enum Action {
        case onAppear
        case selectMode(GameMode)
        case selectDifficulty(Game.Difficulty)
        case showDifficultySelection(Bool)
        case startGame
        case loadPersonalBests
        case personalBestsLoaded([PersonalBest])
        case loadGameHistory
        case gameHistoryLoaded([GameHistoryItem])
        case loadBeatTheClockBests
        case beatTheClockBestsLoaded([Game.Difficulty: BeatTheClockScore])
        case loadSpeedrunBests
        case speedrunBestsLoaded([Game.Difficulty: SpeedrunScore])
        case clearError
        case error(String)
        
        // Delegate actions to parent
        case delegate(Delegate)
        
        enum Delegate {
            case startMultiplayerGame(Game.Difficulty)
            case startBeatTheClockGame(Game.Difficulty)
            case startSpeedrunGame(Game.Difficulty)
        }
    }
    
    @Dependency(\.persistenceService) var persistenceService
    @Dependency(\.beatTheClockService) var beatTheClockService
    @Dependency(\.speedrunService) var speedrunService
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .concatenate(
                    .send(.loadPersonalBests),
                    .send(.loadGameHistory),
                    .send(.loadBeatTheClockBests),
                    .send(.loadSpeedrunBests)
                )
                
            case .selectMode(let mode):
                state.selectedMode = mode
                state.showDifficultySelection = mode != .multiplayer
                // Clear any errors when changing modes
                state.error = nil
                return .none
                
            case .selectDifficulty(let difficulty):
                state.selectedDifficulty = difficulty
                return .none
                
            case .showDifficultySelection(let show):
                state.showDifficultySelection = show
                return .none
                
            case .startGame:
                guard state.canStartGame else { return .none }
                
                state.isLoading = true
                state.error = nil
                
                switch state.selectedMode {
                case .multiplayer:
                    // Multiplayer requires authentication - delegate will handle this
                    return .send(.delegate(.startMultiplayerGame(state.selectedDifficulty)))
                case .beatTheClock:
                    return .send(.delegate(.startBeatTheClockGame(state.selectedDifficulty)))
                case .speedrun:
                    return .send(.delegate(.startSpeedrunGame(state.selectedDifficulty)))
                }
                
            case .loadPersonalBests:
                return .run { send in
                    let personalBests = persistenceService.getAllPersonalBests()
                    await send(.personalBestsLoaded(personalBests))
                }
                
            case .personalBestsLoaded(let personalBests):
                state.personalBests = personalBests
                return .none
                
            case .loadGameHistory:
                return .run { send in
                    let gameHistory = persistenceService.getGameHistory(limit: 10)
                    await send(.gameHistoryLoaded(gameHistory))
                }
                
            case .gameHistoryLoaded(let gameHistory):
                state.gameHistory = gameHistory
                return .none
                
            case .loadBeatTheClockBests:
                return .run { send in
                    var bests: [Game.Difficulty: BeatTheClockScore] = [:]
                    for difficulty in Game.Difficulty.allCases {
                        if let best = beatTheClockService.getBestScore(for: difficulty) {
                            bests[difficulty] = best
                        }
                    }
                    await send(.beatTheClockBestsLoaded(bests))
                }
                
            case .beatTheClockBestsLoaded(let bests):
                state.beatTheClockBests = bests
                return .none
                
            case .loadSpeedrunBests:
                return .run { send in
                    var bests: [Game.Difficulty: SpeedrunScore] = [:]
                    for difficulty in Game.Difficulty.allCases {
                        if let best = speedrunService.getBestScore(for: difficulty) {
                            bests[difficulty] = best
                        }
                    }
                    await send(.speedrunBestsLoaded(bests))
                }
                
            case .speedrunBestsLoaded(let bests):
                state.speedrunBests = bests
                return .none
                
            case .clearError:
                state.error = nil
                return .none
                
            case .error(let error):
                state.error = error
                state.isLoading = false
                return .none
                
            case .delegate:
                state.isLoading = false
                return .none
            }
        }
    }
}
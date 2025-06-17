import Foundation
import ComposableArchitecture

@Reducer
struct GameFeature {
    @ObservableState
    struct State: Equatable {
        // Common state for all game modes
        var selectedGameMode: GameMode = .multiplayer
        var selectedDifficulty: Game.Difficulty = .medium
        var error: String?
        var gameHistory: [Game] = []
        
        // Multiplayer specific state
        var currentGame: Game?
        var currentRound: Round?
        var isSearchingForGame = false
        var selectedAnswer: String?
        var hasAnswered = false
        
        // Single-user specific state
        var singleUserSession: SingleUserGameSession?
        var currentQuestion: (plant: Plant, options: [String])?
        var gameTimeRemaining: TimeInterval = 0
        var totalGameTime: TimeInterval = 0
        var personalBests: [PersonalBest] = []
        var newPersonalBest: PersonalBest?
        var isPaused = false
        
        // Beat the Clock specific state
        var beatTheClockScore: BeatTheClockScore?
        var beatTheClockPersonalBest: BeatTheClockScore?
        var beatTheClockLeaderboard: [BeatTheClockScore] = []
        
        // Speedrun specific state
        var speedrunScore: SpeedrunScore?
        var speedrunPersonalBest: SpeedrunScore?
        var speedrunLeaderboard: [SpeedrunScore] = []
        
        // Computed properties that work for both modes
        var currentMode: GameMode {
            return singleUserSession?.mode ?? currentGame?.mode ?? selectedGameMode
        }
        
        var canAnswer: Bool {
            switch currentMode {
            case .multiplayer:
                guard let round = currentRound else { return false }
                return round.isActive && !hasAnswered
            case .beatTheClock, .speedrun:
                guard let session = singleUserSession else { return false }
                return session.state == .active && currentQuestion != nil && !isPaused
            }
        }
        
        var gameProgress: Double {
            switch currentMode {
            case .multiplayer:
                guard let game = currentGame else { return 0.0 }
                return Double(game.currentRound) / Double(game.totalRounds)
            case .beatTheClock:
                guard let session = singleUserSession else { return 0.0 }
                return min(session.totalGameTime / 60.0, 1.0) // Progress based on time
            case .speedrun:
                guard let session = singleUserSession else { return 0.0 }
                return Double(session.questionsAnswered) / 25.0 // Progress based on questions
            }
        }
        
        var currentScore: Int {
            switch currentMode {
            case .multiplayer:
                return currentGame?.players.first?.score ?? 0
            case .beatTheClock, .speedrun:
                return singleUserSession?.score ?? 0
            }
        }
        
        var questionsAnswered: Int {
            switch currentMode {
            case .multiplayer:
                return currentGame?.currentRound ?? 0
            case .beatTheClock, .speedrun:
                return singleUserSession?.questionsAnswered ?? 0
            }
        }
        
        var isGameActive: Bool {
            switch currentMode {
            case .multiplayer:
                return currentGame?.state == .inProgress
            case .beatTheClock, .speedrun:
                return singleUserSession?.state == .active
            }
        }
        
        var timeRemaining: TimeInterval {
            switch currentMode {
            case .multiplayer:
                return currentRound?.timeRemaining ?? 0
            case .beatTheClock:
                return max(0, 60.0 - (singleUserSession?.totalGameTime ?? 0))
            case .speedrun:
                return totalGameTime // Show elapsed time for speedrun
            }
        }
    }
    
    enum Action {
        // Mode selection
        case selectGameMode(GameMode)
        case selectDifficulty(Game.Difficulty)
        
        // Multiplayer actions
        case searchForMultiplayerGame(Game.Difficulty)
        case joinGame(String)
        case gameFound(Game)
        case gameUpdated(Game)
        case roundStarted(Round)
        case roundEnded(Round)
        case gameEnded(Game)
        
        // Single-user actions
        case startSingleUserGame(GameMode, Game.Difficulty)
        case singleUserGameStarted(SingleUserGameSession)
        case loadNextQuestion
        case questionLoaded(Plant, [String])
        case pauseGame
        case resumeGame
        case singleUserGameCompleted(PersonalBest?)
        
        // Beat the Clock specific actions
        case beatTheClockGameCompleted(BeatTheClockScore)
        case loadBeatTheClockPersonalBest(Game.Difficulty)
        case beatTheClockPersonalBestLoaded(BeatTheClockScore?)
        case loadBeatTheClockLeaderboard(Game.Difficulty)
        case beatTheClockLeaderboardLoaded([BeatTheClockScore])
        
        // Speedrun specific actions
        case speedrunGameCompleted(SpeedrunScore)
        case loadSpeedrunPersonalBest(Game.Difficulty)
        case speedrunPersonalBestLoaded(SpeedrunScore?)
        case loadSpeedrunLeaderboard(Game.Difficulty)
        case speedrunLeaderboardLoaded([SpeedrunScore])
        
        // Common actions
        case submitAnswer(String)
        case leaveGame
        case timerTick
        case timerUpdate(GameTimerUpdate)
        case gameError(String)
        case clearError
        case loadGameHistory
        case gameHistoryLoaded([Game])
        case loadPersonalBests
        case personalBestsLoaded([PersonalBest])
    }
    
    @Dependency(\.gameService) var gameService
    @Dependency(\.singleUserGameService) var singleUserGameService
    @Dependency(\.personalBestService) var personalBestService
    @Dependency(\.gameTimerService) var gameTimerService
    @Dependency(\.gameTimerValidationService) var gameTimerValidationService
    @Dependency(\.gameTimerPersistenceService) var gameTimerPersistenceService
    @Dependency(\.beatTheClockService) var beatTheClockService
    @Dependency(\.speedrunService) var speedrunService
    @Dependency(\.continuousClock) var clock
    
    enum CancelID { 
        case multiplayerTimer
        case singleUserTimer
        case gameTimer
        case gameObserver
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // MARK: - Mode Selection
            case .selectGameMode(let mode):
                state.selectedGameMode = mode
                return .none
                
            case .selectDifficulty(let difficulty):
                state.selectedDifficulty = difficulty
                return .none
                
            // MARK: - Multiplayer Actions
            case .searchForMultiplayerGame(let difficulty):
                state.isSearchingForGame = true
                state.selectedDifficulty = difficulty
                state.selectedGameMode = .multiplayer
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
                } cancellableId: CancelID.gameObserver
                
            case .gameUpdated(let game):
                state.currentGame = game
                return .none
                
            case .roundStarted(let round):
                state.currentRound = round
                state.hasAnswered = false
                state.selectedAnswer = nil
                
                return .run { send in
                    for await _ in clock.timer(interval: .seconds(1)) {
                        await send(.timerTick)
                    }
                } cancellableId: CancelID.multiplayerTimer
                
            case .roundEnded(let round):
                state.currentRound = round
                return .cancel(id: CancelID.multiplayerTimer)
                
            case .gameEnded(let game):
                state.currentGame = game
                state.currentRound = nil
                return .concatenate(
                    .cancel(id: CancelID.multiplayerTimer),
                    .cancel(id: CancelID.gameObserver),
                    .send(.loadGameHistory)
                )
                
            // MARK: - Single-User Actions
            case .startSingleUserGame(let mode, let difficulty):
                state.selectedGameMode = mode
                state.selectedDifficulty = difficulty
                state.error = nil
                state.newPersonalBest = nil
                
                let session = singleUserGameService.startGame(mode: mode, difficulty: difficulty)
                state.singleUserSession = session
                state.totalGameTime = 0
                state.isPaused = false
                
                return .concatenate(
                    .send(.singleUserGameStarted(session)),
                    .send(.loadNextQuestion)
                )
                
            case .singleUserGameStarted(let session):
                state.singleUserSession = session
                
                // Start the game timer using GameTimerService
                return .run { send in
                    for await update in gameTimerService.startTimer(mode: session.mode, startTime: session.startedAt) {
                        await send(.timerUpdate(update))
                    }
                } cancellableId: CancelID.gameTimer
                
            case .loadNextQuestion:
                guard let session = state.singleUserSession else { return .none }
                
                return .run { send in
                    do {
                        let (plant, options) = try await singleUserGameService.getCurrentQuestion(for: session)
                        await send(.questionLoaded(plant, options))
                    } catch {
                        await send(.gameError(error.localizedDescription))
                    }
                }
                
            case .questionLoaded(let plant, let options):
                state.currentQuestion = (plant: plant, options: options)
                return .none
                
            case .pauseGame:
                guard var session = state.singleUserSession else { return .none }
                singleUserGameService.pauseGame(session: &session)
                state.singleUserSession = session
                state.isPaused = true
                gameTimerService.pauseTimer()
                return .none
                
            case .resumeGame:
                guard var session = state.singleUserSession else { return .none }
                singleUserGameService.resumeGame(session: &session)
                state.singleUserSession = session
                state.isPaused = false
                gameTimerService.resumeTimer()
                return .none
                
            case .singleUserGameCompleted(let personalBest):
                state.newPersonalBest = personalBest
                state.singleUserSession = nil
                state.currentQuestion = nil
                state.isPaused = false
                gameTimerService.stopTimer()
                
                return .concatenate(
                    .cancel(id: CancelID.gameTimer),
                    .send(.loadPersonalBests),
                    .send(.loadGameHistory)
                )
                
            // MARK: - Common Actions
            case .submitAnswer(let answer):
                switch state.currentMode {
                case .multiplayer:
                    return handleMultiplayerAnswerSubmission(state: &state, answer: answer)
                case .beatTheClock, .speedrun:
                    return handleSingleUserAnswerSubmission(state: &state, answer: answer)
                }
                
            case .leaveGame:
                state.currentGame = nil
                state.currentRound = nil
                state.singleUserSession = nil
                state.currentQuestion = nil
                state.isSearchingForGame = false
                state.hasAnswered = false
                state.selectedAnswer = nil
                state.isPaused = false
                state.newPersonalBest = nil
                gameTimerService.stopTimer()
                
                return .concatenate(
                    .cancel(id: CancelID.multiplayerTimer),
                    .cancel(id: CancelID.gameTimer),
                    .cancel(id: CancelID.gameObserver)
                )
                
            case .timerTick:
                switch state.currentMode {
                case .multiplayer:
                    return handleMultiplayerTimerTick(state: &state)
                case .beatTheClock, .speedrun:
                    return handleSingleUserTimerTick(state: &state)
                }
                
            case .timerUpdate(let update):
                guard let session = state.singleUserSession else { return .none }
                
                // Validate timer update
                let validation = gameTimerValidationService.validateTimerState(session: session, timerUpdate: update)
                
                // Use adjusted time if validation suggests it
                let finalTime = validation.adjustedTime ?? update.totalTime
                
                state.totalGameTime = finalTime
                state.gameTimeRemaining = update.timeRemaining ?? finalTime
                
                // Update session with current timing
                var updatedSession = session
                updatedSession.totalPausedTime = update.pausedTime
                state.singleUserSession = updatedSession
                
                // Save timer state for recovery
                let persistenceState = TimerPersistenceState(
                    sessionId: session.id,
                    mode: session.mode,
                    startTime: session.startedAt,
                    totalPausedTime: update.pausedTime,
                    wasActive: session.state == .active,
                    lastSaveTime: Date(),
                    questionsAnswered: session.questionsAnswered,
                    correctAnswers: session.correctAnswers
                )
                gameTimerPersistenceService.saveTimerState(persistenceState)
                
                // Check if time expired for Beat the Clock
                if update.isExpired && session.mode == .beatTheClock {
                    return .run { send in
                        let beatTheClockScore = beatTheClockService.calculateScore(session: updatedSession)
                        await send(.beatTheClockGameCompleted(beatTheClockScore))
                    }
                }
                
                // Log warnings if validation found issues
                if !validation.isValid {
                    print("Timer validation warnings: \(validation.warnings)")
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
                
            case .loadPersonalBests:
                return .run { send in
                    let personalBests = personalBestService.getAllPersonalBests()
                    await send(.personalBestsLoaded(personalBests))
                }
                
            case .personalBestsLoaded(let personalBests):
                state.personalBests = personalBests
                return .none
                
            // MARK: - Beat the Clock Actions
            case .beatTheClockGameCompleted(let score):
                state.beatTheClockScore = score
                state.singleUserSession = nil
                state.currentQuestion = nil
                state.isPaused = false
                gameTimerService.stopTimer()
                
                // Save the score
                if let service = beatTheClockService as? BeatTheClockService {
                    service.saveScore(score)
                }
                
                return .concatenate(
                    .cancel(id: CancelID.gameTimer),
                    .send(.loadBeatTheClockPersonalBest(score.difficulty)),
                    .send(.loadBeatTheClockLeaderboard(score.difficulty))
                )
                
            case .loadBeatTheClockPersonalBest(let difficulty):
                return .run { send in
                    let personalBest = beatTheClockService.getBestScore(for: difficulty)
                    await send(.beatTheClockPersonalBestLoaded(personalBest))
                }
                
            case .beatTheClockPersonalBestLoaded(let personalBest):
                state.beatTheClockPersonalBest = personalBest
                return .none
                
            case .loadBeatTheClockLeaderboard(let difficulty):
                return .run { send in
                    let leaderboard = beatTheClockService.getLeaderboard(for: difficulty)
                    await send(.beatTheClockLeaderboardLoaded(leaderboard))
                }
                
            case .beatTheClockLeaderboardLoaded(let leaderboard):
                state.beatTheClockLeaderboard = leaderboard
                return .none
                
            // MARK: - Speedrun Actions
            case .speedrunGameCompleted(let score):
                state.speedrunScore = score
                state.singleUserSession = nil
                state.currentQuestion = nil
                state.isPaused = false
                gameTimerService.stopTimer()
                
                // Save the score
                if let service = speedrunService as? SpeedrunService {
                    service.saveScore(score)
                }
                
                return .concatenate(
                    .cancel(id: CancelID.gameTimer),
                    .send(.loadSpeedrunPersonalBest(score.difficulty)),
                    .send(.loadSpeedrunLeaderboard(score.difficulty))
                )
                
            case .loadSpeedrunPersonalBest(let difficulty):
                return .run { send in
                    let personalBest = speedrunService.getBestScore(for: difficulty)
                    await send(.speedrunPersonalBestLoaded(personalBest))
                }
                
            case .speedrunPersonalBestLoaded(let personalBest):
                state.speedrunPersonalBest = personalBest
                return .none
                
            case .loadSpeedrunLeaderboard(let difficulty):
                return .run { send in
                    let leaderboard = speedrunService.getLeaderboard(for: difficulty)
                    await send(.speedrunLeaderboardLoaded(leaderboard))
                }
                
            case .speedrunLeaderboardLoaded(let leaderboard):
                state.speedrunLeaderboard = leaderboard
                return .none
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleMultiplayerAnswerSubmission(state: inout State, answer: String) -> Effect<Action> {
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
    }
    
    private func handleSingleUserAnswerSubmission(state: inout State, answer: String) -> Effect<Action> {
        guard var session = state.singleUserSession,
              let question = state.currentQuestion,
              state.canAnswer else { return .none }
        
        let correctAnswer = question.plant.primaryCommonName
        let answerResult = singleUserGameService.submitAnswer(
            session: &session,
            selectedAnswer: answer,
            correctAnswer: correctAnswer,
            plantId: question.plant.id
        )
        
        state.singleUserSession = session
        state.selectedAnswer = answer
        
        // Check if game is complete
        if session.isComplete {
            return .run { send in
                var completedSession = session
                
                // Handle mode-specific completion
                switch completedSession.mode {
                case .beatTheClock:
                    let beatTheClockScore = beatTheClockService.calculateScore(session: completedSession)
                    await send(.beatTheClockGameCompleted(beatTheClockScore))
                case .speedrun:
                    let speedrunScore = speedrunService.calculateScore(session: completedSession)
                    await send(.speedrunGameCompleted(speedrunScore))
                case .multiplayer:
                    let personalBest = singleUserGameService.completeGame(session: &completedSession)
                    await send(.singleUserGameCompleted(personalBest))
                }
            }
        } else {
            // Load next question after a brief delay
            return .run { send in
                try await clock.sleep(for: .seconds(1.5)) // Show result briefly
                await send(.loadNextQuestion)
            }
        }
    }
    
    private func handleMultiplayerTimerTick(state: inout State) -> Effect<Action> {
        guard let round = state.currentRound else {
            return .cancel(id: CancelID.multiplayerTimer)
        }
        
        let newTimeRemaining = round.timeRemaining
        
        if newTimeRemaining <= 0 {
            return .cancel(id: CancelID.multiplayerTimer)
        }
        
        return .none
    }
    
    private func handleSingleUserTimerTick(state: inout State) -> Effect<Action> {
        guard let session = state.singleUserSession,
              session.state == .active else {
            return .cancel(id: CancelID.singleUserTimer)
        }
        
        state.totalGameTime = session.totalGameTime
        state.gameTimeRemaining = state.timeRemaining
        
        // Check for game completion conditions
        switch session.mode {
        case .beatTheClock:
            if session.isTimeExpired {
                return .run { send in
                    let beatTheClockScore = beatTheClockService.calculateScore(session: session)
                    await send(.beatTheClockGameCompleted(beatTheClockScore))
                }
            }
        case .speedrun:
            if session.questionsAnswered >= 25 {
                return .run { send in
                    let speedrunScore = speedrunService.calculateScore(session: session)
                    await send(.speedrunGameCompleted(speedrunScore))
                }
            }
        case .multiplayer:
            break
        }
        
        return .none
    }
}
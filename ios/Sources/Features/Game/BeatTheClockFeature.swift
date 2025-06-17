import Foundation
import ComposableArchitecture

@Reducer
struct BeatTheClockFeature {
    @ObservableState
    struct State: Equatable {
        var difficulty: Game.Difficulty = .medium
        var session: SingleUserGameSession?
        var currentQuestion: (plant: Plant, options: [String])?
        var selectedAnswer: String?
        var hasAnswered = false
        var timeRemaining: TimeInterval = 60.0
        var totalTime: TimeInterval = 0.0
        var isPaused = false
        var score: BeatTheClockScore?
        var personalBest: BeatTheClockScore?
        var leaderboard: [BeatTheClockScore] = []
        var error: String?
        var isGameActive = false
        var showResults = false
        var answerFeedback: AnswerFeedback?
        
        // Computed properties
        var correctAnswers: Int {
            session?.correctAnswers ?? 0
        }
        
        var totalAnswers: Int {
            session?.questionsAnswered ?? 0
        }
        
        var accuracy: Double {
            session?.accuracy ?? 0.0
        }
        
        var questionsPerSecond: Double {
            guard totalTime > 0 else { return 0 }
            return Double(totalAnswers) / totalTime
        }
        
        var canAnswer: Bool {
            guard let session = session else { return false }
            return isGameActive && !isPaused && !hasAnswered && 
                   currentQuestion != nil && timeRemaining > 0 && 
                   session.state == .active
        }
        
        var progressPercentage: Double {
            return max(0, min(1.0, (60.0 - timeRemaining) / 60.0))
        }
    }
    
    enum Action {
        case startGame(Game.Difficulty)
        case pauseGame
        case resumeGame
        case stopGame
        case loadNextQuestion
        case questionLoaded(Plant, [String])
        case submitAnswer(String)
        case answerSubmitted(Bool) // isCorrect
        case timerUpdate(TimeInterval, TimeInterval) // timeRemaining, totalTime
        case gameCompleted(BeatTheClockScore)
        case loadPersonalBest
        case personalBestLoaded(BeatTheClockScore?)
        case loadLeaderboard
        case leaderboardLoaded([BeatTheClockScore])
        case showResults
        case hideResults
        case clearError
        case gameError(String)
    }
    
    struct AnswerFeedback: Equatable {
        let isCorrect: Bool
        let correctAnswer: String
        let selectedAnswer: String
        let showTime: Date
        
        var shouldHide: Bool {
            Date().timeIntervalSince(showTime) > 1.5
        }
    }
    
    @Dependency(\.beatTheClockService) var beatTheClockService
    @Dependency(\.singleUserGameService) var singleUserGameService
    @Dependency(\.gameTimerService) var gameTimerService
    @Dependency(\.continuousClock) var clock
    
    enum CancelID {
        case gameTimer
        case answerFeedback
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startGame(let difficulty):
                state.difficulty = difficulty
                state.error = nil
                state.showResults = false
                state.answerFeedback = nil
                
                let session = beatTheClockService.startBeatTheClockGame(difficulty: difficulty)
                state.session = session
                state.timeRemaining = 60.0
                state.totalTime = 0.0
                state.isPaused = false
                state.isGameActive = true
                state.hasAnswered = false
                state.selectedAnswer = nil
                
                return .concatenate(
                    .send(.loadPersonalBest),
                    .send(.loadNextQuestion),
                    startGameTimer()
                )
                
            case .pauseGame:
                guard state.isGameActive, !state.isPaused else { return .none }
                state.isPaused = true
                gameTimerService.pauseTimer()
                return .none
                
            case .resumeGame:
                guard state.isGameActive, state.isPaused else { return .none }
                state.isPaused = false
                gameTimerService.resumeTimer()
                return .none
                
            case .stopGame:
                state.isGameActive = false
                state.isPaused = false
                state.session = nil
                state.currentQuestion = nil
                state.selectedAnswer = nil
                state.hasAnswered = false
                state.answerFeedback = nil
                gameTimerService.stopTimer()
                
                return .concatenate(
                    .cancel(id: CancelID.gameTimer),
                    .cancel(id: CancelID.answerFeedback)
                )
                
            case .loadNextQuestion:
                guard let session = state.session,
                      state.isGameActive,
                      state.timeRemaining > 0 else { return .none }
                
                state.hasAnswered = false
                state.selectedAnswer = nil
                state.answerFeedback = nil
                
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
                
            case .submitAnswer(let answer):
                guard var session = state.session,
                      let question = state.currentQuestion,
                      state.canAnswer else { return .none }
                
                state.selectedAnswer = answer
                state.hasAnswered = true
                
                let correctAnswer = question.plant.primaryCommonName
                let isCorrect = answer == correctAnswer
                
                // Submit answer to session
                let answerResult = singleUserGameService.submitAnswer(
                    session: &session,
                    selectedAnswer: answer,
                    correctAnswer: correctAnswer,
                    plantId: question.plant.id
                )
                
                state.session = session
                
                // Show answer feedback
                state.answerFeedback = AnswerFeedback(
                    isCorrect: isCorrect,
                    correctAnswer: correctAnswer,
                    selectedAnswer: answer,
                    showTime: Date()
                )
                
                return .concatenate(
                    .send(.answerSubmitted(isCorrect)),
                    // Hide feedback and load next question after delay
                    .run { send in
                        try await clock.sleep(for: .seconds(1.5))
                        await send(.loadNextQuestion)
                    } cancellableId: CancelID.answerFeedback
                )
                
            case .answerSubmitted(let isCorrect):
                // This action can be used for haptic feedback, sound effects, etc.
                return .none
                
            case .timerUpdate(let timeRemaining, let totalTime):
                state.timeRemaining = timeRemaining
                state.totalTime = totalTime
                
                // Check if time is up
                if timeRemaining <= 0 && state.isGameActive {
                    return .send(.gameCompleted(calculateFinalScore(state)))
                }
                
                return .none
                
            case .gameCompleted(let score):
                state.isGameActive = false
                state.score = score
                state.showResults = true
                gameTimerService.stopTimer()
                
                // Save score and update personal best
                if let service = beatTheClockService as? BeatTheClockService {
                    service.saveScore(score)
                }
                
                return .concatenate(
                    .cancel(id: CancelID.gameTimer),
                    .cancel(id: CancelID.answerFeedback),
                    .send(.loadPersonalBest),
                    .send(.loadLeaderboard)
                )
                
            case .loadPersonalBest:
                let personalBest = beatTheClockService.getBestScore(for: state.difficulty)
                return .send(.personalBestLoaded(personalBest))
                
            case .personalBestLoaded(let personalBest):
                state.personalBest = personalBest
                return .none
                
            case .loadLeaderboard:
                let leaderboard = beatTheClockService.getLeaderboard(for: state.difficulty)
                return .send(.leaderboardLoaded(leaderboard))
                
            case .leaderboardLoaded(let leaderboard):
                state.leaderboard = leaderboard
                return .none
                
            case .showResults:
                state.showResults = true
                return .none
                
            case .hideResults:
                state.showResults = false
                return .none
                
            case .clearError:
                state.error = nil
                return .none
                
            case .gameError(let error):
                state.error = error
                state.isGameActive = false
                return .none
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func startGameTimer() -> Effect<Action> {
        return .run { send in
            for await update in gameTimerService.startTimer(mode: .beatTheClock, startTime: Date()) {
                let timeRemaining = update.timeRemaining ?? 0
                await send(.timerUpdate(timeRemaining, update.totalTime))
                
                if update.isExpired {
                    break
                }
            }
        } cancellableId: CancelID.gameTimer
    }
    
    private func calculateFinalScore(_ state: State) -> BeatTheClockScore {
        guard let session = state.session else {
            return BeatTheClockScore(
                id: UUID().uuidString,
                difficulty: state.difficulty,
                correctAnswers: 0,
                totalAnswers: 0,
                timeUsed: 60.0,
                accuracy: 0.0,
                pointsPerSecond: 0.0,
                achievedAt: Date(),
                isNewRecord: false
            )
        }
        
        return beatTheClockService.calculateScore(session: session)
    }
}

// MARK: - Extensions

extension BeatTheClockFeature.State {
    var timeRemainingText: String {
        let seconds = Int(ceil(timeRemaining))
        return "\(seconds)s"
    }
    
    var accuracyText: String {
        return String(format: "%.1f%%", accuracy * 100)
    }
    
    var scoreText: String {
        return "\(correctAnswers)/\(totalAnswers)"
    }
}
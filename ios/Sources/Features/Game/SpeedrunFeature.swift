import Foundation
import ComposableArchitecture

@Reducer
struct SpeedrunFeature {
    @ObservableState
    struct State: Equatable {
        var difficulty: Game.Difficulty = .medium
        var session: SingleUserGameSession?
        var currentQuestion: (plant: Plant, options: [String])?
        var selectedAnswer: String?
        var hasAnswered = false
        var elapsedTime: TimeInterval = 0.0
        var isPaused = false
        var score: SpeedrunScore?
        var personalBest: SpeedrunScore?
        var leaderboard: [SpeedrunScore] = []
        var error: String?
        var isGameActive = false
        var showResults = false
        var answerFeedback: AnswerFeedback?
        
        // Computed properties
        var questionsCompleted: Int {
            session?.questionsAnswered ?? 0
        }
        
        var questionsRemaining: Int {
            max(0, 25 - questionsCompleted)
        }
        
        var correctAnswers: Int {
            session?.correctAnswers ?? 0
        }
        
        var accuracy: Double {
            session?.accuracy ?? 0.0
        }
        
        var averageTimePerQuestion: TimeInterval {
            guard questionsCompleted > 0 else { return 0 }
            return elapsedTime / Double(questionsCompleted)
        }
        
        var projectedCompletionTime: TimeInterval {
            guard questionsCompleted > 0 else { return 0 }
            return averageTimePerQuestion * 25.0
        }
        
        var currentPace: SpeedrunPace {
            return calculateCurrentPace()
        }
        
        var canAnswer: Bool {
            guard let session = session else { return false }
            return isGameActive && !isPaused && !hasAnswered && 
                   currentQuestion != nil && questionsCompleted < 25 && 
                   session.state == .active
        }
        
        var progressPercentage: Double {
            return Double(questionsCompleted) / 25.0
        }
        
        var isSpeedrunComplete: Bool {
            return questionsCompleted >= 25
        }
        
        private func calculateCurrentPace() -> SpeedrunPace {
            guard questionsCompleted > 0 else { return .unknown }
            
            let targetTimes: [Game.Difficulty: TimeInterval] = [
                .easy: 4.0,    // 4s per question
                .medium: 5.0,  // 5s per question  
                .hard: 6.0,    // 6s per question
                .expert: 8.0   // 8s per question
            ]
            
            guard let targetTime = targetTimes[difficulty] else { return .unknown }
            
            let currentAverage = averageTimePerQuestion
            let ratio = currentAverage / targetTime
            
            if ratio <= 0.8 {
                return .excellent
            } else if ratio <= 1.0 {
                return .good
            } else if ratio <= 1.3 {
                return .average
            } else {
                return .slow
            }
        }
    }
    
    enum SpeedrunPace: String, CaseIterable {
        case excellent = "Excellent"
        case good = "Good"
        case average = "Average"
        case slow = "Slow"
        case unknown = "Unknown"
        
        var color: String {
            switch self {
            case .excellent: return "#00FF00"
            case .good: return "#90EE90"
            case .average: return "#FFFF00"
            case .slow: return "#FF6B35"
            case .unknown: return "#808080"
            }
        }
        
        var description: String {
            switch self {
            case .excellent: return "World record pace!"
            case .good: return "Great pace!"
            case .average: return "Steady pace"
            case .slow: return "Need to speed up"
            case .unknown: return "Just getting started"
            }
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
        case timerUpdate(TimeInterval) // elapsedTime
        case gameCompleted(SpeedrunScore)
        case loadPersonalBest
        case personalBestLoaded(SpeedrunScore?)
        case loadLeaderboard
        case leaderboardLoaded([SpeedrunScore])
        case showResults
        case hideResults
        case clearError
        case gameError(String)
    }
    
    struct AnswerFeedback: Equatable {
        let isCorrect: Bool
        let correctAnswer: String
        let selectedAnswer: String
        let questionNumber: Int
        let timeForThisQuestion: TimeInterval
        let showTime: Date
        
        var shouldHide: Bool {
            Date().timeIntervalSince(showTime) > 1.5
        }
    }
    
    @Dependency(\.speedrunService) var speedrunService
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
                
                let session = speedrunService.startSpeedrunGame(difficulty: difficulty)
                state.session = session
                state.elapsedTime = 0.0
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
                      state.questionsCompleted < 25 else { return .none }
                
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
                
                let questionStartTime = state.elapsedTime
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
                
                // Calculate time for this specific question
                let timeForThisQuestion = state.elapsedTime - questionStartTime
                
                // Show answer feedback
                state.answerFeedback = AnswerFeedback(
                    isCorrect: isCorrect,
                    correctAnswer: correctAnswer,
                    selectedAnswer: answer,
                    questionNumber: state.questionsCompleted,
                    timeForThisQuestion: timeForThisQuestion,
                    showTime: Date()
                )
                
                // Check if speedrun is complete
                if state.questionsCompleted >= 25 {
                    return .concatenate(
                        .send(.answerSubmitted(isCorrect)),
                        .run { send in
                            try await clock.sleep(for: .seconds(1.5))
                            await send(.gameCompleted(calculateFinalScore(state)))
                        } cancellableId: CancelID.answerFeedback
                    )
                } else {
                    return .concatenate(
                        .send(.answerSubmitted(isCorrect)),
                        // Hide feedback and load next question after delay
                        .run { send in
                            try await clock.sleep(for: .seconds(1.5))
                            await send(.loadNextQuestion)
                        } cancellableId: CancelID.answerFeedback
                    )
                }
                
            case .answerSubmitted(let isCorrect):
                // This action can be used for haptic feedback, sound effects, etc.
                return .none
                
            case .timerUpdate(let elapsedTime):
                state.elapsedTime = elapsedTime
                return .none
                
            case .gameCompleted(let score):
                state.isGameActive = false
                state.score = score
                state.showResults = true
                gameTimerService.stopTimer()
                
                // Save score and update personal best
                if let service = speedrunService as? SpeedrunService {
                    service.saveScore(score)
                }
                
                return .concatenate(
                    .cancel(id: CancelID.gameTimer),
                    .cancel(id: CancelID.answerFeedback),
                    .send(.loadPersonalBest),
                    .send(.loadLeaderboard)
                )
                
            case .loadPersonalBest:
                let personalBest = speedrunService.getBestScore(for: state.difficulty)
                return .send(.personalBestLoaded(personalBest))
                
            case .personalBestLoaded(let personalBest):
                state.personalBest = personalBest
                return .none
                
            case .loadLeaderboard:
                let leaderboard = speedrunService.getLeaderboard(for: state.difficulty)
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
            for await update in gameTimerService.startTimer(mode: .speedrun, startTime: Date()) {
                await send(.timerUpdate(update.totalTime))
            }
        } cancellableId: CancelID.gameTimer
    }
    
    private func calculateFinalScore(_ state: State) -> SpeedrunScore {
        guard let session = state.session else {
            return SpeedrunScore(
                id: UUID().uuidString,
                difficulty: state.difficulty,
                completionTime: state.elapsedTime,
                correctAnswers: 0,
                totalAnswers: 0,
                accuracy: 0.0,
                averageTimePerQuestion: 0.0,
                speedrunRating: 0,
                achievedAt: Date(),
                isNewRecord: false,
                isCompleted: false
            )
        }
        
        return speedrunService.calculateScore(session: session)
    }
}

// MARK: - Extensions

extension SpeedrunFeature.State {
    var elapsedTimeText: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        let milliseconds = Int((elapsedTime.truncatingRemainder(dividingBy: 1)) * 100)
        
        if minutes > 0 {
            return String(format: "%d:%02d.%02d", minutes, seconds, milliseconds)
        } else {
            return String(format: "%d.%02ds", seconds, milliseconds)
        }
    }
    
    var progressText: String {
        return "\(questionsCompleted)/25"
    }
    
    var accuracyText: String {
        return String(format: "%.1f%%", accuracy * 100)
    }
    
    var averageTimeText: String {
        return String(format: "%.2fs", averageTimePerQuestion)
    }
    
    var projectedTimeText: String {
        let minutes = Int(projectedCompletionTime) / 60
        let seconds = Int(projectedCompletionTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}